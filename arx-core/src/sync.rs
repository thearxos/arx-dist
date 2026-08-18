use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use tokio::process::Command;
use tokio::sync::Semaphore;

#[derive(Clone, Debug)]
pub struct RepoSpec {
    pub name: String,
    pub url: String,
    pub branch: String,
}

pub fn read_manifest(path: &Path) -> Result<Vec<RepoSpec>> {
    let text = std::fs::read_to_string(path)
        .with_context(|| format!("read manifest {}", path.display()))?;
    Ok(text
        .lines()
        .filter_map(|line| {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') { return None; }
            let mut it = line.split_whitespace();
            let name = it.next()?.to_owned();
            let url = it.next()?.to_owned();
            let branch = it.next().unwrap_or("main").to_owned();
            Some(RepoSpec { name, url, branch })
        })
        .collect())
}

async fn sync_one(repo: RepoSpec, cache: PathBuf) -> Result<()> {
    let dir = cache.join(&repo.name);
    if dir.join(".git").is_dir() {
        let status = Command::new("git")
            .args(["-C", dir.to_str().unwrap(), "fetch", "-q", "--depth=1", "origin", &repo.branch])
            .status().await.context("git fetch")?;
        if !status.success() { anyhow::bail!("{}: git fetch failed", repo.name); }
        let status = Command::new("git")
            .args(["-C", dir.to_str().unwrap(), "reset", "-q", "--hard", &format!("origin/{}", repo.branch)])
            .status().await.context("git reset")?;
        if !status.success() { anyhow::bail!("{}: git reset failed", repo.name); }
    } else {
        let status = Command::new("git")
            .args(["clone", "-q", "--depth=1", "-b", &repo.branch, &repo.url, dir.to_str().unwrap()])
            .status().await.context("git clone")?;
        if !status.success() { anyhow::bail!("{}: git clone failed", repo.name); }
    }
    Ok(())
}

pub async fn sync_manifest(manifest: &Path, cache: &Path, jobs: usize) -> Result<()> {
    std::fs::create_dir_all(cache)
        .with_context(|| format!("create cache {}", cache.display()))?;
    let repos = read_manifest(manifest)?;
    let gate = std::sync::Arc::new(Semaphore::new(jobs.max(1)));
    let mut tasks = Vec::with_capacity(repos.len());
    for repo in repos {
        let permit = gate.clone().acquire_owned().await?;
        let cache = cache.to_path_buf();
        tasks.push(tokio::spawn(async move {
            let _permit = permit;
            let name = repo.name.clone();
            (name, sync_one(repo, cache).await)
        }));
    }
    for task in tasks {
        let (name, result) = task.await?;
        match result {
            Ok(()) => println!("SYNC\t{name}\tOK"),
            Err(e) => println!("SYNC\t{name}\tERR\t{e}"),
        }
    }
    Ok(())
}
