use anyhow::{bail, Context, Result};
use std::process::Command;

use crate::search::{SearchResult, Source};

pub fn install_selected(result: &SearchResult) -> Result<()> {
    match &result.source {
        Source::Official(_) => install_official(&result.name),
        Source::Aur => bail!("AUR installation is not enabled yet; selected '{}' can be handed to the isolated AUR builder in the next stage", result.name),
    }
}

fn install_official(name: &str) -> Result<()> {
    let status = Command::new("pacman")
        .args(["-S", "--needed", "--", name])
        .status()
        .with_context(|| format!("failed to execute pacman for {name}"))?;
    if !status.success() {
        bail!("pacman failed while installing {name} (status: {status})");
    }
    Ok(())
}
