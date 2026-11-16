use serde_json::json;
use std::collections::BTreeMap;
use std::io::Write;
use unicode_width::UnicodeWidthChar;

use crate::herdr::Herdr;
use crate::timeline::{self, Ctx, LiveAgent, State, Sub, WINDOW_SEC};

const RESET: &str = "\x1b[0m";

fn style(name: &str) -> &'static str {
    match name {
        "dim" => "\x1b[38;2;147;146;147m",
        "green" => "\x1b[38;2;169;220;118m",
        "yellow" => "\x1b[38;2;255;216;102m",
        "red" => "\x1b[38;2;255;97;136m",
        "cyan" => "\x1b[38;2;120;220;232m",
        "mauve" => "\x1b[38;2;171;157;242m",
        "bold" => "\x1b[1m",
        "rev" => "\x1b[7m",
        _ => "",
    }
}

fn paint(text: &str, styles: &[&str]) -> String {
    if styles.is_empty() {
        return text.to_string();
    }
    let mut out: String = styles.iter().map(|s| style(s)).collect();
    out.push_str(text);
    out.push_str(RESET);
    out
}

fn status_color(status: &str) -> &'static str {
    match status {
        "working" => "yellow",
        "blocked" => "red",
        "done" => "green",
        _ => "dim",
    }
}

/// ANSI を含む行を端末幅で切る。
pub fn fit(line: &str, cols: usize) -> String {
    let mut out = String::new();
    let mut used = 0;
    let mut chars = line.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\x1b' && chars.peek() == Some(&'[') {
            out.push(c);
            for d in chars.by_ref() {
                out.push(d);
                if d.is_ascii_alphabetic() {
                    break;
                }
            }
            continue;
        }
        let w = c.width().unwrap_or(0);
        if used + w > cols {
            out.push_str(RESET);
            return out;
        }
        out.push(c);
        used += w;
    }
    out
}

pub fn duration(sec: i64) -> String {
    let sec = sec.max(0);
    if sec < 60 {
        format!("{sec}s")
    } else if sec < 3600 {
        format!("{}m{:02}s", sec / 60, sec % 60)
    } else {
        format!("{}h{:02}m", sec / 3600, sec % 3600 / 60)
    }
}

fn local_time(ts: i64, with_seconds: bool) -> String {
    let t = ts as libc::time_t;
    // SAFETY: localtime_r は渡した tm にだけ書き込む
    let tm = unsafe {
        let mut tm: libc::tm = std::mem::zeroed();
        libc::localtime_r(&t, &mut tm);
        tm
    };
    if with_seconds {
        format!("{:02}:{:02}:{:02}", tm.tm_hour, tm.tm_min, tm.tm_sec)
    } else {
        format!("{:02}:{:02}", tm.tm_hour, tm.tm_min)
    }
}

fn visible_subs(state: &State, now: i64) -> Vec<&Sub> {
    let mut subs: Vec<&Sub> = state
        .subs
        .values()
        .filter(|s| s.state == "running" || s.end.is_some_and(|e| e >= now - WINDOW_SEC))
        .collect();
    subs.sort_by_key(|s| s.start.unwrap_or(0));
    subs
}

fn sub_line(sub: &Sub, now: i64, indent: &str) -> String {
    let (icon, color, took) = match sub.state.as_str() {
        "running" => ("⟳", "cyan", now - sub.start.unwrap_or(now)),
        "done" => (
            "✔",
            "dim",
            sub.end.unwrap_or(now) - sub.start.or(sub.end).unwrap_or(now),
        ),
        _ => (
            "✖",
            "red",
            sub.end.unwrap_or(now) - sub.start.or(sub.end).unwrap_or(now),
        ),
    };
    format!(
        "{indent}{} {}  {}  {}",
        paint(icon, &[color]),
        paint(&sub.kind, &["mauve"]),
        sub.desc,
        paint(&duration(took), &["dim"])
    )
}

pub fn tree_lines(state: &State, now: i64) -> Vec<String> {
    let tasks = &state.tasks;
    let subs = visible_subs(state, now);
    let not_in_tasks = |s: &Sub| s.task.is_none_or(|t| !tasks.contains_key(&t));
    let mut lines: Vec<(&str, String)> = Vec::new();
    let completed: Vec<u32> = tasks
        .iter()
        .filter(|(_, t)| t.status == "completed")
        .map(|(id, _)| *id)
        .collect();
    // 完了が多いと実行中のタスクが画面外に押し出されるので畳む
    let folded: Vec<u32> = if completed.len() > 6 {
        completed[..completed.len() - 2].to_vec()
    } else {
        Vec::new()
    };
    if !folded.is_empty() {
        lines.push((
            "",
            format!(
                "{} {}",
                paint("✔", &["green"]),
                paint(&format!("完了 {} 件(省略)", folded.len()), &["dim"])
            ),
        ));
    }
    let shown: Vec<_> = tasks.iter().filter(|(id, _)| !folded.contains(id)).collect();
    let has_orphans = subs.iter().any(|s| not_in_tasks(s));
    for (i, (id, task)) in shown.iter().enumerate() {
        let last = i == shown.len() - 1 && !has_orphans;
        let (branch, child) = if last { ("└", "   ") } else { ("├", "│  ") };
        let waiting: Vec<String> = task
            .blocked
            .iter()
            .filter(|d| tasks.get(d).is_some_and(|t| t.status != "completed"))
            .map(|d| format!("#{d}"))
            .collect();
        let text = match task.status.as_str() {
            "completed" => {
                let took = match (task.start, task.done) {
                    (Some(s), Some(d)) => format!("  {}", paint(&duration(d - s), &["dim"])),
                    _ => String::new(),
                };
                format!(
                    "{} #{id} {}{took}",
                    paint("✔", &["green"]),
                    paint(&task.subject, &["dim"])
                )
            }
            "in_progress" => {
                let since = task
                    .start
                    .map(|s| format!("  {}", paint(&duration(now - s), &["dim"])))
                    .unwrap_or_default();
                let label = if task.active.is_empty() {
                    &task.subject
                } else {
                    &task.active
                };
                format!(
                    "{} #{id} {}{since}",
                    paint("◐", &["yellow"]),
                    paint(label, &["yellow", "bold"])
                )
            }
            _ => {
                let wait = if waiting.is_empty() {
                    String::new()
                } else {
                    paint(&format!("  ⧗{}", waiting.join(",")), &["red"])
                };
                format!("{} #{id} {}{wait}", paint("○", &["dim"]), task.subject)
            }
        };
        lines.push((branch, text));
        for sub in subs.iter().filter(|s| s.task == Some(**id)) {
            lines.push((child, sub_line(sub, now, "└ ")));
        }
    }
    if has_orphans {
        lines.push((
            "└",
            paint(
                if tasks.is_empty() {
                    "サブエージェント"
                } else {
                    "タスク外のサブエージェント"
                },
                &["dim"],
            ),
        ));
        for sub in subs.iter().filter(|s| not_in_tasks(s)) {
            lines.push(("   ", sub_line(sub, now, "")));
        }
    }
    lines
        .into_iter()
        .map(|(b, t)| {
            if b.is_empty() {
                format!("     {t}")
            } else {
                format!("   {b} {t}")
            }
        })
        .collect()
}

fn lane(cols: usize, now: i64, value_at: impl Fn(f64, f64) -> String) -> String {
    let span = WINDOW_SEC as f64 / cols as f64;
    let origin = (now - WINDOW_SEC) as f64;
    (0..cols)
        .map(|i| value_at(origin + i as f64 * span, origin + (i + 1) as f64 * span))
        .collect()
}

pub fn timeline_lines(state: &State, now: i64, cols: usize) -> Vec<String> {
    let minutes: &BTreeMap<i64, u32> = &state.minutes;
    // 動きのないセッションの空のレーンで一覧が埋まらないようにする
    if !minutes.keys().any(|&m| m >= now - WINDOW_SEC) {
        return Vec::new();
    }
    let prompts = &state.prompts;
    let subs: Vec<&Sub> = state.subs.values().collect();
    let done_at: Vec<i64> = state.tasks.values().filter_map(|t| t.done).collect();
    let nowf = now as f64;
    let activity = |a: f64, b: f64| {
        if prompts.iter().any(|&p| a <= p as f64 && (p as f64) < b) {
            return paint("▼", &["mauve"]);
        }
        let n: u32 = minutes
            .iter()
            .filter(|&(&m, _)| (m as f64) < b && (m + 60) as f64 > a)
            .map(|(_, v)| v)
            .sum();
        match n {
            0 => paint("·", &["dim"]),
            1..=2 => paint("▃", &["yellow"]),
            3..=9 => paint("▆", &["yellow"]),
            _ => paint("█", &["yellow"]),
        }
    };
    let concurrency = |a: f64, b: f64| {
        let n = subs
            .iter()
            .filter(|s| (s.start.map_or(nowf, |v| v as f64)) < b && (s.end.map_or(nowf, |v| v as f64)) > a)
            .count();
        if n == 0 {
            " ".to_string()
        } else {
            paint(["░", "▒", "▓", "█"][n.min(4) - 1], &["cyan"])
        }
    };
    let completions = |a: f64, b: f64| {
        if done_at.iter().any(|&d| a <= d as f64 && (d as f64) < b) {
            paint("✔", &["green"])
        } else {
            " ".into()
        }
    };
    let start = local_time(now - WINDOW_SEC, false);
    let end = local_time(now, false);
    let mut rows = vec![format!(
        "   {start:>5} ▕{}▏ {}  {end}",
        lane(cols, now, activity),
        paint("本体", &["dim"])
    )];
    if subs.iter().any(|s| s.end.unwrap_or(now) >= now - WINDOW_SEC) {
        rows.push(format!(
            "   {:>5} ▕{}▏ {}",
            "",
            lane(cols, now, concurrency),
            paint("sub", &["dim"])
        ));
    }
    if done_at.iter().any(|&d| d >= now - WINDOW_SEC) {
        rows.push(format!(
            "   {:>5} ▕{}▏ {}",
            "",
            lane(cols, now, completions),
            paint("完了", &["dim"])
        ));
    }
    rows
}

pub fn render(
    agents: &[LiveAgent],
    states: &[Option<State>],
    selected: usize,
    cols: usize,
    rows: usize,
    now: i64,
) -> String {
    let legend = "j/k:選択  Enter:移動  q:閉じる   ▼依頼 ▃▆█活動量 ░▒▓█サブエージェント同時数 ✔タスク完了";
    let header = format!(
        " {}  {}   {}",
        paint("Agent Timeline", &["bold"]),
        local_time(now, true),
        paint(legend, &["dim"])
    );
    let mut blocks: Vec<Vec<String>> = Vec::new();
    for (i, (agent, state)) in agents.iter().zip(states).enumerate() {
        let mark = if i == selected {
            paint("▶", &["cyan"])
        } else {
            " ".into()
        };
        let title = if i == selected {
            paint(&agent.title, &["bold", "rev"])
        } else {
            paint(&agent.title, &["bold"])
        };
        let mut head = format!(
            " {mark} {} {title}  {}",
            paint(&agent.pane_id, &["dim"]),
            paint(&agent.status, &[status_color(&agent.status)])
        );
        let mut block = Vec::new();
        match state {
            Some(state) => {
                let token = timeline::progress_token(&timeline::summarize(state, now));
                if !token.is_empty() {
                    head += &format!("  {}", paint(&token, &["cyan"]));
                }
                block.push(head);
                block.extend(tree_lines(state, now));
                block.extend(timeline_lines(state, now, cols.saturating_sub(26).clamp(10, 120)));
            }
            None => {
                block.push(head);
                block.push(paint("     transcript が見つかりません", &["dim"]));
            }
        }
        block.push(String::new());
        blocks.push(block);
    }
    if agents.is_empty() {
        blocks.push(vec![paint("  Claude Code のエージェントがいません", &["dim"])]);
    }
    // 選んだエージェントのブロックが画面に入るように先頭をずらす
    let top: usize = blocks[..selected].iter().map(Vec::len).sum();
    let avail = rows.saturating_sub(2);
    let sel_len = blocks[selected].len();
    let offset = if top + sel_len > avail {
        top.min(top + sel_len - avail)
    } else {
        0
    };
    let body: Vec<&String> = blocks.iter().flatten().skip(offset).take(avail).collect();
    let lines: Vec<String> = [&header, &String::new()]
        .into_iter()
        .chain(body)
        .map(|l| fit(l, cols))
        .collect();
    format!("\x1b[H{}\x1b[K\x1b[J", lines.join("\x1b[K\r\n"))
}

#[derive(Debug, PartialEq)]
enum Key {
    Up,
    Down,
    Enter,
    Quit,
    Other,
}

fn parse_keys(data: &[u8]) -> Vec<Key> {
    let mut keys = Vec::new();
    let mut i = 0;
    while i < data.len() {
        let rest = &data[i..];
        let (key, len) = if rest.starts_with(b"\x1b[A") || rest.starts_with(b"\x1bOA") {
            (Key::Up, 3)
        } else if rest.starts_with(b"\x1b[B") || rest.starts_with(b"\x1bOB") {
            (Key::Down, 3)
        } else {
            let key = match rest[0] {
                b'k' => Key::Up,
                b'j' => Key::Down,
                b'\r' | b'\n' => Key::Enter,
                // ISIG を切っているので Ctrl-C も文字として届く
                b'q' | 0x1b | 0x03 => Key::Quit,
                _ => Key::Other,
            };
            (key, 1)
        };
        keys.push(key);
        i += len;
    }
    keys
}

/// cbreak 相当(エコーと行バッファと ISIG を切る)にし、Drop で必ず元に戻す。
struct Terminal {
    saved: libc::termios,
}

impl Terminal {
    fn enter() -> Result<Self, String> {
        // SAFETY: fd 0 の termios を読み書きするだけ
        unsafe {
            let mut saved: libc::termios = std::mem::zeroed();
            if libc::tcgetattr(0, &mut saved) != 0 {
                return Err("端末ではない".into());
            }
            let mut raw = saved;
            raw.c_lflag &= !(libc::ICANON | libc::ECHO | libc::ISIG);
            raw.c_cc[libc::VMIN] = 1;
            raw.c_cc[libc::VTIME] = 0;
            libc::tcsetattr(0, libc::TCSADRAIN, &raw);
            print!("\x1b[?1049h\x1b[?25l");
            let _ = std::io::stdout().flush();
            Ok(Terminal { saved })
        }
    }

    fn size() -> (usize, usize) {
        let env = |k: &str| {
            std::env::var(k)
                .ok()
                .and_then(|v| v.parse::<usize>().ok())
                .filter(|&v| v > 0)
        };
        // SAFETY: TIOCGWINSZ は winsize に書き込むだけ
        let ws = unsafe {
            let mut ws: libc::winsize = std::mem::zeroed();
            if libc::ioctl(1, libc::TIOCGWINSZ, &mut ws) == 0 {
                Some(ws)
            } else {
                None
            }
        };
        let cols = env("COLUMNS")
            .or(ws.map(|w| w.ws_col as usize).filter(|&v| v > 0))
            .unwrap_or(80);
        let rows = env("LINES")
            .or(ws.map(|w| w.ws_row as usize).filter(|&v| v > 0))
            .unwrap_or(24);
        (cols, rows)
    }

    fn read_keys(timeout_ms: i32) -> Vec<Key> {
        let mut fds = libc::pollfd {
            fd: 0,
            events: libc::POLLIN,
            revents: 0,
        };
        let mut buf = [0u8; 64];
        // SAFETY: fd 0 を poll して、用意したバッファに読むだけ
        let n = unsafe {
            if libc::poll(&mut fds, 1, timeout_ms) <= 0 {
                return Vec::new();
            }
            libc::read(0, buf.as_mut_ptr().cast(), buf.len())
        };
        if n <= 0 {
            vec![Key::Quit]
        } else {
            parse_keys(&buf[..n as usize])
        }
    }
}

impl Drop for Terminal {
    fn drop(&mut self) {
        // SAFETY: enter で保存した設定に戻すだけ
        unsafe {
            libc::tcsetattr(0, libc::TCSADRAIN, &self.saved);
        }
        print!("\x1b[?25h\x1b[?1049l");
        let _ = std::io::stdout().flush();
    }
}

pub fn run(refresh_sec: u64) -> Result<(), String> {
    let ctx = Ctx::from_env();
    let herdr = Herdr::new(false);
    let mut selected = 0usize;
    let focus = {
        let _term = Terminal::enter()?;
        let mut focus = None;
        'outer: loop {
            let now = crate::now();
            let agents = timeline::claude_agents(&herdr);
            let states: Vec<Option<State>> = agents
                .iter()
                .map(|a| timeline::update(&ctx, &a.session_id, now).ok().flatten())
                .collect();
            selected = selected.min(agents.len().saturating_sub(1));
            let (cols, rows) = Terminal::size();
            print!("{}", render(&agents, &states, selected, cols, rows, now));
            let _ = std::io::stdout().flush();
            for key in Terminal::read_keys((refresh_sec * 1000).min(i32::MAX as u64) as i32) {
                match key {
                    Key::Down => selected = (selected + 1).min(agents.len().saturating_sub(1)),
                    Key::Up => selected = selected.saturating_sub(1),
                    Key::Enter if !agents.is_empty() => {
                        focus = Some(agents[selected].pane_id.clone());
                        break 'outer;
                    }
                    Key::Quit => break 'outer,
                    _ => {}
                }
            }
        }
        focus
    };
    // 端末を戻してから移動する
    if let Some(pane) = focus {
        herdr.send("agent.focus", json!({"target": pane}))?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn strip(s: &str) -> String {
        let mut out = String::new();
        let mut chars = s.chars().peekable();
        while let Some(c) = chars.next() {
            if c == '\x1b' {
                for d in chars.by_ref() {
                    if d.is_ascii_alphabetic() {
                        break;
                    }
                }
                continue;
            }
            out.push(c);
        }
        out
    }

    #[test]
    fn fit_keeps_ansi_and_clips_width() {
        let line = paint("あいう", &["green"]) + "xyz";
        assert_eq!(strip(&fit(&line, 5)), "あい");
        assert_eq!(fit("abc", 10), "abc");
    }

    #[test]
    fn keys_are_split() {
        assert_eq!(parse_keys(b"jj\x1b[Ak"), vec![Key::Down, Key::Down, Key::Up, Key::Up]);
        assert_eq!(parse_keys(b"\r"), vec![Key::Enter]);
        assert_eq!(parse_keys(b"\x03"), vec![Key::Quit]);
        assert_eq!(parse_keys(b"\x1b"), vec![Key::Quit]);
    }

    #[test]
    fn durations() {
        assert_eq!(duration(-5), "0s");
        assert_eq!(duration(192), "3m12s");
        assert_eq!(duration(2_600_000), "722h13m");
    }
}
