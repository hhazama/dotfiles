# Windows AutoHotkey スクリプト

キーボードだけでアプリのフォーカスと仮想デスクトップ移動を完結させるための AutoHotkey v2 スクリプト一式。マルチモニタ + 仮想デスクトップで「どのアプリがどこにいったか」を探さずに済ませることが目的。

## 前提

- AutoHotkey v2（Microsoft Store 版、ランチャー `AutoHotkey.exe`）がインストール済みであること。

## ファイル

| ファイル | 役割 |
| --- | --- |
| `app-switch.ahk` | アプリを固定キーで呼び出す（新規） |
| `moveVirtualDesktop.ahk` | 仮想デスクトップの移動・ウィンドウ移動（既存を取り込み） |
| `VirtualDesktopAccessor.dll` | 両スクリプトが使う仮想デスクトップ操作ライブラリ |
| `deploy.ps1` | Windows へ配置し自動起動を設定する |

## キー割り当て

### app-switch.ahk

| キー | 動作 |
| --- | --- |
| `Alt+1` | Terminal（Windows Terminal） |
| `Alt+2` | Slack |
| `Alt+3` | Chrome |
| `Alt+4` | Obsidian |
| `Alt+0` | 上記4アプリを並び順で順送り巡回 |

- 押すと最前面化。対象が別の仮想デスクトップやモニタに在っても、そのデスクトップへ移動した上で前面に出す（`VirtualDesktopAccessor.dll` を利用）。
- すでにそのアプリが最前面なら、連打で同じアプリの別ウィンドウへ巡回する。巡回対象は現在表示中のデスクトップ上のウィンドウ（Chrome や Terminal を複数開いていても回せる）。
- 未起動なら起動する。

### moveVirtualDesktop.ahk

| キー | 動作 |
| --- | --- |
| `Win+1..4` | 仮想デスクトップ 1〜4 へ移動 |
| `Win+Shift+1..4` | アクティブウィンドウを仮想デスクトップ 1〜4 へ移動 |
| `Win+Ctrl+Shift+←/→` | アクティブウィンドウを隣のデスクトップへ移動し、自分もついていく |

## 導入・更新

Windows PowerShell から `deploy.ps1` を実行する。編集したときも同じコマンドで再反映する。

```powershell
powershell -ExecutionPolicy Bypass -File "\\wsl.localhost\Ubuntu\data\repos\hhazama\dotfiles\windows\autohotkey\deploy.ps1"
```

`deploy.ps1` の動作:

1. スクリプトと DLL を `%LOCALAPPDATA%\autohotkey-scripts\` へコピー
2. スタートアップ（`shell:startup`）に各スクリプトのショートカットを作成 → 次回ログインから自動起動
3. 該当スクリプトを一度終了して、その場で起動し直す（再ログイン不要）

初回導入後、旧 `Documents\PowerToys\moveVirtualDesktop.ahk` は手動起動をやめれば削除してよい（正本はこのリポジトリ）。

## 設定

`app-switch.ahk` 冒頭:

- `WARP_MOUSE`：`true` にするとフォーカス先ウィンドウの中央へマウスカーソルを移動する（既定 `false`）。
- `APPS`：並び順・ウィンドウ判定用 `exe`・未起動時の `launch` パス。アプリの入れ替えやパス変更はここを直す。

## 補足

- `app-switch.ahk` は、Windows のフォアグラウンド固定でフォーカスを奪えないことがあるため、最小化→復元のフォールバックを入れている。
- `moveVirtualDesktop.ahk` は動作実績のある既存スクリプトの本文をそのまま取り込み、先頭に `#Requires AutoHotkey v2.0`（起動時に出る v1/v2 選択ポップアップを止めるため）と `#SingleInstance Force` を追加している。
- `VirtualDesktopAccessor.dll` は Windows のビルドに依存するバイナリ。Windows の大型更新後に仮想デスクトップ移動が効かなくなったら、DLL の更新版への差し替えが要る場合がある。

## アンインストール

1. `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\` の `app-switch.lnk` / `moveVirtualDesktop.lnk` を削除
2. タスクトレイの AutoHotkey アイコンから該当スクリプトを終了
3. 不要なら `%LOCALAPPDATA%\autohotkey-scripts\` を削除
