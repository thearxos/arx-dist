use std::process::exit;

#[derive(Clone, Copy)]
struct HelpTopic {
    name: &'static str,
    aliases: &'static [&'static str],
    summary: &'static str,
    details: &'static str,
    example: &'static str,
}

const TOPICS: &[HelpTopic] = &[
    HelpTopic { name: "sync", aliases: &["-S", "-Sync", "--sync"], summary: "Synchronize/install packages using pacman-compatible sync semantics.", details: "Use this form when you want pacman's -S behavior. It operates against the configured package databases. Database refresh and system upgrade are controlled separately by refresh/sysupgrade options.", example: "arx -S firefox\narx -Sync firefox" },
    HelpTopic { name: "install", aliases: &["in", "i"], summary: "Install a package using the current package databases.", details: "This is the easier ARX spelling for installation. It does not intentionally force a repository refresh first. Use arx -S when you specifically want the pacman-compatible sync operation.", example: "arx install firefox" },
    HelpTopic { name: "remove", aliases: &["rm", "-R", "-Remove", "--remove"], summary: "Remove an installed package.", details: "Use --recursive to remove dependencies that are no longer required and --nosave to remove package-owned configuration files. ARX starts unprivileged and requests elevation only when the protected transaction needs it.", example: "arx remove firefox\narx remove --recursive --nosave firefox\narx -Rns firefox" },
    HelpTopic { name: "query", aliases: &["-Q", "-Query", "--query"], summary: "Query the local package database.", details: "Read-only operation. It does not require administrator privileges and does not contact the AUR. Use query options to list, search, inspect ownership, or inspect installed files.", example: "arx -Q firefox\narx -Qs browser\narx -Qo /usr/bin/firefox" },
    HelpTopic { name: "search", aliases: &["-Search", "--search"], summary: "Search package sources and show where each result comes from.", details: "Official repository results and AUR results remain explicitly classified. Exact official matches should avoid unnecessary AUR work. Search is read-only.", example: "arx search firefox\narx -Search firefox" },
    HelpTopic { name: "info", aliases: &["-Info", "--info"], summary: "Display package metadata and source information.", details: "Shows package identity, version, description, and source/repository information. This is read-only.", example: "arx info firefox\narx -Info firefox" },
    HelpTopic { name: "upgrade", aliases: &["-U", "-Upgrade", "--upgrade"], summary: "Install/upgrade from a local or supplied package using pacman-compatible semantics.", details: "Use this for local package upgrade workflows. For a normal repository system upgrade, use the sync/sysupgrade operation instead.", example: "arx -U ./package.pkg.tar.zst" },
    HelpTopic { name: "mirrors", aliases: &["mirror", "-Mirrors", "--mirrors"], summary: "Inspect and manage repository mirror configuration.", details: "Mirror operations are ArxOS integration functionality. Changes to protected configuration require elevation; inspection does not.", example: "arx mirrors" },
    HelpTopic { name: "aur", aliases: &["AUR"], summary: "Search, inspect, build, and install Arch User Repository packages.", details: "AUR packages are source builds and are always labeled separately from official repositories. Final installation should use the normal package transaction path.", example: "arx aur search firefox" },
];

pub fn print(topic: Option<&str>) {
    match topic {
        None => print_index(),
        Some(name) => match find(name) {
            Some(t) => print_topic(t),
            None => {
                eprintln!("arx: unknown help topic '{name}'");
                eprintln!("Try: arx help, arx help install, or arx help search");
                exit(2);
            }
        },
    }
}

fn find(name: &str) -> Option<&'static HelpTopic> {
    let n = name.to_ascii_lowercase();
    TOPICS.iter().find(|t| t.name == n || t.aliases.iter().any(|a| a.eq_ignore_ascii_case(name)))
}

fn print_index() {
    println!("ARX — Arch package manager for ArxOS\n");
    println!("USAGE\n    arx <command> [options] [package...]");
    println!("\nCOMMON COMMANDS");
    for t in TOPICS { println!("\n  arx {:<9} {}\n      help: arx help {}", t.name, t.summary, t.name); }
    println!("\nPRIVILEGE\n    ARX starts unprivileged. Administrator privileges are requested only\n    when an operation actually needs protected system access.");
    println!("\nFor details: arx help <command>");
}

fn print_topic(t: &HelpTopic) {
    println!("arx {}\n\n{}\n\n{}\n\nEXAMPLE\n    {}", t.name, t.summary, t.details, t.example.replace('\n', "\n    "));
}
