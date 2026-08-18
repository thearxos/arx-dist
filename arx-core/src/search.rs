use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Clone, Debug)]
pub enum Source { Official(String), Aur }

#[derive(Clone, Debug)]
pub struct SearchResult {
    pub name: String,
    pub version: String,
    pub description: String,
    pub source: Source,
    pub score: i64,
}

#[derive(Deserialize)]
struct AurResponse { results: Vec<AurPackage> }

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct AurPackage { Name: String, Version: String, Description: Option<String>, NumVotes: i64, Popularity: f64 }

fn score(name: &str, query: &str, description: &str) -> i64 {
    let n = name.to_ascii_lowercase();
    let q = query.to_ascii_lowercase();
    let d = description.to_ascii_lowercase();
    if n == q { 10000 } else if n.starts_with(&q) { 8000 - n.len() as i64 } else if n.contains(&q) { 6000 - n.len() as i64 } else if d.contains(&q) { 3000 } else { 0 }
}

pub fn official(query: &str) -> Result<Vec<SearchResult>> {
    let handle = super::open_for_search()?;
    let mut out = Vec::new();
    for db in handle.syncdbs() {
        let terms = [query];
        for p in db.search(terms.into_iter()).unwrap_or_default() {
            let desc = p.desc().unwrap_or("").to_owned();
            out.push(SearchResult { name: p.name().to_owned(), version: p.version().to_string(), description: desc.clone(), source: Source::Official(db.name().to_owned()), score: score(p.name(), query, &desc) });
        }
    }
    Ok(out)
}

pub async fn aur(query: &str) -> Result<Vec<SearchResult>> {
    let url = format!("https://aur.archlinux.org/rpc/v5/search/{}?by=name-desc", urlencoding::encode(query));
    let response = reqwest::get(url).await.context("AUR request")?.error_for_status()?.json::<AurResponse>().await.context("AUR response")?;
    Ok(response.results.into_iter().map(|p| {
        let desc = p.Description.unwrap_or_default();
        let score = score(&p.Name, query, &desc) + p.NumVotes.min(500) + (p.Popularity * 100.0) as i64;
        SearchResult { name: p.Name, version: p.Version, description: desc, source: Source::Aur, score }
    }).collect())
}

pub async fn unified(query: &str) -> Result<Vec<SearchResult>> {
    // Fast path: an exact official package is the overwhelmingly common package
    // lookup. Avoid paying the AUR network latency when the local sync DB already
    // contains an exact match. Broad/fuzzy searches retain concurrent AUR lookup.
    let query_trimmed = query.trim();
    if !query_trimmed.is_empty() && !query_trimmed.contains(char::is_whitespace) {
        let official = tokio::task::spawn_blocking({
            let query = query_trimmed.to_owned();
            move || official(&query)
        }).await??;
        if official.iter().any(|r| r.name.eq_ignore_ascii_case(query_trimmed)) {
            return Ok(official);
        }
        let aur = aur(query_trimmed).await?;
        return merge(official, aur);
    }

    let official = tokio::task::spawn_blocking({
        let query = query.to_owned();
        move || official(&query)
    });
    let (official, aur) = tokio::join!(official, aur(query));
    merge(official??, aur?)
}

fn merge(mut official: Vec<SearchResult>, aur: Vec<SearchResult>) -> Result<Vec<SearchResult>> {
    official.extend(aur);
    official.sort_by(|a, b| b.score.cmp(&a.score).then_with(|| a.name.cmp(&b.name)));
    official.dedup_by(|a, b| a.name == b.name && std::mem::discriminant(&a.source) == std::mem::discriminant(&b.source));
    Ok(official)
}

pub fn render(results: &[SearchResult]) {
    println!("ARX :: package search\n");
    let official: Vec<_> = results.iter().filter(|r| matches!(r.source, Source::Official(_))).collect();
    let aur: Vec<_> = results.iter().filter(|r| matches!(r.source, Source::Aur)).collect();
    let mut n = 1usize;
    if !official.is_empty() {
        println!("PACMAN");
        for r in official { println!("  {n}  {}\t{}\n     {}", r.name, r.version, r.description); n += 1; }
        println!();
    }
    if !aur.is_empty() {
        println!("AUR · {} similar packages", aur.len());
        for r in aur { println!("  {n}  {}\t{}\n     {}", r.name, r.version, r.description); n += 1; }
        println!();
    }
    if results.is_empty() { println!("No packages found."); } else { println!("[1-{}] select · [q] quit", results.len()); }
}

#[cfg(test)]
mod tests {
    use super::score;

    #[test]
    fn exact_name_scores_above_prefix() {
        assert!(score("pacman", "pacman", "package manager") > score("pacman-contrib", "pacman", "tools"));
    }

    #[test]
    fn description_match_scores_below_name_match() {
        assert!(score("foo", "pacman", "pacman helper") < score("pacman-utils", "pacman", "utilities"));
    }
}
