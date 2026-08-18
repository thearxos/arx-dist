use anyhow::{bail, Context, Result};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub fn prepare(name: &str, root: &Path) -> Result<PathBuf> {
    if !valid_name(name) {
        bail!("invalid AUR package name: {name}");
    }
    fs::create_dir_all(root).with_context(|| format!("create AUR workspace {}", root.display()))?;
    let repo = root.join(name);
    if repo.exists() {
        fs::remove_dir_all(&repo).with_context(|| format!("reset AUR workspace {}", repo.display()))?;
    }
    let url = format!("https://aur.archlinux.org/{name}.git");
    let status = Command::new("git")
        .args(["clone", "--depth", "1", &url])
        .current_dir(root)
        .status()
        .context("failed to execute git for AUR checkout")?;
    if !status.success() {
        bail!("AUR checkout failed for {name}");
    }
    Ok(repo)
}

fn valid_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 100 && name.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'@' | b'+' | b'.' | b'_' | b'-'))
}
