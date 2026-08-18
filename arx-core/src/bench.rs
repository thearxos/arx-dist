use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy)]
pub struct Sample {
    pub elapsed: Duration,
    pub peak_rss_kb: Option<u64>,
}

pub fn measure<F, T>(f: F) -> (Sample, T)
where
    F: FnOnce() -> T,
{
    let start = Instant::now();
    let result = f();
    (
        Sample {
            elapsed: start.elapsed(),
            peak_rss_kb: peak_rss_kb(),
        },
        result,
    )
}

fn peak_rss_kb() -> Option<u64> {
    #[cfg(target_os = "linux")]
    {
        let status = std::fs::read_to_string("/proc/self/status").ok()?;
        status.lines().find_map(|line| {
            let value = line.strip_prefix("VmHWM:")?.split_whitespace().next()?.parse().ok()?;
            Some(value)
        })
    }
    #[cfg(not(target_os = "linux"))]
    { None }
}

pub fn print(label: &str, sample: Sample) {
    let rss = sample.peak_rss_kb.map(|v| format!(" peak_rss={} KiB", v)).unwrap_or_default();
    println!("benchmark {label}: elapsed_ms={}{}", sample.elapsed.as_secs_f64() * 1000.0, rss);
}
