# tmux エージェント状態サイドバー 設計

- 日付: 2026-07-15
- 目的: herdr の「エージェント状態サイドバー」相当を tmux 上に実現する。各 Claude Code セッションの状態(⏳要対応 / ▶作業中 / ✓待機)を細い縦ペインに一覧表示し、トグルで出し入れできる。

## 決定事項

- 表示形態: 常設サイドペイン(A案)＋トグル。ペインは tmux の性質上ウィンドウ単位で、`prefix+b` で出し入れ。`after-new-window`/`after-new-session` フックで全ウィンドウに自動表示(herdr のデフォルト表示相当)。
- 中身の作り方: flock スロットルの共有 state file(案1)を、サイドバーペイン内の fzf が読んで常時表示。fzf 上で j/k/Enter またはクリックで選択セッションの pane へジャンプ(インタラクティブ)。kill 等の重操作は既存 `prefix+a` popup に委ねる。
- データ源: `claude agents --json`(既存 `claude-sessions` と同じ)。状態マップ waiting/needs_input→⏳、busy/running→▶、idle→✓。

## コンポーネント

| 名前 | 種別 | 責務 |
|---|---|---|
| `claude-agents-lib.sh` | 新規(共有lib) | `claude agents --json` の正規化・状態マップ・age/branch・pane 突合を集約。状態マップの唯一の定義箇所 |
| `agents_refresh_state`(lib内) | 新規 | レンダラ内から flock 付きで呼ばれ、state が maxage(2秒)より古い時だけ再生成。別プロセスの常駐ポーラは持たず孤児化を避ける |
| `claude-agents-sidebar` | 新規 | ペイン内で fzf を起動し状態一覧を常時表示。`--feed`(state 更新+整形)を2秒毎に自動 reload、Enter/クリックで `--jump`(選択 pane へ移動)。fzf 非アクティブ window では再描画されない点は実使用上問題なし |
| `claude-sidebar-toggle` | 新規 | `prefix+b`。当該windowにサイドバーがあれば kill、無ければ左に固定幅で分割し fzf 起動＋フォーカス復帰。`ensure` モードは「無ければ開くだけ」でフック自動表示に使う |
| `claude-sessions` | 変更 | emit_rows を lib 利用へ置換(状態マップ二重管理の解消)。外部挙動(--list/--rows)は不変 |
| `config/tmux/tmux.conf` | 変更 | `bind b run-shell claude-sidebar-toggle` |

## データフロー

1. `prefix+b` → toggle。サイドバー在→kill、無→左に `split-window -h -b -l 32`、`@agent_sidebar=1` を付与、レンダラ起動、フォーカスを元ペインへ。
2. レンダラが毎tick `agents_refresh_state` を呼ぶ。flock 保持者だけが state を再生成(2秒スロットル)し、`claude agents --json` の実行はペイン数に依らず約2秒に1回に収まる。
3. レンダラ(1s): state file を読み `icon label age` を描画。

## state file

- 置き場: `${XDG_RUNTIME_DIR:-/tmp}/claude-agents/state`
- 中身: lib の生 TSV(`icon label cwdbase branch age loc target cwd sid pid`)。書込は temp→mv でアトミック。空=セッションなし。

## エラー処理

- `claude agents --json` 空/失敗→空リスト表示。state 未生成→loading…。claude/jq 不在→レンダラが1行エラー、ポーラ即終了。tmux 到達不可→ポーラ終了。手動 kill→ポーラ自壊し再トグルで復帰。

## テスト

- 純関数: フィクスチャ json＋固定 now で `agents_transform` の TSV を厳密比較(状態マップ/age/並び順)、`agents_trunc`/`session_label` の分岐。tmux/claude 非依存。
- 連携: 別ソケット(`tmux -L`)でトグルの分割→目印→kill→フォーカス復帰、ポーラ単一起動を確認。
- 回帰: `claude-sessions --rows` が5フィールド構造を保つこと。
