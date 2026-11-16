use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::io::{BufRead, BufReader, Seek, SeekFrom};
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use unicode_width::UnicodeWidthChar;

use crate::herdr::Herdr;

pub const SOURCE: &str = "agent-timeline";
// キャッシュの形を変えたら上げる。tmpfs のキャッシュは herdr を使っている間ずっと残るため
const CACHE_VERSION: u32 = 4;
pub const WINDOW_SEC: i64 = 60 * 60;
const KEEP_SEC: i64 = 3 * 60 * 60;
// Claude が落ちたときやチームメイトは meta.json に finished が付かないため、更新が止まったものは実行中とみなさない。
// 完了したサブエージェントの書き込み間隔は p99 で約15分だった
pub const STALE_SEC: i64 = 20 * 60;
pub const DONE_HIDE_SEC: i64 = 30 * 60;
pub const TOKEN_WIDTH: usize = 34;
// 周期(config.toml の interval_seconds)の数倍。周期を60秒以上にするならこれも上げる
pub const TTL_MS: u64 = 60_000;

pub struct Ctx {
    pub projects: PathBuf,
    pub cache: PathBuf,
}

impl Ctx {
    pub fn from_env() -> Self {
        Ctx {
            projects: crate::home().join(".claude/projects"),
            cache: crate::runtime_dir().join("herdr-agent-timeline"),
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Task {
    pub subject: String,
    pub active: String,
    pub status: String,
    pub blocked: Vec<u32>,
    pub start: Option<i64>,
    pub done: Option<i64>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct Pending {
    subject: String,
    active: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Agent {
    desc: String,
    kind: String,
    pub ts: i64,
    pub task: Option<u32>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Sub {
    pub desc: String,
    pub kind: String,
    pub start: Option<i64>,
    pub end: Option<i64>,
    pub task: Option<u32>,
    pub state: String,
    // 更新が止まっただけのものは、後で再開・完了することがあるので読み直す
    fin: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct State {
    v: u32,
    path: PathBuf,
    ino: u64,
    pub offset: u64,
    pub tasks: BTreeMap<u32, Task>,
    pending: HashMap<String, Pending>,
    pub agents: HashMap<String, Agent>,
    pub minutes: BTreeMap<i64, u32>,
    pub prompts: Vec<i64>,
    pub subs: BTreeMap<String, Sub>,
}

impl State {
    fn new(path: PathBuf, ino: u64) -> Self {
        State {
            v: CACHE_VERSION,
            path,
            ino,
            offset: 0,
            tasks: BTreeMap::new(),
            pending: HashMap::new(),
            agents: HashMap::new(),
            minutes: BTreeMap::new(),
            prompts: Vec::new(),
            subs: BTreeMap::new(),
        }
    }
}

/// `2026-11-15T15:38:13.784Z` 形式を epoch 秒にする。transcript の timestamp はこの形だけ。
pub fn parse_ts(value: &str) -> Option<i64> {
    let b = value.as_bytes();
    if b.len() < 20
        || b[4] != b'-'
        || b[7] != b'-'
        || b[10] != b'T'
        || b[13] != b':'
        || b[16] != b':'
        || !value.ends_with('Z')
    {
        return None;
    }
    let num = |r: std::ops::Range<usize>| value.get(r)?.parse::<i64>().ok();
    let (y, mo, d) = (num(0..4)?, num(5..7)?, num(8..10)?);
    let (h, mi, s) = (num(11..13)?, num(14..16)?, num(17..19)?);
    let rest = &value[19..value.len() - 1];
    if !(rest.is_empty() || (rest.starts_with('.') && rest[1..].bytes().all(|c| c.is_ascii_digit()))) {
        return None;
    }
    if !(1..=12).contains(&mo) || !(1..=31).contains(&d) || h > 23 || mi > 59 || s > 60 {
        return None;
    }
    // Howard Hinnant の days_from_civil
    let y = if mo <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let doy = (153 * ((mo + 9) % 12) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146097 + doe - 719468;
    Some(days * 86400 + h * 3600 + mi * 60 + s)
}

/// TaskUpdate の taskId は文字列でも数値でも来る。
fn task_id(v: &Value) -> Option<u32> {
    match v {
        Value::String(s) => s.parse().ok(),
        Value::Number(n) => n.as_u64().and_then(|n| u32::try_from(n).ok()),
        _ => None,
    }
}

fn str_of<'a>(v: &'a Value, key: &str) -> &'a str {
    v.get(key).and_then(Value::as_str).unwrap_or("")
}

pub fn feed(state: &mut State, rec: &Value) {
    let ts = rec.get("timestamp").and_then(Value::as_str).and_then(parse_ts);
    let kind = str_of(rec, "type");
    // api-request-blob などの控えにも同じ tool_use が timestamp なしで再出現するため、会話の行だけを見る
    let Some(ts) = ts else { return };
    if kind != "assistant" && kind != "user" {
        return;
    }
    let content = rec.get("message").and_then(|m| m.get("content"));
    if kind == "assistant" {
        *state.minutes.entry(ts.div_euclid(60) * 60).or_insert(0) += 1;
    } else if content.is_some_and(Value::is_string) && !rec.get("isMeta").and_then(Value::as_bool).unwrap_or(false) {
        state.prompts.push(ts);
    }
    let Some(items) = content.and_then(Value::as_array) else {
        return;
    };
    for item in items {
        let item_type = str_of(item, "type");
        if kind == "assistant" && item_type == "tool_use" {
            let empty = json!({});
            let input = item.get("input").filter(|v| v.is_object()).unwrap_or(&empty);
            on_tool_use(state, str_of(item, "id"), str_of(item, "name"), input, ts);
        } else if kind == "user"
            && item_type == "tool_result"
            && state.pending.contains_key(str_of(item, "tool_use_id"))
        {
            on_task_created(state, item, rec.get("toolUseResult"));
        }
    }
}

fn on_tool_use(state: &mut State, use_id: &str, name: &str, input: &Value, ts: i64) {
    match name {
        "TaskCreate" => {
            let pending = Pending {
                subject: str_of(input, "subject").into(),
                active: str_of(input, "activeForm").into(),
            };
            state.pending.insert(use_id.into(), pending);
        }
        "TaskUpdate" => {
            let Some(id) = input.get("taskId").and_then(task_id) else {
                return;
            };
            let Some(task) = state.tasks.get_mut(&id) else { return };
            let status = str_of(input, "status");
            if status == "deleted" {
                state.tasks.remove(&id);
                return;
            }
            if !status.is_empty() {
                task.status = status.into();
                if status == "in_progress" && task.start.is_none() {
                    task.start = Some(ts);
                }
                if status == "completed" {
                    task.done = Some(ts);
                }
            }
            if !str_of(input, "subject").is_empty() {
                task.subject = str_of(input, "subject").into();
            }
            if !str_of(input, "activeForm").is_empty() {
                task.active = str_of(input, "activeForm").into();
            }
            for dep in input
                .get("addBlockedBy")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
            {
                if let Some(dep) = task_id(dep) {
                    task.blocked.push(dep);
                }
            }
            for dep in input.get("addBlocks").and_then(Value::as_array).into_iter().flatten() {
                if let Some(other) = task_id(dep).and_then(|d| state.tasks.get_mut(&d)) {
                    other.blocked.push(id);
                }
            }
        }
        "Agent" => {
            let kind = input
                .get("subagent_type")
                .and_then(Value::as_str)
                .filter(|s| !s.is_empty())
                .unwrap_or("general-purpose");
            let agent = Agent {
                desc: str_of(input, "description").into(),
                kind: kind.into(),
                ts,
                task: current_task(&state.tasks),
            };
            state.agents.insert(use_id.into(), agent);
        }
        _ => {}
    }
}

fn on_task_created(state: &mut State, item: &Value, structured: Option<&Value>) {
    let Some(pending) = state.pending.remove(str_of(item, "tool_use_id")) else {
        return;
    };
    let id = structured
        .and_then(|s| s.get("task"))
        .and_then(|t| t.get("id"))
        .and_then(task_id)
        .or_else(|| {
            let body = match item.get("content") {
                Some(Value::String(s)) => s.clone(),
                Some(Value::Array(parts)) => parts
                    .iter()
                    .filter_map(|p| p.get("text").and_then(Value::as_str))
                    .collect::<Vec<_>>()
                    .join(" "),
                _ => String::new(),
            };
            created_id(&body)
        });
    let Some(id) = id else { return };
    if state.tasks.keys().next_back().is_some_and(|&max| id <= max) {
        // 同じセッションでもタスク一覧が作り直されると #1 から振り直される。古い一覧は捨てる
        state.tasks.clear();
        state.agents.values_mut().for_each(|a| a.task = None);
        state.subs.values_mut().for_each(|s| s.task = None);
    }
    let task = Task {
        subject: pending.subject,
        active: pending.active,
        status: "pending".into(),
        blocked: Vec::new(),
        start: None,
        done: None,
    };
    state.tasks.insert(id, task);
}

/// 本文の `Task #N created` から N を取る。
fn created_id(body: &str) -> Option<u32> {
    let rest = &body[body.find("Task #")? + "Task #".len()..];
    let digits: String = rest.chars().take_while(char::is_ascii_digit).collect();
    if digits.is_empty() || !rest[digits.len()..].starts_with(" created") {
        return None;
    }
    digits.parse().ok()
}

/// 最後に着手した in_progress のタスク。サブエージェントをぶら下げる先に使う。
pub fn current_task(tasks: &BTreeMap<u32, Task>) -> Option<u32> {
    tasks
        .iter()
        .filter(|(_, t)| t.status == "in_progress")
        .map(|(id, t)| (t.start.unwrap_or(0), *id))
        .max()
        .map(|(_, id)| id)
}

fn find_transcript(ctx: &Ctx, session_id: &str) -> Option<PathBuf> {
    let name = format!("{session_id}.jsonl");
    fs::read_dir(&ctx.projects)
        .ok()?
        .flatten()
        .map(|d| d.path().join(&name))
        .filter_map(|p| fs::metadata(&p).ok().map(|m| (m.mtime(), p)))
        .max()
        .map(|(_, p)| p)
}

fn load_cache(ctx: &Ctx, session_id: &str) -> Option<State> {
    let text = fs::read(ctx.cache.join(format!("{session_id}.json"))).ok()?;
    serde_json::from_slice::<State>(&text)
        .ok()
        .filter(|s| s.v == CACHE_VERSION)
}

fn save_cache(ctx: &Ctx, session_id: &str, state: &State) -> Result<(), String> {
    fs::create_dir_all(&ctx.cache).map_err(|e| e.to_string())?;
    let path = ctx.cache.join(format!("{session_id}.json"));
    let tmp = ctx.cache.join(format!("{session_id}.json.{}", std::process::id()));
    fs::write(&tmp, serde_json::to_vec(state).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
    fs::rename(&tmp, &path).map_err(|e| e.to_string())
}

/// 追記された分だけ transcript を読み、キャッシュを更新した状態を返す。transcript が無ければ None。
pub fn update(ctx: &Ctx, session_id: &str, now: i64) -> Result<Option<State>, String> {
    let cached = load_cache(ctx, session_id);
    let path = match &cached {
        Some(s) if s.path.exists() => s.path.clone(),
        _ => match find_transcript(ctx, session_id) {
            Some(p) => p,
            None => return Ok(None),
        },
    };
    let meta = fs::metadata(&path).map_err(|e| format!("{}: {e}", path.display()))?;
    let mut state = match cached {
        Some(s) if s.path == path && s.ino == meta.ino() && meta.len() >= s.offset => s,
        _ => State::new(path.clone(), meta.ino()),
    };
    let mut changed = meta.len() > state.offset;
    if changed {
        let mut file = fs::File::open(&path).map_err(|e| e.to_string())?;
        file.seek(SeekFrom::Start(state.offset)).map_err(|e| e.to_string())?;
        let mut reader = BufReader::with_capacity(1 << 16, file);
        let mut line = Vec::new();
        loop {
            line.clear();
            let n = reader.read_until(b'\n', &mut line).map_err(|e| e.to_string())?;
            // 書き込み途中の最終行は次回読み直す
            if n == 0 || !line.ends_with(b"\n") {
                break;
            }
            state.offset += n as u64;
            if let Ok(rec) = serde_json::from_slice::<Value>(&line)
                && rec.is_object()
            {
                feed(&mut state, &rec);
            }
        }
        prune(&mut state, now);
    }
    changed |= refresh_subs(&mut state, now);
    if changed {
        save_cache(ctx, session_id, &state)?;
    }
    Ok(Some(state))
}

fn prune(state: &mut State, now: i64) {
    let cutoff = now - KEEP_SEC;
    state.minutes.retain(|&m, _| m >= cutoff);
    state.prompts.retain(|&t| t >= cutoff);
    state.agents.retain(|_, a| a.ts >= cutoff);
}

fn mtime(path: &Path) -> Option<i64> {
    fs::metadata(path).ok().map(|m| m.mtime())
}

/// subagents/*.meta.json から各サブエージェントの状態を取る。確定したものは読み直さない。
fn refresh_subs(state: &mut State, now: i64) -> bool {
    let base = state.path.to_string_lossy();
    let sub_dir = PathBuf::from(format!("{}/subagents", base.strip_suffix(".jsonl").unwrap_or(&base)));
    let Ok(entries) = fs::read_dir(&sub_dir) else {
        return false;
    };
    let mut changed = false;
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        let Some(stem) = name.strip_suffix(".meta.json") else {
            continue;
        };
        let known = state.subs.get(&name).cloned();
        if known.as_ref().is_some_and(|k| k.fin) {
            continue;
        }
        let log = sub_dir.join(format!("{stem}.jsonl"));
        let Some(end) = mtime(&log) else { continue };
        if known.is_none() && end < now - KEEP_SEC {
            continue;
        }
        let Some(meta) = fs::read(entry.path())
            .ok()
            .and_then(|t| serde_json::from_slice::<Value>(&t).ok())
        else {
            continue;
        };
        let agent = meta
            .get("toolUseId")
            .and_then(Value::as_str)
            .and_then(|id| state.agents.get(id));
        let (start, task) = match (&known, agent) {
            (Some(k), _) => (k.start, k.task),
            (None, Some(a)) => (Some(a.ts), a.task),
            // スキル経由やチームメイトは親に Agent の tool_use が無いので、サブエージェント自身の記録から取る
            (None, None) => (first_ts(&log), None),
        };
        let flag = |key: &str| meta.get(key).and_then(Value::as_bool).unwrap_or(false);
        let sub_state = if flag("finished") {
            "done"
        } else if flag("stoppedByUser") || now - end > STALE_SEC {
            "stopped"
        } else {
            "running"
        };
        let pick = |key: &str| meta.get(key).and_then(Value::as_str).filter(|s| !s.is_empty());
        let sub = Sub {
            desc: pick("description")
                .or_else(|| pick("name"))
                .map(String::from)
                .or_else(|| agent.map(|a| a.desc.clone()))
                .unwrap_or_default(),
            kind: pick("agentType")
                .map(String::from)
                .or_else(|| agent.map(|a| a.kind.clone()))
                .unwrap_or_default(),
            start,
            end: if sub_state == "running" { None } else { Some(end) },
            task,
            state: sub_state.into(),
            fin: flag("finished") || flag("stoppedByUser"),
        };
        if known.as_ref() != Some(&sub) {
            state.subs.insert(name, sub);
            changed = true;
        }
    }
    let before = state.subs.len();
    state.subs.retain(|_, s| s.end.is_none_or(|e| e >= now - KEEP_SEC));
    changed || state.subs.len() != before
}

fn first_ts(path: &Path) -> Option<i64> {
    let reader = BufReader::new(fs::File::open(path).ok()?);
    reader.lines().take(20).map_while(Result::ok).find_map(|l| {
        serde_json::from_str::<Value>(&l)
            .ok()?
            .get("timestamp")?
            .as_str()
            .and_then(parse_ts)
    })
}

pub fn width(text: &str) -> usize {
    text.chars().map(|c| c.width().unwrap_or(0)).sum()
}

pub fn truncate(text: &str, limit: usize) -> String {
    if width(text) <= limit {
        return text.to_string();
    }
    let mut out = String::new();
    let mut used = 0;
    for c in text.chars() {
        let w = c.width().unwrap_or(0);
        if used + w > limit - 1 {
            break;
        }
        out.push(c);
        used += w;
    }
    out + "…"
}

pub struct Summary {
    pub done: usize,
    pub total: usize,
    pub current: String,
    pub running: Vec<Sub>,
}

pub fn summarize(state: &State, now: i64) -> Summary {
    let tasks = &state.tasks;
    let mut done = tasks.values().filter(|t| t.status == "completed").count();
    let mut total = tasks.len();
    // 終わった作業の一覧がサイドバーに残り続けると、動いているセッションが見分けにくくなる
    if total > 0 && done == total && tasks.values().filter_map(|t| t.done).max().unwrap_or(0) < now - DONE_HIDE_SEC {
        done = 0;
        total = 0;
    }
    let current = current_task(tasks).and_then(|id| tasks.get(&id)).map(|t| {
        if t.active.is_empty() {
            t.subject.clone()
        } else {
            t.active.clone()
        }
    });
    let running = state.subs.values().filter(|s| s.state == "running").cloned().collect();
    Summary {
        done,
        total,
        current: current.unwrap_or_default(),
        running,
    }
}

/// サイドバーのエージェント行に出す1行。出すものが無ければ空文字。
pub fn progress_token(summary: &Summary) -> String {
    let Summary {
        done, total, running, ..
    } = summary;
    let mut parts: Vec<String> = Vec::new();
    if *total > 0 {
        let filled = (4.0 * *done as f64 / *total as f64).round_ties_even() as usize;
        parts.push(format!(
            "{}{} {done}/{total}",
            "▰".repeat(filled),
            "▱".repeat(4 - filled)
        ));
    }
    if !running.is_empty() {
        parts.push(format!("⟳{}", running.len()));
    }
    if *total > 0 {
        parts.push(if !summary.current.is_empty() {
            summary.current.clone()
        } else if done == total {
            "✔".into()
        } else {
            String::new()
        });
    } else if let Some(first) = running.first() {
        // 同じ開始時刻なら先に見つかったものを出す
        let latest = running.iter().fold(first, |best, s| {
            if s.start.unwrap_or(0) > best.start.unwrap_or(0) {
                s
            } else {
                best
            }
        });
        parts.push(latest.desc.clone());
    }
    let joined = parts
        .into_iter()
        .filter(|p| !p.is_empty())
        .collect::<Vec<_>>()
        .join(" ");
    truncate(&joined, TOKEN_WIDTH)
}

pub fn tab_summary(summaries: &[Summary]) -> String {
    let done: usize = summaries.iter().map(|s| s.done).sum();
    let total: usize = summaries.iter().map(|s| s.total).sum();
    let running: usize = summaries.iter().map(|s| s.running.len()).sum();
    let mut parts = Vec::new();
    if total > 0 {
        parts.push(format!("TASK {done}/{total}"));
    }
    if running > 0 {
        parts.push(format!("SUB {running}⟳"));
    }
    parts.join(" · ")
}

pub fn remove_old_caches(ctx: &Ctx, now: i64) {
    let Ok(entries) = fs::read_dir(&ctx.cache) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().is_some_and(|e| e == "json") && mtime(&path).is_some_and(|m| m < now - 24 * 60 * 60) {
            let _ = fs::remove_file(path);
        }
    }
}

pub struct LiveAgent {
    pub pane_id: String,
    pub session_id: String,
    pub status: String,
    pub title: String,
}

pub fn claude_agents(herdr: &Herdr) -> Vec<LiveAgent> {
    let Ok(result) = herdr.request("agent.list", json!({})) else {
        return Vec::new();
    };
    let agents = result
        .get("agents")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    agents
        .iter()
        .filter(|a| str_of(a, "agent") == "claude")
        .filter_map(|a| {
            let session_id = a
                .get("agent_session")?
                .get("value")?
                .as_str()
                .filter(|s| !s.is_empty())?
                .to_string();
            let title = Some(str_of(a, "terminal_title_stripped"))
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| str_of(a, "cwd"));
            Some(LiveAgent {
                pane_id: str_of(a, "pane_id").into(),
                session_id,
                status: a
                    .get("agent_status")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown")
                    .into(),
                title: title.into(),
            })
        })
        .collect()
}

/// 各ペインの $progress を更新し、タブ行用の集計を返す。
pub fn report(ctx: &Ctx, herdr: &Herdr, now: i64) -> Result<String, String> {
    remove_old_caches(ctx, now);
    let mut summaries = Vec::new();
    for agent in claude_agents(herdr) {
        let summary = update(ctx, &agent.session_id, now)?.map(|s| summarize(&s, now));
        let token = summary.as_ref().map(progress_token).unwrap_or_default();
        let value = if token.is_empty() {
            Value::Null
        } else {
            Value::String(token)
        };
        let params =
            json!({"pane_id": agent.pane_id, "source": SOURCE, "ttl_ms": TTL_MS, "tokens": {"progress": value}});
        let _ = herdr.request("pane.report_metadata", params);
        summaries.extend(summary);
    }
    Ok(tab_summary(&summaries))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::testutil::tempdir;
    use std::fs::OpenOptions;
    use std::io::Write;

    const SID: &str = "00000000-0000-4000-8000-000000000000";
    const NOW: i64 = 1_800_000_000;

    fn iso(ts: i64) -> String {
        let days = ts.div_euclid(86400);
        let secs = ts.rem_euclid(86400);
        // civil_from_days
        let z = days + 719468;
        let era = z.div_euclid(146097);
        let doe = z - era * 146097;
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        let mp = (5 * doy + 2) / 153;
        let d = doy - (153 * mp + 2) / 5 + 1;
        let m = if mp < 10 { mp + 3 } else { mp - 9 };
        let y = yoe + era * 400 + if m <= 2 { 1 } else { 0 };
        format!(
            "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}.000Z",
            secs / 3600,
            secs % 3600 / 60,
            secs % 60
        )
    }

    fn assistant(ts: i64, uses: &[(&str, &str, Value)]) -> Value {
        let content: Vec<Value> = uses
            .iter()
            .map(|(id, name, input)| json!({"type": "tool_use", "id": id, "name": name, "input": input}))
            .collect();
        json!({"type": "assistant", "timestamp": iso(ts), "message": {"role": "assistant", "content": content}})
    }

    fn result(ts: i64, use_id: &str, text: &str, structured: Option<Value>) -> Value {
        let mut rec = json!({"type": "user", "timestamp": iso(ts), "message": {"role": "user", "content": [{"tool_use_id": use_id, "type": "tool_result", "content": text}]}});
        if let Some(s) = structured {
            rec["toolUseResult"] = s;
        }
        rec
    }

    fn prompt(ts: i64, text: &str) -> Value {
        json!({"type": "user", "timestamp": iso(ts), "message": {"role": "user", "content": text}})
    }

    fn create(ts: i64, use_id: &str, id: u32, subject: &str, active: &str) -> Vec<Value> {
        vec![
            assistant(
                ts,
                &[(
                    use_id,
                    "TaskCreate",
                    json!({"subject": subject, "description": "d", "activeForm": active}),
                )],
            ),
            result(
                ts + 1,
                use_id,
                &format!("Task #{id} created successfully: {subject}"),
                None,
            ),
        ]
    }

    fn task_update(ts: i64, use_id: &str, input: Value) -> Value {
        assistant(ts, &[(use_id, "TaskUpdate", input)])
    }

    struct Env {
        ctx: Ctx,
        dir: PathBuf,
        path: PathBuf,
    }

    impl Env {
        fn new() -> Self {
            let root = tempdir();
            let ctx = Ctx {
                projects: root.join("projects"),
                cache: root.join("cache"),
            };
            let dir = ctx.projects.join("-repo");
            fs::create_dir_all(&dir).unwrap();
            let path = dir.join(format!("{SID}.jsonl"));
            Env { ctx, dir, path }
        }

        fn write(&self, records: &[Value]) {
            let mut f = OpenOptions::new().create(true).append(true).open(&self.path).unwrap();
            for r in records {
                writeln!(f, "{r}").unwrap();
            }
        }

        fn rewrite(&self, records: &[Value]) {
            // 同じ inode のまま縮んだ状態を作る
            let f = OpenOptions::new().write(true).open(&self.path).unwrap();
            f.set_len(0).unwrap();
            self.write(records);
        }

        fn load(&self) -> State {
            update(&self.ctx, SID, NOW).unwrap().unwrap()
        }

        fn subagent(&self, agent_id: &str, use_id: Option<&str>, desc: &str, mtime: i64, flags: Value) {
            let sub_dir = self.dir.join(SID).join("subagents");
            fs::create_dir_all(&sub_dir).unwrap();
            let mut meta = json!({"agentType": "reviewer", "description": desc, "toolUseId": use_id});
            for (k, v) in flags.as_object().unwrap() {
                meta[k] = v.clone();
            }
            fs::write(sub_dir.join(format!("agent-{agent_id}.meta.json")), meta.to_string()).unwrap();
            let log = sub_dir.join(format!("agent-{agent_id}.jsonl"));
            if !log.exists() {
                fs::write(&log, "").unwrap();
            }
            set_mtime(&log, mtime);
        }
    }

    fn set_mtime(path: &Path, ts: i64) {
        let f = fs::File::options().write(true).open(path).unwrap();
        let t = std::time::UNIX_EPOCH + std::time::Duration::from_secs(ts as u64);
        f.set_times(fs::FileTimes::new().set_accessed(t).set_modified(t))
            .unwrap();
    }

    fn statuses(state: &State) -> Vec<(u32, String)> {
        state.tasks.iter().map(|(k, t)| (*k, t.status.clone())).collect()
    }

    #[test]
    fn parses_transcript_timestamps() {
        assert_eq!(parse_ts("1970-01-01T00:00:00.000Z"), Some(0));
        assert_eq!(parse_ts("2026-11-15T15:38:13.784Z"), Some(1_794_757_093));
        assert_eq!(parse_ts("2024-02-29T12:00:00Z"), Some(1_709_208_000));
        assert_eq!(parse_ts("2026-11-15 15:38:13Z"), None);
        assert_eq!(parse_ts("2026-11-15T15:38:13+09:00"), None);
        assert_eq!(iso(1_794_757_093), "2026-11-15T15:38:13.000Z");
    }

    #[test]
    fn create_and_progress() {
        let env = Env::new();
        let n = NOW - 600;
        let mut recs = create(n, "u1", 1, "調査", "調査中");
        recs.extend(create(n + 10, "u2", 2, "実装", "実装中"));
        recs.extend(create(n + 20, "u3", 3, "検証", ""));
        recs.push(task_update(
            n + 30,
            "u4",
            json!({"taskId": "1", "status": "in_progress"}),
        ));
        recs.push(task_update(n + 90, "u5", json!({"taskId": "1", "status": "completed"})));
        recs.push(task_update(
            n + 100,
            "u6",
            json!({"taskId": 2, "status": "in_progress"}),
        ));
        recs.push(task_update(
            n + 110,
            "u7",
            json!({"taskId": "3", "addBlockedBy": ["2"]}),
        ));
        env.write(&recs);
        let state = env.load();
        assert_eq!(
            statuses(&state),
            vec![
                (1, "completed".into()),
                (2, "in_progress".into()),
                (3, "pending".into())
            ]
        );
        assert_eq!(state.tasks[&1].done.unwrap() - state.tasks[&1].start.unwrap(), 60);
        assert_eq!(state.tasks[&3].blocked, vec![2]);
        let summary = summarize(&state, NOW);
        assert_eq!(
            (summary.done, summary.total, summary.current.as_str()),
            (1, 3, "実装中")
        );
        assert_eq!(progress_token(&summary), "▰▱▱▱ 1/3 実装中");
    }

    #[test]
    fn progress_bar_rounds_half_to_even() {
        let token = |done, total| {
            progress_token(&Summary {
                done,
                total,
                current: "x".into(),
                running: vec![],
            })
        };
        assert_eq!(token(1, 8), "▱▱▱▱ 1/8 x");
        assert_eq!(token(5, 8), "▰▰▱▱ 5/8 x");
        assert_eq!(token(3, 8), "▰▰▱▱ 3/8 x");
    }

    #[test]
    fn deleted_task_disappears() {
        let env = Env::new();
        let n = NOW - 600;
        let mut recs = create(n, "u1", 1, "不要", "");
        recs.push(task_update(n + 5, "u2", json!({"taskId": "1", "status": "deleted"})));
        env.write(&recs);
        assert!(env.load().tasks.is_empty());
    }

    #[test]
    fn renumbered_list_replaces_old_one() {
        let env = Env::new();
        let n = NOW - 600;
        let mut recs = create(n, "u1", 1, "旧1", "");
        recs.extend(create(n + 1, "u2", 2, "旧2", ""));
        recs.push(task_update(
            n + 2,
            "u3",
            json!({"taskId": "1", "status": "in_progress"}),
        ));
        recs.push(assistant(n + 3, &[("a1", "Agent", json!({"description": "旧の子"}))]));
        recs.extend(create(n + 10, "u4", 1, "新1", ""));
        env.write(&recs);
        let state = env.load();
        assert_eq!(
            state.tasks.values().map(|t| t.subject.as_str()).collect::<Vec<_>>(),
            vec!["新1"]
        );
        assert_eq!(state.agents["a1"].task, None);
    }

    #[test]
    fn renumbered_from_middle_and_structured_id() {
        let env = Env::new();
        let n = NOW - 600;
        let mut recs = create(n, "u1", 1, "旧1", "");
        recs.extend(create(n + 1, "u2", 2, "旧2", ""));
        recs.extend(create(n + 2, "u3", 3, "旧3", ""));
        // 構造化された結果を優先し、本文の番号は見ない
        recs.push(assistant(
            n + 10,
            &[("u4", "TaskCreate", json!({"subject": "新", "activeForm": ""}))],
        ));
        recs.push(result(
            n + 11,
            "u4",
            "Task #9 created successfully: 新",
            Some(json!({"task": {"id": "2", "subject": "新"}})),
        ));
        env.write(&recs);
        let state = env.load();
        assert_eq!(
            state
                .tasks
                .iter()
                .map(|(k, t)| (*k, t.subject.as_str()))
                .collect::<Vec<_>>(),
            vec![(2, "新")]
        );
    }

    #[test]
    fn tasks_are_ordered_numerically() {
        let env = Env::new();
        let mut recs = Vec::new();
        for i in 1..=11 {
            recs.extend(create(NOW - 600 + i as i64, &format!("u{i}"), i, &format!("t{i}"), ""));
        }
        env.write(&recs);
        assert_eq!(
            env.load().tasks.keys().copied().collect::<Vec<_>>(),
            (1..=11).collect::<Vec<_>>()
        );
    }

    #[test]
    fn failed_create_is_ignored() {
        let env = Env::new();
        let n = NOW - 600;
        env.write(&[
            assistant(n, &[("u1", "TaskCreate", json!({"subject": "x"}))]),
            result(n + 1, "u1", "Error: invalid", None),
        ]);
        let state = env.load();
        assert!(state.tasks.is_empty() && state.pending.is_empty());
    }

    #[test]
    fn finished_list_hidden_after_a_while() {
        let env = Env::new();
        let n = NOW - DONE_HIDE_SEC - 100;
        let mut recs = create(n, "u1", 1, "A", "");
        recs.push(task_update(n + 5, "u2", json!({"taskId": "1", "status": "completed"})));
        env.write(&recs);
        let state = env.load();
        assert_eq!(progress_token(&summarize(&state, n + 60)), "▰▰▰▰ 1/1 ✔");
        assert_eq!(progress_token(&summarize(&state, NOW)), "");
    }

    #[test]
    fn request_blob_does_not_override() {
        let env = Env::new();
        let n = NOW - 600;
        let blob = json!({"type": "api-request-blob", "message": {"content": [{"type": "tool_use", "id": "a1", "name": "Agent", "input": {}}]}});
        env.write(&[
            assistant(
                n,
                &[(
                    "a1",
                    "Agent",
                    json!({"description": "調べる", "subagent_type": "Explore"}),
                )],
            ),
            blob,
        ]);
        assert_eq!(env.load().agents["a1"].ts, n);
    }

    #[test]
    fn prompts_and_activity() {
        let env = Env::new();
        let n = NOW - 600;
        let mut meta = prompt(n + 1, "skill text");
        meta["isMeta"] = json!(true);
        env.write(&[prompt(n, "依頼"), meta, assistant(n + 5, &[]), assistant(n + 70, &[])]);
        let state = env.load();
        assert_eq!(state.prompts, vec![n]);
        assert_eq!(state.minutes.values().sum::<u32>(), 2);
    }

    #[test]
    fn subagent_status_and_task_assignment() {
        let env = Env::new();
        let n = NOW - 600;
        let mut recs = create(n, "u1", 1, "レビュー", "レビュー中");
        recs.push(assistant(
            n + 2,
            &[(
                "a0",
                "Agent",
                json!({"description": "タスク前", "subagent_type": "Explore"}),
            )],
        ));
        recs.push(task_update(
            n + 5,
            "u2",
            json!({"taskId": "1", "status": "in_progress"}),
        ));
        recs.push(assistant(
            n + 10,
            &[(
                "a1",
                "Agent",
                json!({"description": "観点1", "subagent_type": "reviewer"}),
            )],
        ));
        recs.push(assistant(
            n + 10,
            &[(
                "a2",
                "Agent",
                json!({"description": "観点2", "subagent_type": "reviewer"}),
            )],
        ));
        env.write(&recs);
        env.subagent("x0", Some("a0"), "タスク前", n + 50, json!({"finished": true}));
        env.subagent("x1", Some("a1"), "観点1", NOW - 30, json!({}));
        env.subagent("x2", Some("a2"), "観点2", NOW - STALE_SEC - 1, json!({}));
        let state = env.load();
        let subs: BTreeMap<&str, &Sub> = state.subs.values().map(|s| (s.desc.as_str(), s)).collect();
        assert_eq!(
            subs.iter().map(|(d, s)| (*d, s.state.as_str())).collect::<Vec<_>>(),
            vec![("タスク前", "done"), ("観点1", "running"), ("観点2", "stopped")]
        );
        assert_eq!(
            subs.iter().map(|(d, s)| (*d, s.task)).collect::<Vec<_>>(),
            vec![("タスク前", None), ("観点1", Some(1)), ("観点2", Some(1))]
        );
        assert_eq!(subs["タスク前"].end.unwrap() - subs["タスク前"].start.unwrap(), 48);
        assert_eq!(progress_token(&summarize(&state, NOW)), "▱▱▱▱ 0/1 ⟳1 レビュー中");
    }

    #[test]
    fn stale_subagent_can_come_back() {
        let env = Env::new();
        let n = NOW - STALE_SEC - 100;
        env.write(&[assistant(n, &[("a1", "Agent", json!({"description": "遅い"}))])]);
        env.subagent("x1", Some("a1"), "遅い", n + 10, json!({}));
        assert_eq!(
            env.load().subs.values().map(|s| s.state.clone()).collect::<Vec<_>>(),
            vec!["stopped"]
        );
        env.subagent("x1", Some("a1"), "遅い", NOW - 5, json!({"finished": true}));
        assert_eq!(
            env.load().subs.values().map(|s| s.state.clone()).collect::<Vec<_>>(),
            vec!["done"]
        );
    }

    #[test]
    fn subagent_without_parent_tool_use() {
        let env = Env::new();
        env.write(&[assistant(NOW - 100, &[])]);
        let log = env.dir.join(SID).join("subagents").join("agent-x1.jsonl");
        fs::create_dir_all(log.parent().unwrap()).unwrap();
        fs::write(
            &log,
            format!("{}\n", json!({"type": "user", "timestamp": iso(NOW - 50)})),
        )
        .unwrap();
        env.subagent("x1", None, "スキル経由", NOW - 10, json!({}));
        // 保持期間より前に終わったものは読まない
        env.subagent("old", None, "古い", NOW - KEEP_SEC - 1, json!({"finished": true}));
        let state = env.load();
        let subs: Vec<_> = state
            .subs
            .values()
            .map(|s| (s.desc.as_str(), s.start, s.state.as_str()))
            .collect();
        assert_eq!(subs, vec![("スキル経由", Some(NOW - 50), "running")]);
    }

    #[test]
    fn running_without_tasks() {
        let env = Env::new();
        let long = "長い説明".repeat(10);
        env.write(&[assistant(NOW - 60, &[("a1", "Agent", json!({"description": long}))])]);
        env.subagent("x1", Some("a1"), &long, NOW, json!({}));
        let token = progress_token(&summarize(&env.load(), NOW));
        assert!(token.starts_with("⟳1 長い説明"), "{token}");
        assert!(width(&token) <= TOKEN_WIDTH);
    }

    #[test]
    fn reads_only_appended_lines() {
        let env = Env::new();
        let n = NOW - 600;
        env.write(&create(n, "u1", 1, "A", ""));
        let first = env.load().offset;
        // 書き込み途中の行は読まない
        let partial = task_update(n + 5, "u2", json!({"taskId": "1", "status": "in_progress"})).to_string();
        OpenOptions::new()
            .append(true)
            .open(&env.path)
            .unwrap()
            .write_all(&partial.as_bytes()[..20])
            .unwrap();
        assert_eq!(env.load().offset, first);
        // 縮んだら(書き直されたら)最初から読み直す。タスクは消える
        env.rewrite(&[task_update(
            n + 5,
            "u2",
            json!({"taskId": "1", "status": "in_progress"}),
        )]);
        assert!(env.load().tasks.is_empty());
        env.write(&create(n + 10, "u3", 1, "B", ""));
        let state = env.load();
        assert_eq!(state.tasks[&1].subject, "B");
        assert_eq!(state.offset, fs::metadata(&env.path).unwrap().len());
    }

    #[test]
    fn uses_cache_between_runs() {
        let env = Env::new();
        env.write(&create(NOW - 600, "u1", 1, "A", ""));
        env.load();
        // キャッシュに読んだ分が残っていれば、既読部分を壊しても結果は変わらない
        let mut f = OpenOptions::new().write(true).open(&env.path).unwrap();
        f.write_all(b"xxxxxxxxxx").unwrap();
        assert_eq!(env.load().tasks[&1].subject, "A");
    }

    #[test]
    fn missing_transcript() {
        let env = Env::new();
        assert!(
            update(&env.ctx, "ffffffff-0000-4000-8000-000000000000", NOW)
                .unwrap()
                .is_none()
        );
    }

    #[test]
    fn truncate_by_display_width() {
        assert_eq!(truncate("あいうえお", 6), "あい…");
        assert_eq!(truncate("abc", 3), "abc");
    }

    #[test]
    fn tab_summary_joins_counts() {
        let sub = Sub {
            desc: String::new(),
            kind: String::new(),
            start: None,
            end: None,
            task: None,
            state: "running".into(),
            fin: false,
        };
        let a = Summary {
            done: 1,
            total: 3,
            current: String::new(),
            running: vec![sub],
        };
        let b = Summary {
            done: 2,
            total: 2,
            current: String::new(),
            running: vec![],
        };
        assert_eq!(tab_summary(&[a, b]), "TASK 3/5 · SUB 1⟳");
        assert_eq!(
            tab_summary(&[Summary {
                done: 0,
                total: 0,
                current: String::new(),
                running: vec![]
            }]),
            ""
        );
    }

    #[test]
    fn created_id_from_text() {
        assert_eq!(created_id("Task #12 created successfully: x"), Some(12));
        assert_eq!(created_id("Error: Task #3 not found"), None);
    }
}
