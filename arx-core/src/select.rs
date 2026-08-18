use std::io::{self, Write};

use crate::search::{SearchResult, Source};

pub fn choose(results: &[SearchResult]) -> Option<usize> {
    if results.is_empty() { return None; }
    loop {
        print!("Select package [1-{}] or q: ", results.len());
        io::stdout().flush().ok()?;
        let mut input = String::new();
        io::stdin().read_line(&mut input).ok()?;
        let input = input.trim();
        if input.eq_ignore_ascii_case("q") { return None; }
        if let Ok(n) = input.parse::<usize>() {
            if (1..=results.len()).contains(&n) {
                let r = &results[n - 1];
                match &r.source {
                    Source::Official(repo) => println!("Selected {} ({repo}, pacman)", r.name),
                    Source::Aur => println!("Selected {} (AUR)", r.name),
                }
                return Some(n - 1);
            }
        }
        println!("Invalid selection.");
    }
}
