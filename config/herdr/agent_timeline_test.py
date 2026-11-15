"""agent_timeline.py の単体テスト。transcript の形式は Claude Code 2.1 系の実物に合わせた架空データ。

実行: /usr/bin/python3 -I config/herdr/agent_timeline_test.py
"""
import json
import os
import sys
from contextlib import redirect_stdout
from io import StringIO
import tempfile
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import agent_timeline as tl  # noqa: E402

SID = "00000000-0000-4000-8000-000000000000"


def iso(ts):
    return time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime(ts))


def assistant(ts, *uses):
    content = [{"type": "tool_use", "id": i, "name": n, "input": inp} for i, n, inp in uses]
    return {"type": "assistant", "timestamp": iso(ts), "message": {"role": "assistant", "content": content}}


def result(ts, use_id, text, structured=None):
    content = [{"tool_use_id": use_id, "type": "tool_result", "content": text}]
    rec = {"type": "user", "timestamp": iso(ts), "message": {"role": "user", "content": content}}
    if structured is not None:
        rec["toolUseResult"] = structured
    return rec


def prompt(ts, text):
    return {"type": "user", "timestamp": iso(ts), "message": {"role": "user", "content": text}}


def create(ts, use_id, task_id, subject, active=""):
    return [
        assistant(ts, (use_id, "TaskCreate", {"subject": subject, "description": "d", "activeForm": active})),
        result(ts + 1, use_id, f"Task #{task_id} created successfully: {subject}"),
    ]


def task_update(ts, use_id, **inp):
    return assistant(ts, (use_id, "TaskUpdate", inp))


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        tl.PROJECTS = os.path.join(self.tmp.name, "projects")
        tl.CACHE_DIR = os.path.join(self.tmp.name, "cache")
        self.dir = os.path.join(tl.PROJECTS, "-repo")
        os.makedirs(self.dir)
        self.path = os.path.join(self.dir, SID + ".jsonl")
        self.now = 1_800_000_000

    def tearDown(self):
        self.tmp.cleanup()

    def load(self):
        state = tl.update(SID, self.now)
        assert state is not None
        return state

    def write(self, records, mode="a"):
        with open(self.path, mode) as f:
            for r in records:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")

    def subagent(self, agent_id, use_id, desc, mtime, **flags):
        sub_dir = os.path.join(self.dir, SID, "subagents")
        os.makedirs(sub_dir, exist_ok=True)
        meta = {"agentType": "reviewer", "description": desc, "toolUseId": use_id, **flags}
        with open(os.path.join(sub_dir, f"agent-{agent_id}.meta.json"), "w") as f:
            json.dump(meta, f)
        log = os.path.join(sub_dir, f"agent-{agent_id}.jsonl")
        open(log, "w").close()
        os.utime(log, (mtime, mtime))


class TaskTest(Base):
    def test_create_and_progress(self):
        n = self.now - 600
        self.write(
            create(n, "u1", "1", "調査", "調査中")
            + create(n + 10, "u2", "2", "実装", "実装中")
            + create(n + 20, "u3", "3", "検証")
            + [
                task_update(n + 30, "u4", taskId="1", status="in_progress"),
                task_update(n + 90, "u5", taskId="1", status="completed"),
                task_update(n + 100, "u6", taskId="2", status="in_progress"),
                task_update(n + 110, "u7", taskId="3", addBlockedBy=["2"]),
            ]
        )
        state = self.load()
        self.assertEqual([(k, t["status"]) for k, t in state["tasks"].items()], [("1", "completed"), ("2", "in_progress"), ("3", "pending")])
        self.assertEqual(state["tasks"]["1"]["done"] - state["tasks"]["1"]["start"], 60)
        self.assertEqual(state["tasks"]["3"]["blocked"], ["2"])
        summary = tl.summarize(state, self.now)
        self.assertEqual((summary["done"], summary["total"], summary["current"]), (1, 3, "実装中"))
        self.assertEqual(tl.progress_token(summary), "▰▱▱▱ 1/3 実装中")

    def test_deleted_task_disappears(self):
        n = self.now - 600
        self.write(create(n, "u1", "1", "不要") + [task_update(n + 5, "u2", taskId="1", status="deleted")])
        self.assertEqual(self.load()["tasks"], {})

    def test_renumbered_list_replaces_old_one(self):
        n = self.now - 600
        self.write(
            create(n, "u1", "1", "旧1")
            + create(n + 1, "u2", "2", "旧2")
            + [task_update(n + 2, "u3", taskId="1", status="in_progress")]
            + [assistant(n + 3, ("a1", "Agent", {"description": "旧の子"}))]
            + create(n + 10, "u4", "1", "新1")
        )
        state = self.load()
        self.assertEqual({k: t["subject"] for k, t in state["tasks"].items()}, {"1": "新1"})
        self.assertIsNone(state["agents"]["a1"]["task"])

    def test_renumbered_from_middle_and_structured_id(self):
        n = self.now - 600
        new = assistant(n + 10, ("u4", "TaskCreate", {"subject": "新", "activeForm": ""}))
        # 構造化された結果を優先し、本文の番号は見ない
        self.write(
            create(n, "u1", "1", "旧1")
            + create(n + 1, "u2", "2", "旧2")
            + create(n + 2, "u3", "3", "旧3")
            + [new, result(n + 11, "u4", "Task #9 created successfully: 新", {"task": {"id": "2", "subject": "新"}})]
        )
        self.assertEqual({k: t["subject"] for k, t in self.load()["tasks"].items()}, {"2": "新"})

    def test_failed_create_is_ignored(self):
        n = self.now - 600
        self.write([assistant(n, ("u1", "TaskCreate", {"subject": "x"})), result(n + 1, "u1", "Error: invalid")])
        state = self.load()
        self.assertEqual((state["tasks"], state["pending"]), ({}, {}))

    def test_finished_list_hidden_after_a_while(self):
        n = self.now - tl.DONE_HIDE_SEC - 100
        self.write(create(n, "u1", "1", "A") + [task_update(n + 5, "u2", taskId="1", status="completed")])
        state = self.load()
        self.assertEqual(tl.progress_token(tl.summarize(state, n + 60)), "▰▰▰▰ 1/1 ✔")
        self.assertEqual(tl.progress_token(tl.summarize(state, self.now)), "")

    def test_request_blob_does_not_override(self):
        n = self.now - 600
        agent = ("a1", "Agent", {"description": "調べる", "subagent_type": "Explore", "prompt": "p"})
        blob = {"type": "api-request-blob", "message": {"content": [{"type": "tool_use", "id": "a1", "name": "Agent", "input": {}}]}}
        self.write([assistant(n, agent), blob])
        self.assertEqual(self.load()["agents"]["a1"]["ts"], n)

    def test_prompts_and_activity(self):
        n = self.now - 600
        meta = dict(prompt(n + 1, "skill text"), isMeta=True)
        self.write([prompt(n, "依頼"), meta, assistant(n + 5), assistant(n + 70)])
        state = self.load()
        self.assertEqual(state["prompts"], [n])
        self.assertEqual(sum(state["minutes"].values()), 2)


class SubagentTest(Base):
    def test_status_and_task_assignment(self):
        n = self.now - 600
        self.write(
            create(n, "u1", "1", "レビュー", "レビュー中")
            + [
                assistant(n + 2, ("a0", "Agent", {"description": "タスク前", "subagent_type": "Explore"})),
                task_update(n + 5, "u2", taskId="1", status="in_progress"),
                assistant(n + 10, ("a1", "Agent", {"description": "観点1", "subagent_type": "reviewer"})),
                assistant(n + 10, ("a2", "Agent", {"description": "観点2", "subagent_type": "reviewer"})),
            ]
        )
        self.subagent("x0", "a0", "タスク前", n + 50, finished=True)
        self.subagent("x1", "a1", "観点1", self.now - 30)
        self.subagent("x2", "a2", "観点2", self.now - tl.STALE_SEC - 1)
        state = self.load()
        subs = {s["desc"]: s for s in state["subs"].values()}
        self.assertEqual({d: s["state"] for d, s in subs.items()}, {"タスク前": "done", "観点1": "running", "観点2": "stopped"})
        self.assertEqual({d: s["task"] for d, s in subs.items()}, {"タスク前": None, "観点1": "1", "観点2": "1"})
        self.assertEqual(subs["タスク前"]["end"] - subs["タスク前"]["start"], 48)
        self.assertEqual(tl.progress_token(tl.summarize(state, self.now)), "▱▱▱▱ 0/1 ⟳1 レビュー中")

    def test_subagent_without_parent_tool_use(self):
        self.write([assistant(self.now - 100)])
        self.subagent("x1", None, "スキル経由", self.now - 10)
        log = os.path.join(self.dir, SID, "subagents", "agent-x1.jsonl")
        with open(log, "w") as f:
            f.write(json.dumps({"type": "user", "timestamp": iso(self.now - 50)}) + "\n")
        os.utime(log, (self.now - 10, self.now - 10))
        # 保持期間より前に終わったものは読まない
        self.subagent("old", None, "古い", self.now - tl.KEEP_SEC - 1, finished=True)
        subs = self.load()["subs"]
        self.assertEqual([(s["desc"], s["start"], s["state"]) for s in subs.values()], [("スキル経由", self.now - 50, "running")])

    def test_running_without_tasks(self):
        n = self.now - 60
        self.write([assistant(n, ("a1", "Agent", {"description": "長い説明" * 10}))])
        self.subagent("x1", "a1", "長い説明" * 10, self.now)
        token = tl.progress_token(tl.summarize(self.load(), self.now))
        self.assertTrue(token.startswith("⟳1 長い説明"))
        self.assertLessEqual(tl.width(token), tl.TOKEN_WIDTH)


class IncrementalTest(Base):
    def test_reads_only_appended_lines(self):
        n = self.now - 600
        self.write(create(n, "u1", "1", "A"))
        first = self.load()["offset"]
        # 書き込み途中の行は読まない
        with open(self.path, "a") as f:
            f.write(json.dumps(task_update(n + 5, "u2", taskId="1", status="in_progress"))[:20])
        self.assertEqual(self.load()["offset"], first)
        self.write([task_update(n + 5, "u2", taskId="1", status="in_progress")], mode="w")
        # 縮んだら(書き直されたら)最初から読み直す。タスクは消える
        state = self.load()
        self.assertEqual(state["tasks"], {})
        self.write(create(n + 10, "u3", "1", "B"))
        state = self.load()
        self.assertEqual(state["tasks"]["1"]["subject"], "B")
        self.assertEqual(state["offset"], os.path.getsize(self.path))

    def test_uses_cache_between_runs(self):
        n = self.now - 600
        self.write(create(n, "u1", "1", "A"))
        self.load()
        # キャッシュに読んだ分が残っていれば、既読部分を壊しても結果は変わらない
        size = os.path.getsize(self.path)
        with open(self.path, "r+b") as f:
            f.write(b"x" * 10)
        self.assertEqual(os.path.getsize(self.path), size)
        self.assertEqual(self.load()["tasks"]["1"]["subject"], "A")

    def test_missing_transcript(self):
        self.assertIsNone(tl.update("ffffffff-0000-4000-8000-000000000000", self.now))


class ReportTest(Base):
    def test_error_is_visible_in_tab_bar(self):
        def broken():
            raise RuntimeError("boom")

        original, tl.collect_and_report = tl.collect_and_report, broken
        try:
            out = StringIO()
            with redirect_stdout(out):
                tl.report()
        finally:
            tl.collect_and_report = original
        self.assertEqual(out.getvalue(), "TL ERR\n")
        with open(os.path.join(tl.CACHE_DIR, "error.log")) as f:
            self.assertIn("RuntimeError: boom", f.read())


class FormatTest(unittest.TestCase):
    def test_truncate_by_display_width(self):
        self.assertEqual(tl.truncate("あいうえお", 6), "あい…")
        self.assertEqual(tl.truncate("abc", 3), "abc")

    def test_tab_summary(self):
        a = {"done": 1, "total": 3, "running": [{}]}
        b = {"done": 2, "total": 2, "running": []}
        self.assertEqual(tl.tab_summary([a, b]), "TASK 3/5 · SUB 1⟳")
        self.assertEqual(tl.tab_summary([{"done": 0, "total": 0, "running": []}]), "")

    def test_fit_keeps_ansi_and_clips_width(self):
        line = tl.paint("あいう", "green") + "xyz"
        self.assertEqual(tl.ANSI.sub("", tl.fit(line, 5)), "あい")


if __name__ == "__main__":
    unittest.main()
