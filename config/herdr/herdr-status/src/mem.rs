//! タブ行のメモリ表示。並列エージェント・証跡撮影・nvim の同時利用で WSL が OOM しやすいため、
//! 使用量と最大プロセスを常に見えるようにし、空きが閾値を割ったら一度だけ herdr のトーストで知らせる。
use serde_json::{Map, Value, json};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use crate::herdr::Herdr;

const SOURCE: &str = "mem-status";
const CGROUP: &str = "/sys/fs/cgroup/system.slice";
const NODE_ROLES: [&str; 9] = [
    "next",
    "nest",
    "tsc",
    "jest",
    "vitest",
    "graphql-codegen",
    "pyright",
    "playwright",
    "vite",
];
const RANK: usize = 10;

#[derive(Debug, PartialEq)]
pub struct MemInfo {
    pub total: u64,
    pub avail: u64,
    pub swap_total: u64,
    pub swap_used: u64,
}

/// /proc/meminfo の kB を MiB(切り捨て)にする。
pub fn parse_meminfo(text: &str) -> MemInfo {
    let mut kb: HashMap<&str, u64> = HashMap::new();
    for line in text.lines() {
        let mut it = line.split_whitespace();
        if let (Some(key), Some(value)) = (it.next(), it.next()) {
            kb.insert(key.trim_end_matches(':'), value.parse().unwrap_or(0));
        }
    }
    let get = |k| kb.get(k).copied().unwrap_or(0);
    MemInfo {
        total: get("MemTotal") / 1024,
        avail: get("MemAvailable") / 1024,
        swap_total: get("SwapTotal") / 1024,
        swap_used: get("SwapTotal").saturating_sub(get("SwapFree")) / 1024,
    }
}

/// /proc/<pid>/status の RSS+swap(kB)。VmSwap 行の無いもの(カーネルスレッド)は対象外。
pub fn parse_status(text: &str) -> Option<u64> {
    let field = |name: &str| {
        text.lines()
            .find_map(|l| l.strip_prefix(name))
            .and_then(|v| v.split_whitespace().next())
            .and_then(|v| v.parse::<u64>().ok())
    };
    let swap = field("VmSwap:")?;
    Some(field("VmRSS:").unwrap_or(0) + swap)
}

/// コンテナ内の node は comm では区別できないので、コマンドラインから役割を拾う。
pub fn label(comm: &str, cmdline: &str) -> String {
    if (comm.starts_with("node") || comm == "MainThread")
        && let Some(role) = NODE_ROLES.iter().find(|k| cmdline.contains(*k))
    {
        return role.to_string();
    }
    comm.to_string()
}

pub fn gb(mb: u64) -> String {
    format!("{:.1}", mb as f64 / 1024.0)
}

pub fn status_line(mem: &MemInfo, top_label: &str, top_mb: u64, warn_mb: u64) -> String {
    let mark = if mem.avail < warn_mb { "⚠ " } else { "" };
    format!(
        "{mark}MEM {}/{}G · SW {}/{}G · top {top_label} {}G",
        gb(mem.total - mem.avail),
        gb(mem.total),
        gb(mem.swap_used),
        gb(mem.swap_total),
        gb(top_mb)
    )
}

struct Top {
    pid: String,
    label: String,
    mb: u64,
}

fn top_process() -> Option<Top> {
    let mut pids: Vec<String> = fs::read_dir("/proc")
        .ok()?
        .flatten()
        .filter_map(|e| e.file_name().into_string().ok())
        .filter(|n| n.bytes().all(|b| b.is_ascii_digit()))
        .collect();
    // sh 版の /proc/[0-9]* と同じ並びにして、同じ値のときの選び方を揃える
    pids.sort();
    let mut best: Option<(String, u64)> = None;
    for pid in pids {
        // 読む途中で消えたプロセスは飛ばす
        let Some(kb) = fs::read_to_string(format!("/proc/{pid}/status"))
            .ok()
            .as_deref()
            .and_then(parse_status)
        else {
            continue;
        };
        if kb > best.as_ref().map_or(0, |b| b.1) {
            best = Some((pid, kb));
        }
    }
    let (pid, kb) = best?;
    let comm = fs::read_to_string(format!("/proc/{pid}/comm")).unwrap_or_default();
    let cmdline = fs::read(format!("/proc/{pid}/cmdline"))
        .map(|b| String::from_utf8_lossy(&b).replace('\0', " "))
        .unwrap_or_default();
    Some(Top {
        label: label(comm.trim_end(), &cmdline),
        pid,
        mb: kb / 1024,
    })
}

/// `docker ps` の1行(ID 名前 イメージ compose プロジェクト)をサイドバー用の短い名前にする。
pub fn short_name(line: &str) -> Option<(String, String)> {
    let mut it = line.split_whitespace();
    let (id, name, image) = (it.next()?, it.next()?, it.next().unwrap_or(""));
    let project = it.next().unwrap_or("");
    let short = if project.is_empty() {
        // compose 外(MCP サーバ等)は名前がランダムで何者か分からないのでイメージ名を出す
        let base = image.rsplit('/').next().unwrap_or(image);
        base.split(':').next().unwrap_or(base)
    } else {
        // サイドバーの幅に収めるため、<プロジェクト>_<サービス> 形式の container_name はサービス名だけにする
        name.rsplit('_').next().unwrap_or(name)
    };
    Some((id.to_string(), short.to_string()))
}

/// MiB の量とコンテナ名から $c1.. の値を作る。
pub fn rank_tokens(mut usage: Vec<(u64, String)>, names: &HashMap<String, String>) -> Map<String, Value> {
    usage.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| b.1.cmp(&a.1)));
    let mut tokens = Map::new();
    for i in 0..RANK {
        let value = usage.get(i).map(|(mb, id)| {
            let name = names.get(id).cloned().unwrap_or_else(|| id.chars().take(12).collect());
            let size = if *mb >= 1024 {
                format!("{}G", gb(*mb))
            } else {
                format!("{mb}M")
            };
            Value::String(format!("{size} {name}"))
        });
        tokens.insert(format!("c{}", i + 1), value.unwrap_or(Value::Null));
    }
    tokens
}

fn read_u64(path: &Path) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

/// cgroup から各コンテナの anon+swap を MiB(切り捨て)で取る(docker stats は swap を数えない)。
fn container_usage() -> Vec<(u64, String)> {
    let Ok(entries) = fs::read_dir(CGROUP) else {
        return Vec::new();
    };
    entries
        .flatten()
        .filter_map(|e| {
            let name = e.file_name().into_string().ok()?;
            let id = name.strip_prefix("docker-")?.strip_suffix(".scope")?.to_string();
            let dir = e.path();
            let anon = fs::read_to_string(dir.join("memory.stat")).ok().and_then(|t| {
                t.lines()
                    .find_map(|l| l.strip_prefix("anon "))
                    .and_then(|v| v.trim().parse::<u64>().ok())
            });
            let swap = read_u64(&dir.join("memory.swap.current"));
            if anon.is_none() && swap.is_none() {
                return None;
            }
            Some(((anon.unwrap_or(0) + swap.unwrap_or(0)) / 1_048_576, id))
        })
        .collect()
}

fn load_names(path: &Path) -> HashMap<String, String> {
    fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .filter_map(|l| l.split_once(' ').map(|(id, name)| (id.to_string(), name.to_string())))
        .collect()
}

/// docker ps は 1 回 0.2 秒かかるので、cgroup に知らないコンテナが現れたときだけ名前表を作り直す。
fn container_names(path: &Path, ids: &HashSet<&str>) -> HashMap<String, String> {
    let names = load_names(path);
    if ids.iter().all(|id| names.contains_key(*id)) {
        return names;
    }
    let format = "{{.ID}} {{.Names}} {{.Image}} {{.Label \"com.docker.compose.project\"}}";
    let table: Vec<(String, String)> = run_with_timeout(
        Command::new("docker").args(["ps", "--no-trunc", "--format", format]),
        Duration::from_secs(1),
    )
    .map(|out| out.lines().filter_map(short_name).collect())
    .unwrap_or_default();
    // 失敗しても空の表を書き、次回また作り直す
    let text: String = table.iter().map(|(id, name)| format!("{id} {name}\n")).collect();
    let _ = fs::write(path, text);
    table.into_iter().collect()
}

fn run_with_timeout(cmd: &mut Command, limit: Duration) -> Option<String> {
    let mut child = cmd.stdout(Stdio::piped()).stderr(Stdio::null()).spawn().ok()?;
    let deadline = Instant::now() + limit;
    loop {
        match child.try_wait() {
            Ok(Some(_)) => break,
            Ok(None) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(10)),
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                return None;
            }
        }
    }
    let mut out = String::new();
    std::io::Read::read_to_string(&mut child.stdout.take()?, &mut out).ok()?;
    Some(out)
}

fn report_containers(herdr: &Herdr, names_path: &Path) {
    let usage = container_usage();
    let ids: HashSet<&str> = usage.iter().map(|(_, id)| id.as_str()).collect();
    let names = container_names(names_path, &ids);
    let tokens = rank_tokens(usage.clone(), &names);
    let Ok(list) = herdr.query("workspace.list", json!({})) else {
        return;
    };
    for ws in list.get("workspaces").and_then(Value::as_array).into_iter().flatten() {
        let Some(id) = ws.get("workspace_id").and_then(Value::as_str) else {
            continue;
        };
        // スクリプトが止まったら古い順位を残さないよう TTL で消す
        let params = json!({"workspace_id": id, "source": SOURCE, "ttl_ms": crate::timeline::TTL_MS, "tokens": tokens});
        let _ = herdr.send("workspace.report_metadata", params);
    }
}

fn env_mb(key: &str, default: u64) -> u64 {
    std::env::var(key).ok().and_then(|v| v.parse().ok()).unwrap_or(default)
}

pub struct Alert {
    pub state_file: PathBuf,
    pub warn_mb: u64,
    pub alert_mb: u64,
}

impl Alert {
    /// 空きが ALERT を割ったら一度だけ通知し、WARN を超えて回復するまで再通知しない。
    pub fn check(&self, mem: &MemInfo, notify: impl FnOnce() -> bool) {
        if mem.avail < self.alert_mb {
            if !self.state_file.exists() && notify() {
                let _ = fs::write(&self.state_file, "");
            }
        } else if mem.avail > self.warn_mb {
            let _ = fs::remove_file(&self.state_file);
        }
    }
}

pub fn report(herdr: &Herdr) -> Result<String, String> {
    let run = crate::runtime_dir();
    let mem = parse_meminfo(&fs::read_to_string("/proc/meminfo").map_err(|e| e.to_string())?);
    let top = top_process().unwrap_or(Top {
        pid: String::new(),
        label: String::new(),
        mb: 0,
    });
    report_containers(herdr, &run.join("herdr-mem-container-names"));
    let alert = Alert {
        state_file: run.join("herdr-mem-alerted"),
        warn_mb: env_mb("WARN_AVAIL_MB", 3072),
        alert_mb: env_mb("ALERT_AVAIL_MB", 1536),
    };
    alert.check(&mem, || {
        let params = json!({
            "title": format!("メモリ残り {}G", gb(mem.avail)),
            "body": format!("最大: {} (pid {}) {}G / swap {}G 使用", top.label, top.pid, gb(top.mb), gb(mem.swap_used)),
            "sound": "request",
        });
        herdr.send("notification.show", params).is_ok()
    });
    Ok(status_line(&mem, &top.label, top.mb, alert.warn_mb))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn meminfo_in_mib() {
        let text = "MemTotal:       20447232 kB\nMemFree: 1 kB\nMemAvailable:   15728640 kB\nSwapTotal:       8388608 kB\nSwapFree:        3145728 kB\n";
        assert_eq!(
            parse_meminfo(text),
            MemInfo {
                total: 19968,
                avail: 15360,
                swap_total: 8192,
                swap_used: 5120
            }
        );
    }

    #[test]
    fn status_requires_vmswap() {
        assert_eq!(
            parse_status("Name:\tnode\nVmRSS:\t  2048 kB\nVmSwap:\t  1024 kB\n"),
            Some(3072)
        );
        assert_eq!(parse_status("Name:\tkthreadd\n"), None);
        assert_eq!(parse_status("VmSwap:\t 5 kB\n"), Some(5));
    }

    #[test]
    fn node_role_from_cmdline() {
        assert_eq!(label("node", "node /app/node_modules/.bin/next dev"), "next");
        assert_eq!(label("MainThread", "node vitest run"), "vitest");
        // キーワードは書かれた順に探す(nest より next が先)
        assert_eq!(label("node", "nest start --watch next"), "next");
        assert_eq!(label("node", "node server.js"), "node");
        assert_eq!(label("python3", "python3 next.py"), "python3");
    }

    #[test]
    fn status_line_marks_low_memory() {
        let mem = MemInfo {
            total: 20000,
            avail: 3000,
            swap_total: 8192,
            swap_used: 5222,
        };
        assert_eq!(
            status_line(&mem, "next", 1946, 3072),
            "⚠ MEM 16.6/19.5G · SW 5.1/8.0G · top next 1.9G"
        );
        assert!(!status_line(&mem, "next", 1946, 2048).starts_with('⚠'));
    }

    #[test]
    fn short_names_from_docker_ps() {
        assert_eq!(
            short_name("abc mr_frontend registry.example/app/web:1.2 mr"),
            Some(("abc".into(), "frontend".into()))
        );
        assert_eq!(
            short_name("def brave_swartz ghcr.io/org/some-mcp-server "),
            Some(("def".into(), "some-mcp-server".into()))
        );
        assert_eq!(
            short_name("ghi postgres postgres:16 db"),
            Some(("ghi".into(), "postgres".into()))
        );
    }

    #[test]
    fn rank_tokens_fill_and_clear() {
        let names = HashMap::from([("a".to_string(), "frontend".to_string())]);
        let usage = vec![(90, "0123456789abcdef".to_string()), (2048, "a".to_string())];
        let tokens = rank_tokens(usage, &names);
        assert_eq!(tokens["c1"], json!("2.0G frontend"));
        assert_eq!(tokens["c2"], json!("90M 0123456789ab"));
        assert_eq!(tokens["c3"], Value::Null);
        assert_eq!(tokens.len(), 10);
    }

    #[test]
    fn alert_fires_once_until_recovered() {
        let dir = crate::testutil::tempdir();
        let alert = Alert {
            state_file: dir.join("alerted"),
            warn_mb: 3072,
            alert_mb: 1536,
        };
        let mem = |avail| MemInfo {
            total: 20000,
            avail,
            swap_total: 0,
            swap_used: 0,
        };
        let mut sent = 0;
        alert.check(&mem(1000), || false);
        assert!(!alert.state_file.exists(), "送れなかったときは状態を残さず次回また送る");
        alert.check(&mem(1000), || {
            sent += 1;
            true
        });
        alert.check(&mem(1000), || {
            sent += 1;
            true
        });
        assert_eq!(sent, 1);
        alert.check(&mem(2000), || unreachable!());
        assert!(alert.state_file.exists(), "ALERT と WARN の間では状態を保つ");
        alert.check(&mem(4000), || unreachable!());
        assert!(!alert.state_file.exists());
    }
}
