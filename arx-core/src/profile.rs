use std::time::Instant;

use anyhow::Result;

pub async fn search(query: &str) -> Result<()> {
    let total = Instant::now();
    let official_start = Instant::now();
    let official = super::search::official(query)?;
    let official_ms = official_start.elapsed();

    let aur_start = Instant::now();
    let aur = super::search::aur(query).await?;
    let aur_ms = aur_start.elapsed();

    let merge_start = Instant::now();
    let mut all = official;
    all.extend(aur);
    all.sort_by(|a, b| b.score.cmp(&a.score).then_with(|| a.name.cmp(&b.name)));
    all.dedup_by(|a, b| a.name == b.name && std::mem::discriminant(&a.source) == std::mem::discriminant(&b.source));
    let merge_ms = merge_start.elapsed();

    let render_start = Instant::now();
    super::search::render(&all);
    let render_ms = render_start.elapsed();

    eprintln!("ARX PROFILE query={query}");
    eprintln!("official_ms={:.3} results={}", official_ms.as_secs_f64() * 1000.0, all.iter().filter(|r| matches!(r.source, super::search::Source::Official(_))).count());
    eprintln!("aur_ms={:.3} results={}", aur_ms.as_secs_f64() * 1000.0, all.iter().filter(|r| matches!(r.source, super::search::Source::Aur)).count());
    eprintln!("merge_ms={:.3}", merge_ms.as_secs_f64() * 1000.0);
    eprintln!("render_ms={:.3}", render_ms.as_secs_f64() * 1000.0);
    eprintln!("total_ms={:.3}", total.elapsed().as_secs_f64() * 1000.0);
    Ok(())
}
