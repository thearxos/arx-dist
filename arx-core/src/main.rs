// arx-core — ARXOS native package-manager core.
//
// Hot paths carved out of the bash `arx` and run natively via libalpm, so there is
// no `pacman` subprocess spawn + text-parse on the common read paths:
//
//   search <term>...   fast repo search (name/desc), installed-flagged
//   info <pkg>...      repo package details
//   outdated           installed packages that have a newer version in the sync dbs
//   list               explicitly-installed packages
//
// Output is tab-separated and stable, so the thin bash `arx` formats/colours it.
// Bash stays the orchestrator (PTY loaders, self-heal, weapons, the write paths).

use std::collections::HashSet;
use std::env;
use std::process::exit;

use pacmanconf::Config;

fn open() -> alpm::Alpm {
    let conf = Config::new().unwrap_or_else(|e| {
        eprintln!("arx-core: /etc/pacman.conf: {e}");
        exit(1);
    });
    alpm_utils::alpm_with_conf(&conf).unwrap_or_else(|e| {
        eprintln!("arx-core: libalpm init: {e}");
        exit(1);
    })
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str).unwrap_or("") {
        "search" => search(&args[2..]),
        "info" => info(&args[2..]),
        "outdated" => outdated(),
        "list" => list(),
        "--version" | "-V" => println!("arx-core {}", env!("CARGO_PKG_VERSION")),
        // cheap ABI probe: open libalpm + read pacman.conf, exit 0 iff usable. `arx` runs this
        // before trusting the binary so a libalpm mismatch falls back to pacman instead of erroring.
        "--selftest" => {
            let _ = open();
        }
        _ => {
            eprintln!("usage: arx-core <search|info|outdated|list> [args]");
            exit(2);
        }
    }
}

fn search(terms: &[String]) {
    if terms.is_empty() {
        eprintln!("arx-core search: need at least one term");
        exit(2);
    }
    let handle = open();
    // pull installed names once (O(1) membership) instead of a localdb lookup per hit
    let installed: HashSet<String> = handle
        .localdb()
        .pkgs()
        .iter()
        .map(|p| p.name().to_string())
        .collect();
    let needles: Vec<&str> = terms.iter().map(String::as_str).collect();
    for db in handle.syncdbs() {
        let found = match db.search(needles.iter().copied()) {
            Ok(list) => list,
            Err(_) => continue,
        };
        for p in found {
            let installed = installed.contains(p.name());
            // repo \t name \t version \t installed(0|1) \t description
            println!(
                "{}\t{}\t{}\t{}\t{}",
                db.name(),
                p.name(),
                p.version(),
                installed as u8,
                p.desc().unwrap_or("")
            );
        }
    }
}

fn info(names: &[String]) {
    let handle = open();
    let mut missing = false;
    for name in names {
        let mut hit = false;
        for db in handle.syncdbs() {
            if let Ok(p) = db.pkg(name.as_str()) {
                println!("Repository\t{}", db.name());
                println!("Name\t{}", p.name());
                println!("Version\t{}", p.version());
                println!("Description\t{}", p.desc().unwrap_or(""));
                println!("URL\t{}", p.url().unwrap_or(""));
                println!("Download Size\t{}", p.download_size());
                println!("Installed Size\t{}", p.isize());
                println!("---");
                hit = true;
                break;
            }
        }
        if !hit {
            eprintln!("arx-core: {name}: not found in the sync databases");
            missing = true;
        }
    }
    if missing {
        exit(1);
    }
}

fn outdated() {
    let handle = open();
    let syncs = handle.syncdbs();
    for p in handle.localdb().pkgs() {
        if let Some(np) = p.sync_new_version(syncs) {
            // name \t current \t available
            println!("{}\t{}\t{}", p.name(), p.version(), np.version());
        }
    }
}

fn list() {
    let handle = open();
    for p in handle.localdb().pkgs() {
        if p.reason() == alpm::PackageReason::Explicit {
            println!("{}\t{}", p.name(), p.version());
        }
    }
}
