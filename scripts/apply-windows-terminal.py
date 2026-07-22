#!/usr/bin/env python3
"""Windows Terminal の settings.json に dotfiles 管理の設定を反映する。

WSL 上から実行する:
    python3 scripts/apply-windows-terminal.py

config/windows-terminal/schemes/*.json を schemes に(同名は置換)、
config/windows-terminal/defaults.json を profiles.defaults / トップレベル /
プロファイル別 colorScheme にマージする。
マシン固有の値(プロファイル GUID 等)には触らない。
"""
import glob
import json
import os
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WT_CONFIG_DIR = REPO_ROOT / "config" / "windows-terminal"


def find_settings_json() -> Path:
    # cmd.exe 経由で %LOCALAPPDATA% を取るのが最も確実(ユーザー名の揺れに強い)
    try:
        out = subprocess.run(
            ["cmd.exe", "/c", "echo %LOCALAPPDATA%"],
            capture_output=True, text=True, timeout=10, cwd="/mnt/c",
        ).stdout.strip()
        if out and "%" not in out:
            win_path = out.replace("\\", "/").replace("C:", "/mnt/c")
            candidates = glob.glob(
                f"{win_path}/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"
            )
            if candidates:
                return Path(candidates[0])
    except (OSError, subprocess.SubprocessError):
        pass
    # フォールバック: /mnt/c/Users 配下を走査
    candidates = glob.glob(
        "/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"
    )
    if len(candidates) == 1:
        return Path(candidates[0])
    print(f"settings.json を特定できません: {candidates}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    settings_path = find_settings_json()
    backup = settings_path.with_suffix(f".json.bak-{date.today():%Y%m%d}")
    shutil.copy2(settings_path, backup)

    settings = json.loads(settings_path.read_text(encoding="utf-8"))
    fragment = json.loads((WT_CONFIG_DIR / "defaults.json").read_text(encoding="utf-8"))

    # schemes: 同名は dotfiles 側で置換、それ以外は保持
    managed = [
        json.loads(p.read_text(encoding="utf-8"))
        for p in sorted((WT_CONFIG_DIR / "schemes").glob("*.json"))
    ]
    managed_names = {s["name"] for s in managed}
    settings["schemes"] = [
        s for s in settings.get("schemes", []) if s.get("name") not in managed_names
    ] + managed

    settings["profiles"].setdefault("defaults", {}).update(fragment["profiles_defaults"])
    settings.update(fragment["top_level"])
    for profile in settings["profiles"]["list"]:
        scheme = fragment["color_scheme_by_profile"].get(profile.get("name"))
        if scheme:
            profile["colorScheme"] = scheme

    settings_path.write_text(
        json.dumps(settings, ensure_ascii=False, indent=4) + "\n", encoding="utf-8"
    )
    print(f"applied: {settings_path}")
    print(f"backup:  {backup}")
    print(f"schemes: {[s['name'] for s in settings['schemes']]}")


if __name__ == "__main__":
    main()
