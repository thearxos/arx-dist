mod aur;
mod bench;
mod help;
mod install;
mod profile;
mod search;
mod select;
mod sync;

use std::env;
use std::path::PathBuf;
use std::process::exit;
use std::time::Instant;

use pacmanconf::Config;

fn open() -> alpm::Alpm {
    let conf = Config::new().unwrap_or_else(|e| { eprintln!("arx-core: /etc/pacman.conf: {e}"); exit(1); });
    alpm_utils::alpm_with_conf(&conf).unwrap_or_else(|e| { eprintln!("arx-core: libalpm init: {e}"); exit(1); })
}

pub(crate) fn open_for_search() -> anyhow::Result<alpm::Alpm> {
    let conf = Config::new()?;
    Ok(alpm_utils::alpm_with_conf(&conf)?)
}

fn with_runtime<F, Fut>(f: F)
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = ()>,
{
    match tokio::runtime::Builder::new_current_thread().enable_all().build() {
        Ok(rt) => rt.block_on(f()),
        Err(e) => { eprintln!("arx-core: runtime init: {e}"); exit(1); }
    }
}

fn profile_enabled() -> bool { env::var_os("ARX_PROFILE").is_some() }

fn peak_rss_kb() -> Option<u64> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    status.lines().find_map(|line| line.strip_prefix("VmHWM:")).and_then(|v| v.split_whitespace().next()).and_then(|v| v.parse::<u64>().ok())
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str).unwrap_or("") {
        "help" | "--help" | "-h" => help::print(args.get(2).map(String::as_str)),
        "search" => search_command(&args[2..]),
        "info" => with_runtime(|| info_command(&args[2..])),
        "outdated" => outdated(),
        "list" => list(),
        "sync" => with_runtime(|| async { if let Err(e) = sync_command(&args[2..]).await { eprintln!("arx-core: {e:#}"); exit(1); } }),
        "bench" => with_runtime(|| bench_command(&args[2..])),
        "profile" => with_runtime(|| async {
            if args.get(2).map(String::as_str) == Some("search") {
                if let Some(q) = args.get(3) { if let Err(e) = profile::search(q).await { eprintln!("arx-core profile: {e:#}"); exit(1); } }
                else { eprintln!("arx-core profile search: need a package name"); exit(2); }
            } else { eprintln!("usage: arx-core profile search <package>"); exit(2); }
        }),
        "--version" | "-V" => println!("arx-core {}", env!("CARGO_PKG_VERSION")),
        "--selftest" => { let _ = open(); }
        _ => { help::print(None); exit(2); }
    }
}

fn search_command(args: &[String]) {
    if args.is_empty() { eprintln!("arx-core search: need a package name"); exit(2); }
    let query = args.join(" "); let profile = profile_enabled(); let total_start = Instant::now();
    with_runtime(|| async move {
        let search_start = Instant::now();
        match search::unified(&query).await {
            Ok(results) => {
                let search_ms = search_start.elapsed().as_secs_f64() * 1000.0;
                let render_start = Instant::now(); render_search_results(&results);
                let render_ms = render_start.elapsed().as_secs_f64() * 1000.0;
                if profile { eprintln!("arx-profile query={query} search_ms={search_ms:.3} render_ms={render_ms:.3} runtime_ms=0.000 total_ms={:.3} results={} peak_rss_kb={}", total_start.elapsed().as_secs_f64() * 1000.0, results.len(), peak_rss_kb().map_or_else(|| "unknown".to_string(), |v| v.to_string())); }
            }
            Err(e) => { eprintln!("arx-core search: {e:#}"); exit(1); }
        }
    });
}

fn render_search_results(results: &[search::SearchResult]) {
    search::render(results);
    if !results.is_empty() && std::io::IsTerminal::is_terminal(&std::io::stdin()) {
        if let Some(index) = select::choose(results) { if let Err(e) = install::install_selected(&results[index]) { eprintln!("arx-core: install: {e:#}"); exit(1); } }
    }
}

async fn info_command(args: &[String]) {
    if args.is_empty() { eprintln!("arx-core info: need a package name"); exit(2); }
    for name in args {
        let exact = match search::unified(name).await { Ok(results) => results.into_iter().find(|r| r.name == *name), Err(e) => { eprintln!("arx-core info: {name}: {e:#}"); exit(1); } };
        match exact { Some(r) => { match &r.source { search::Source::Official(repo) => println!("Source\tPACMAN\nRepository\t{repo}"), search::Source::Aur => println!("Source\tAUR") } println!("Name\t{}\nVersion\t{}\nDescription\t{}\n---", r.name, r.version, r.description); }, None => { eprintln!("arx-core: {name}: package not found"); exit(1); } }
    }
}

async fn sync_command(args: &[String]) -> anyhow::Result<()> {
    let manifest = args.iter().position(|a| a == "--manifest").and_then(|i| args.get(i + 1)).map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/etc/arxos/repos.list"));
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let cache = args.iter().position(|a| a == "--cache").and_then(|i| args.get(i + 1)).map(PathBuf::from).unwrap_or_else(|| PathBuf::from(format!("{home}/.cache/arxos/repos")));
    let jobs = args.iter().position(|a| a == "--jobs").and_then(|i| args.get(i + 1)).and_then(|v| v.parse::<usize>().ok()).unwrap_or_else(|| std::thread::available_parallelism().map(|n| n.get().min(8)).unwrap_or(4));
    sync::sync_manifest(&manifest, &cache, jobs).await
}

async fn bench_command(args: &[String]) {
    match args.first().map(String::as_str).unwrap_or("self") {
        "self" => { let (sample, _) = bench::measure(|| { let _ = open(); }); bench::print("libalpm-init", sample); }
        "search" => { let query = args.get(1).map(String::as_str).unwrap_or("pacman"); let start = Instant::now(); match search::unified(query).await { Ok(results) => { bench::print("search", bench::Sample { elapsed: start.elapsed(), peak_rss_kb: None }); println!("benchmark search_results={}", results.len()); }, Err(e) => { eprintln!("arx-core bench search: {e:#}"); exit(1); } } }
        "sync" => { eprintln!("arx-core bench sync: use a dedicated test manifest with --manifest and --cache through arx-core sync; benchmark harness integration is next"); exit(2); }
        other => { eprintln!("arx-core bench: unknown mode '{other}' (use self or search)"); exit(2); }
    }
}

fn outdated() { let handle = open(); let syncs = handle.syncdbs(); for p in handle.localdb().pkgs() { if let Some(np) = p.sync_new_version(syncs) { println!("{}\t{}\t{}", p.name(), p.version(), np.version()); } } }
fn list() { let handle = open(); for p in handle.localdb().pkgs() { if p.reason() == alpm::PackageReason::Explicit { println!("{}\t{}", p.name(), p.version()); } } }
