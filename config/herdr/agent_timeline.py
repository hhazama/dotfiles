#!/usr/bin/env python3
"""herdr 上の Claude Code セッションのタスクツリーと進捗を出す。

  report  tab_bar_right から呼ぶ。各ペインの $progress token を更新し、タブ行用の集計を1行出す
  view    ポップアップ。全セッションのタスクツリーと直近のタイムラインを描画する
"""
import glob
import json
import os
import re
import select
import shutil
import subprocess
import sys
import termios
import time
import traceback
import tty
import unicodedata
from datetime import datetime

PROJECTS = os.path.expanduser("~/.claude/projects")
CACHE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "herdr-agent-timeline")
HERDR = os.environ.get("HERDR_BIN_PATH") or "herdr"
SOURCE = "agent-timeline"
# キャッシュの形を変えたら上げる。tmpfs のキャッシュは herdr を使っている間ずっと残るため
CACHE_VERSION = 3
WINDOW_SEC = 60 * 60
KEEP_SEC = 3 * 60 * 60
# Claude が落ちたときやチームメイトは meta.json に finished が付かないため、更新が止まったものは実行中とみなさない。
# 完了したサブエージェントの書き込み間隔は p99 で約15分だった
STALE_SEC = 20 * 60
DONE_HIDE_SEC = 30 * 60
TOKEN_WIDTH = 34
TASK_CREATED = re.compile(r"Task #(\d+) created")


def parse_ts(value):
    try:
        return int(datetime.fromisoformat(value).timestamp())
    except (TypeError, ValueError):
        return None


def new_state(path, ino):
    return {
        "v": CACHE_VERSION,
        "path": path,
        "ino": ino,
        "offset": 0,
        "tasks": {},
        "pending": {},
        "agents": {},
        "minutes": {},
        "prompts": [],
        "subs": {},
    }


def feed(state, rec):
    ts = parse_ts(rec.get("timestamp"))
    kind = rec.get("type")
    # api-request-blob などの控えにも同じ tool_use が timestamp なしで再出現するため、会話の行だけを見る
    if ts is None or kind not in ("assistant", "user"):
        return
    content = (rec.get("message") or {}).get("content")
    if kind == "assistant":
        minute = str(ts // 60 * 60)
        state["minutes"][minute] = state["minutes"].get(minute, 0) + 1
    elif isinstance(content, str) and not rec.get("isMeta"):
        state["prompts"].append(ts)
    if not isinstance(content, list):
        return
    for item in content:
        if not isinstance(item, dict):
            continue
        if kind == "assistant" and item.get("type") == "tool_use":
            on_tool_use(state, item.get("id"), item.get("name"), item.get("input") or {}, ts)
        elif kind == "user" and item.get("type") == "tool_result" and item.get("tool_use_id") in state["pending"]:
            on_task_created(state, item, rec.get("toolUseResult"))


def on_tool_use(state, use_id, name, inp, ts):
    tasks = state["tasks"]
    if name == "TaskCreate":
        state["pending"][use_id] = {"subject": inp.get("subject", ""), "active": inp.get("activeForm", ""), "ts": ts}
    elif name == "TaskUpdate":
        task = tasks.get(str(inp.get("taskId")))
        if task is None:
            return
        status = inp.get("status")
        if status == "deleted":
            del tasks[str(inp.get("taskId"))]
            return
        if status:
            task["status"] = status
            if status == "in_progress" and task.get("start") is None:
                task["start"] = ts
            if status == "completed":
                task["done"] = ts
        if inp.get("subject"):
            task["subject"] = inp["subject"]
        if inp.get("activeForm"):
            task["active"] = inp["activeForm"]
        for dep in inp.get("addBlockedBy") or []:
            task["blocked"].append(str(dep))
        for dep in inp.get("addBlocks") or []:
            if str(dep) in tasks:
                tasks[str(dep)]["blocked"].append(str(inp.get("taskId")))
    elif name == "Agent":
        state["agents"][use_id] = {
            "desc": inp.get("description", ""),
            "type": inp.get("subagent_type") or "general-purpose",
            "ts": ts,
            "task": current_task(tasks),
        }


def on_task_created(state, item, structured):
    pend = state["pending"].pop(item["tool_use_id"])
    task_id = (structured.get("task") or {}).get("id") if isinstance(structured, dict) else None
    if task_id is None:
        body = item.get("content")
        if isinstance(body, list):
            body = " ".join(c.get("text", "") for c in body if isinstance(c, dict))
        m = TASK_CREATED.search(body or "")
        task_id = m.group(1) if m else None
    if task_id is None:
        return
    task_id = str(task_id)
    if state["tasks"] and int(task_id) <= max(int(t) for t in state["tasks"]):
        # 同じセッションでもタスク一覧が作り直されると #1 から振り直される。古い一覧は捨てる
        state["tasks"] = {}
        for owner in list(state["agents"].values()) + list(state["subs"].values()):
            owner["task"] = None
    state["tasks"][task_id] = {
        "subject": pend["subject"],
        "active": pend["active"],
        "status": "pending",
        "blocked": [],
        "start": None,
        "done": None,
    }


def current_task(tasks):
    """最後に着手した in_progress のタスク id。サブエージェントをぶら下げる先に使う。"""
    running = [(t["start"], tid) for tid, t in tasks.items() if t["status"] == "in_progress"]
    return max(running)[1] if running else None


def find_transcript(session_id):
    hits = glob.glob(os.path.join(PROJECTS, "*", session_id + ".jsonl"))
    return max(hits, key=os.path.getmtime) if hits else None


def load_cache(session_id):
    try:
        with open(os.path.join(CACHE_DIR, session_id + ".json")) as f:
            state = json.load(f)
        return state if state.get("v") == CACHE_VERSION else None
    except (OSError, ValueError):
        return None


def save_cache(session_id, state):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, session_id + ".json")
    tmp = f"{path}.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(state, f, ensure_ascii=False)
    os.replace(tmp, path)


def update(session_id, now):
    state = load_cache(session_id)
    path = state["path"] if state and os.path.exists(state["path"]) else find_transcript(session_id)
    if not path:
        return None
    st = os.stat(path)
    if state is None or state["path"] != path or state["ino"] != st.st_ino or st.st_size < state["offset"]:
        state = new_state(path, st.st_ino)
    changed = st.st_size > state["offset"]
    if changed:
        with open(path, "rb") as f:
            f.seek(state["offset"])
            for line in f:
                # 書き込み途中の最終行は次回読み直す
                if not line.endswith(b"\n"):
                    break
                state["offset"] += len(line)
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if isinstance(rec, dict):
                    feed(state, rec)
        prune(state, now)
    changed |= refresh_subs(state, now)
    if changed:
        save_cache(session_id, state)
    return state


def prune(state, now):
    cutoff = now - KEEP_SEC
    state["minutes"] = {k: v for k, v in state["minutes"].items() if int(k) >= cutoff}
    state["prompts"] = [t for t in state["prompts"] if t >= cutoff]
    state["agents"] = {k: v for k, v in state["agents"].items() if v["ts"] >= cutoff}


def refresh_subs(state, now):
    """subagents/*.meta.json から各サブエージェントの状態を取る。終わったものは読み直さない。"""
    sub_dir = state["path"][: -len(".jsonl")] + "/subagents"
    try:
        names = [n for n in os.listdir(sub_dir) if n.endswith(".meta.json")]
    except OSError:
        return False
    changed = False
    subs = state["subs"]
    for name in names:
        known = subs.get(name)
        if known and known["final"]:
            continue
        log = os.path.join(sub_dir, name[: -len(".meta.json")] + ".jsonl")
        try:
            end = int(os.path.getmtime(log))
            if known is None and end < now - KEEP_SEC:
                continue
            with open(os.path.join(sub_dir, name)) as f:
                meta = json.load(f)
        except (OSError, ValueError):
            continue
        agent = state["agents"].get(meta.get("toolUseId"))
        if known:
            start, task = known["start"], known["task"]
        elif agent:
            start, task = agent["ts"], agent["task"]
        else:
            # スキル経由やチームメイトは親に Agent の tool_use が無いので、サブエージェント自身の記録から取る
            start, task = first_ts(log), None
        if meta.get("finished"):
            sub_state = "done"
        elif meta.get("stoppedByUser") or now - end > STALE_SEC:
            sub_state = "stopped"
        else:
            sub_state = "running"
        entry = {
            "desc": meta.get("description") or meta.get("name") or (agent or {}).get("desc", ""),
            "type": meta.get("agentType") or (agent or {}).get("type", ""),
            "start": start,
            "end": None if sub_state == "running" else end,
            "task": task,
            "state": sub_state,
            # 更新が止まっただけのものは、後で再開・完了することがあるので読み直す
            "final": bool(meta.get("finished") or meta.get("stoppedByUser")),
        }
        if entry != known:
            subs[name] = entry
            changed = True
    cutoff = now - KEEP_SEC
    for name in [n for n, s in subs.items() if s["end"] is not None and s["end"] < cutoff]:
        del subs[name]
        changed = True
    return changed


def first_ts(path):
    try:
        with open(path, "rb") as f:
            for _, line in zip(range(20), f):
                try:
                    ts = parse_ts(json.loads(line).get("timestamp"))
                except (ValueError, AttributeError):
                    continue
                if ts is not None:
                    return ts
    except OSError:
        pass
    return None


def width(text):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 0 if unicodedata.combining(c) else 1 for c in text)


def truncate(text, limit):
    if width(text) <= limit:
        return text
    out, used = [], 0
    for c in text:
        if used + width(c) > limit - 1:
            break
        out.append(c)
        used += width(c)
    return "".join(out) + "…"


def summarize(state, now):
    tasks = state["tasks"]
    done = sum(1 for t in tasks.values() if t["status"] == "completed")
    total = len(tasks)
    # 終わった作業の一覧がサイドバーに残り続けると、動いているセッションが見分けにくくなる
    if total and done == total and max(t["done"] for t in tasks.values()) < now - DONE_HIDE_SEC:
        done = total = 0
    running = [s for s in state["subs"].values() if s["state"] == "running"]
    cur = tasks.get(current_task(tasks) or "")
    return {
        "done": done,
        "total": total,
        "current": (cur["active"] or cur["subject"]) if cur else "",
        "running": running,
    }


def progress_token(summary):
    """サイドバーのエージェント行に出す1行。出すものが無ければ空文字。"""
    done, total, running = summary["done"], summary["total"], summary["running"]
    parts = []
    if total:
        filled = round(4 * done / total)
        parts.append("▰" * filled + "▱" * (4 - filled) + f" {done}/{total}")
    if running:
        parts.append(f"⟳{len(running)}")
    if total:
        parts.append(summary["current"] or ("✔" if done == total else ""))
    elif running:
        parts.append(max(running, key=lambda s: s["start"] or 0)["desc"])
    return truncate(" ".join(p for p in parts if p), TOKEN_WIDTH)


def tab_summary(summaries):
    done = sum(s["done"] for s in summaries)
    total = sum(s["total"] for s in summaries)
    running = sum(len(s["running"]) for s in summaries)
    parts = []
    if total:
        parts.append(f"TASK {done}/{total}")
    if running:
        parts.append(f"SUB {running}⟳")
    return " · ".join(parts)


def claude_agents():
    try:
        out = subprocess.run([HERDR, "agent", "list"], capture_output=True, text=True, timeout=3).stdout
        agents = json.loads(out)["result"]["agents"]
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        return []
    return [a for a in agents if a.get("agent") == "claude" and (a.get("agent_session") or {}).get("value")]


def report():
    try:
        print(collect_and_report())
    except Exception:
        # 失敗するとタブ行のエントリも token も黙って消えるだけなので、壊れたことが見えるようにする
        os.makedirs(CACHE_DIR, exist_ok=True)
        # 5秒ごとに失敗し続けても tmpfs を食わないよう、最新の1件だけ残す
        with open(os.path.join(CACHE_DIR, "error.log"), "w") as f:
            f.write(f"--- {datetime.now().isoformat()}\n{traceback.format_exc()}")
        print("TL ERR")


def collect_and_report():
    now = int(time.time())
    remove_old_caches(now)
    summaries = []
    for agent in claude_agents():
        state = update(agent["agent_session"]["value"], now)
        summary = summarize(state, now) if state else None
        token = progress_token(summary) if summary else ""
        cmd = [HERDR, "pane", "report-metadata", agent["pane_id"], "--source", SOURCE, "--ttl-ms", "30000"]
        cmd += ["--token", f"progress={token}"] if token else ["--clear-token", "progress"]
        subprocess.run(cmd, capture_output=True, timeout=3)
        if summary:
            summaries.append(summary)
    return tab_summary(summaries)


def remove_old_caches(now):
    for path in glob.glob(os.path.join(CACHE_DIR, "*.json")):
        if os.path.getmtime(path) < now - 24 * 60 * 60:
            os.remove(path)


RESET = "\x1b[0m"
COLORS = {
    "dim": "\x1b[38;2;147;146;147m",
    "green": "\x1b[38;2;169;220;118m",
    "yellow": "\x1b[38;2;255;216;102m",
    "red": "\x1b[38;2;255;97;136m",
    "cyan": "\x1b[38;2;120;220;232m",
    "mauve": "\x1b[38;2;171;157;242m",
    "bold": "\x1b[1m",
    "rev": "\x1b[7m",
}
STATUS_COLOR = {"working": "yellow", "blocked": "red", "done": "green", "idle": "dim"}
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def paint(text, *styles):
    return "".join(COLORS[s] for s in styles) + text + RESET if styles else text


def fit(line, cols):
    out, used, pos = [], 0, 0
    for m in ANSI.finditer(line + "\x1b[0m"):
        for c in line[pos : m.start()]:
            w = width(c)
            if used + w > cols:
                return "".join(out) + RESET
            out.append(c)
            used += w
        out.append(m.group(0))
        pos = m.end()
    return "".join(out)


def duration(sec):
    sec = max(0, int(sec))
    if sec < 60:
        return f"{sec}s"
    if sec < 3600:
        return f"{sec // 60}m{sec % 60:02d}s"
    return f"{sec // 3600}h{sec % 3600 // 60:02d}m"


def visible_subs(state, now):
    subs = [s for s in state["subs"].values() if s["state"] == "running" or s["end"] >= now - WINDOW_SEC]
    return sorted(subs, key=lambda s: s["start"] or 0)


def sub_line(sub, now, indent):
    if sub["state"] == "running":
        icon, color, took = "⟳", "cyan", now - (sub["start"] or now)
    elif sub["state"] == "done":
        icon, color, took = "✔", "dim", sub["end"] - (sub["start"] or sub["end"])
    else:
        icon, color, took = "✖", "red", sub["end"] - (sub["start"] or sub["end"])
    return f"{indent}{paint(icon, color)} {paint(sub['type'], 'mauve')}  {sub['desc']}  {paint(duration(took), 'dim')}"


def tree_lines(state, now):
    tasks = state["tasks"]
    subs = visible_subs(state, now)
    lines = []
    items = list(tasks.items())
    completed = [tid for tid, t in items if t["status"] == "completed"]
    # 完了が多いと実行中のタスクが画面外に押し出されるので畳む
    folded = set(completed[:-2]) if len(completed) > 6 else set()
    if folded:
        lines.append(("", f"{paint('✔', 'green')} {paint(f'完了 {len(folded)} 件(省略)', 'dim')}"))
    shown = [(tid, t) for tid, t in items if tid not in folded]
    for i, (tid, task) in enumerate(shown):
        last = i == len(shown) - 1 and not any(s["task"] not in tasks for s in subs)
        branch, child = ("└", "   ") if last else ("├", "│  ")
        status = task["status"]
        waiting = [d for d in task["blocked"] if d in tasks and tasks[d]["status"] != "completed"]
        if status == "completed":
            took = f"  {paint(duration(task['done'] - task['start']), 'dim')}" if task["start"] and task["done"] else ""
            text = f"{paint('✔', 'green')} #{tid} {paint(task['subject'], 'dim')}{took}"
        elif status == "in_progress":
            since = f"  {paint(duration(now - task['start']), 'dim')}" if task["start"] else ""
            text = f"{paint('◐', 'yellow')} #{tid} {paint(task['active'] or task['subject'], 'yellow', 'bold')}{since}"
        else:
            wait = paint("  ⧗" + ",".join("#" + d for d in waiting), "red") if waiting else ""
            text = f"{paint('○', 'dim')} #{tid} {task['subject']}{wait}"
        lines.append((branch, text))
        for sub in subs:
            if sub["task"] == tid:
                lines.append((child, sub_line(sub, now, "└ ")))
    orphans = [s for s in subs if s["task"] not in tasks]
    if orphans:
        lines.append(("└", paint("タスク外のサブエージェント" if tasks else "サブエージェント", "dim")))
        for sub in orphans:
            lines.append(("   ", sub_line(sub, now, "")))
    return [f"   {b} {t}" if b else f"     {t}" for b, t in lines]


def lane(cols, now, value_at):
    span = WINDOW_SEC / cols
    return "".join(value_at(now - WINDOW_SEC + i * span, now - WINDOW_SEC + (i + 1) * span) for i in range(cols))


def timeline_lines(state, now, cols):
    minutes = {int(k): v for k, v in state["minutes"].items()}
    prompts = state["prompts"]
    subs = list(state["subs"].values())
    done_at = [t["done"] for t in state["tasks"].values() if t["done"]]

    def activity(a, b):
        if any(a <= p < b for p in prompts):
            return paint("▼", "mauve")
        n = sum(v for m, v in minutes.items() if m < b and m + 60 > a)
        return paint("·", "dim") if n == 0 else paint("▃" if n < 3 else "▆" if n < 10 else "█", "yellow")

    def concurrency(a, b):
        n = sum(1 for s in subs if (s["start"] or now) < b and (s["end"] or now) > a)
        return " " if n == 0 else paint("░▒▓█"[min(n, 4) - 1], "cyan")

    def completions(a, b):
        return paint("✔", "green") if any(a <= d < b for d in done_at) else " "

    # 動きのないセッションの空のレーンで一覧が埋まらないようにする
    if not any(m >= now - WINDOW_SEC for m in minutes):
        return []
    start = datetime.fromtimestamp(now - WINDOW_SEC).strftime("%H:%M")
    end = datetime.fromtimestamp(now).strftime("%H:%M")
    rows = [(start, activity, "本体")]
    if any((s["end"] or now) >= now - WINDOW_SEC for s in subs):
        rows.append(("", concurrency, "sub"))
    if any(d >= now - WINDOW_SEC for d in done_at):
        rows.append(("", completions, "完了"))
    return [f"   {label:>5} ▕{lane(cols, now, fn)}▏ {paint(name, 'dim')}{'  ' + end if label else ''}" for label, fn, name in rows]


def render(agents, states, selected, cols, rows, now):
    header = f" {paint('Agent Timeline', 'bold')}  {datetime.fromtimestamp(now).strftime('%H:%M:%S')}   {paint('j/k:選択  Enter:移動  q:閉じる   ▼依頼 ▃▆█活動量 ░▒▓█サブエージェント同時数 ✔タスク完了', 'dim')}"
    blocks = []
    for i, agent in enumerate(agents):
        state = states[i]
        status = agent.get("agent_status", "unknown")
        mark = paint("▶", "cyan") if i == selected else " "
        title = agent.get("terminal_title_stripped") or agent.get("cwd", "")
        head = f" {mark} {paint(agent['pane_id'], 'dim')} {paint(title, 'bold', 'rev') if i == selected else paint(title, 'bold')}  {paint(status, STATUS_COLOR.get(status, 'dim'))}"
        block = [head]
        if state:
            summary = summarize(state, now)
            token = progress_token(summary)
            if token:
                block[0] += f"  {paint(token, 'cyan')}"
            block += tree_lines(state, now)
            block += timeline_lines(state, now, max(10, min(120, cols - 26)))
        else:
            block.append(paint("     transcript が見つかりません", "dim"))
        blocks.append(block + [""])
    if not agents:
        blocks.append([paint("  Claude Code のエージェントがいません", "dim")])
    # 選んだエージェントのブロックが画面に入るように先頭をずらす
    top = sum(len(b) for b in blocks[:selected])
    body = [line for b in blocks for line in b]
    avail = rows - 2
    sel_len = len(blocks[selected])
    offset = max(0, min(top, top + sel_len - avail)) if top + sel_len > avail else 0
    lines = [header, ""] + body[offset : offset + avail]
    return "\x1b[H" + "\x1b[K\r\n".join(fit(line, cols) for line in lines) + "\x1b[K\x1b[J"


ARROWS = {"\x1b[A": "up", "\x1b[B": "down", "\x1bOA": "up", "\x1bOB": "down"}


def read_keys(timeout):
    """押されたキーを順に返す。連打や貼り付けで複数のキーが1回の read に入るため分解する。"""
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if not ready:
        return []
    data = os.read(sys.stdin.fileno(), 64).decode(errors="ignore")
    keys, i = [], 0
    while i < len(data):
        seq = next((q for q in ARROWS if data.startswith(q, i)), None)
        keys.append(ARROWS[seq] if seq else data[i])
        i += len(seq) if seq else 1
    return keys


def view():
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    selected, focus = 0, None
    sys.stdout.write("\x1b[?1049h\x1b[?25l")
    try:
        tty.setcbreak(fd)
        while True:
            now = int(time.time())
            agents = claude_agents()
            states = [update(a["agent_session"]["value"], now) for a in agents]
            selected = min(selected, max(0, len(agents) - 1))
            cols, rows = shutil.get_terminal_size()
            sys.stdout.write(render(agents, states, selected, cols, rows, now))
            sys.stdout.flush()
            keys = read_keys(2)
            for key in keys:
                if key in ("j", "down"):
                    selected = min(selected + 1, max(0, len(agents) - 1))
                elif key in ("k", "up"):
                    selected = max(selected - 1, 0)
            if ("\r" in keys or "\n" in keys) and agents:
                focus = agents[selected]["pane_id"]
                break
            if "q" in keys or "\x1b" in keys:
                break
    except KeyboardInterrupt:
        pass
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        sys.stdout.write("\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()
    if focus:
        subprocess.run([HERDR, "agent", "focus", focus], capture_output=True, timeout=3)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "report":
        report()
    elif command == "view":
        view()
    else:
        sys.exit(__doc__)
