//! herdr のタブ行・サイドバー・ポップアップに、Claude Code のタスク進捗とメモリ状況を出す。
//!
//!   report [--dry-run]   tab_bar_right から呼ぶ。$progress・$c1..$c10 を送り、タブ行用の1行を出す
//!   view [--refresh 秒]  prefix+t のポップアップ。全セッションのタスクツリーと直近のタイムライン
//!   dump --now 秒        全 transcript の集計と描画を JSON で出す(Python 版との突き合わせ用)
mod herdr;
mod mem;
mod timeline;
mod view;

use serde_json::json;
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

const USAGE: &str = "usage: herdr-status report [--dry-run] | view [--refresh 秒] | dump --now 秒";

pub fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

pub fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// 片方が失敗・panic しても、もう片方(特にメモリ逼迫の表示)は出す。
fn part(name: &str, errors: &mut Vec<String>, f: impl FnOnce() -> Result<String, String>) -> String {
    match catch_unwind(AssertUnwindSafe(f)) {
        Ok(Ok(text)) => text,
        Ok(Err(e)) => {
            errors.push(format!("{name}: {e}"));
            format!("{name} ERR")
        }
        Err(panic) => {
            let msg = panic
                .downcast_ref::<String>()
                .cloned()
                .or_else(|| panic.downcast_ref::<&str>().map(|s| s.to_string()))
                .unwrap_or_default();
            errors.push(format!("{name}: panic {msg}"));
            format!("{name} ERR")
        }
    }
}

fn report(dry_run: bool) {
    let ctx = timeline::Ctx::from_env();
    let herdr = herdr::Herdr::new(dry_run);
    let now = now();
    let mut errors = Vec::new();
    let tl = part("TL", &mut errors, || timeline::report(&ctx, &herdr, now));
    let mem = part("MEM", &mut errors, || mem::report(&herdr));
    if !errors.is_empty() {
        // 失敗するとタブ行のエントリも token も黙って消えるだけなので、原因を最新1件だけ残す
        let _ = std::fs::create_dir_all(&ctx.cache);
        let _ = std::fs::write(ctx.cache.join("error.log"), format!("{now}\n{}\n", errors.join("\n")));
    }
    println!(
        "{}",
        [tl, mem]
            .into_iter()
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join("  ")
    );
}

fn dump(now: i64) -> Result<(), String> {
    let ctx = timeline::Ctx::from_env();
    let mut sessions: Vec<String> = std::fs::read_dir(&ctx.projects)
        .map_err(|e| e.to_string())?
        .flatten()
        .flat_map(|d| std::fs::read_dir(d.path()).into_iter().flatten().flatten())
        .filter_map(|f| f.file_name().to_str()?.strip_suffix(".jsonl").map(String::from))
        .collect();
    sessions.sort();
    sessions.dedup();
    for sid in sessions {
        let Some(state) = timeline::update(&ctx, &sid, now)? else {
            continue;
        };
        let summary = timeline::summarize(&state, now);
        let line = json!({
            "sid": sid,
            "done": summary.done,
            "total": summary.total,
            "current": summary.current,
            "running": summary.running.len(),
            "token": timeline::progress_token(&summary),
            "tree": view::tree_lines(&state, now),
            "timeline": view::timeline_lines(&state, now, 80),
        });
        println!("{line}");
    }
    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let flag_value = |name: &str| {
        args.iter()
            .position(|a| a == name)
            .and_then(|i| args.get(i + 1))
            .and_then(|v| v.parse::<i64>().ok())
    };
    let result = match args.first().map(String::as_str) {
        Some("report") => {
            report(args.iter().any(|a| a == "--dry-run"));
            Ok(())
        }
        Some("view") => view::run(flag_value("--refresh").unwrap_or(2).max(1) as u64),
        Some("dump") => match flag_value("--now") {
            Some(now) => dump(now),
            None => Err(USAGE.into()),
        },
        _ => Err(USAGE.into()),
    };
    if let Err(e) = result {
        eprintln!("{e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod testutil {
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicUsize, Ordering};

    static COUNTER: AtomicUsize = AtomicUsize::new(0);

    pub fn tempdir() -> PathBuf {
        let n = COUNTER.fetch_add(1, Ordering::SeqCst);
        let dir = std::env::temp_dir().join(format!("herdr-status-test-{}-{n}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }
}
