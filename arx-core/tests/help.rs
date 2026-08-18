use std::process::Command;

#[test]
fn help_is_available_without_alpm_initialization() {
    let bin = env!("CARGO_BIN_EXE_arx-core");
    let out = Command::new(bin).args(["help", "install"]).output().expect("run help");
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("Install a package"));
    assert!(text.contains("arx install firefox"));
}

#[test]
fn short_and_full_help_aliases_match_topic() {
    let bin = env!("CARGO_BIN_EXE_arx-core");
    for topic in ["sync", "install", "remove", "query", "search", "info"] {
        let out = Command::new(bin).args(["help", topic]).output().expect("run help");
        assert!(out.status.success(), "topic failed: {topic}");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains("EXAMPLE"), "missing example for {topic}");
    }
}
