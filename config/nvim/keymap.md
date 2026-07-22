# Neovim キーバインド一覧

リーダーキー = **スペース**。スペースを押して少し待つと候補一覧がポップアップする(which-key)。`:Telescope keymaps`(`Space sk`)でインクリメンタル検索も可能。

## 基本

| キー | 動作 |
|---|---|
| `jj` (挿入モード) | Esc(ノーマルモードへ戻る) |
| `Esc` (ノーマル) | 検索ハイライト消去 |
| `Ctrl+W` → `t` | 新しいタブを作成 |
| `Space S` | ファイルを SJIS で開き直す |
| (自動) | フォーカスが外れたとき等に自動保存(auto-save.nvim) |

## カーソル移動・ジャンプ (hop)

| キー | 動作 |
|---|---|
| `s` / `S` | 入力した1文字 / 2文字へジャンプ |
| `f` | 単語へジャンプ |
| `F` | 行へジャンプ |

## ファイルツリー (neo-tree)

| キー | 動作 |
|---|---|
| `Ctrl+E` | ツリーを開いて現在ファイルを表示(ツリー内では閉じる) |

ツリー内: `a` 新規作成 / `r` リネーム / `d` 削除 / `m` 移動 / `?` ヘルプ(全キー一覧)

## 検索 (telescope)

| キー | 動作 |
|---|---|
| `Ctrl+P` | ファイル名検索 |
| `Ctrl+S` | 全文検索(スコープ付き live_grep、下記参照) |
| `Space sw` | カーソル下の単語で全文検索 |
| `Space /` | 現在バッファ内をファジー検索 |
| `Space s/` | 開いているファイルだけ全文検索 |
| `Space sd` | 診断一覧 |
| `Space sr` | 直前の検索を再開(resume) |
| `Space s.` | 最近開いたファイル |
| `Space sh` / `Space sk` | ヘルプ検索 / キーマップ検索 |
| `Space ss` | Telescope の機能一覧 |
| `Space sn` | Neovim 設定ファイルを検索 |
| `Space Space` | 開いているバッファ一覧 |

`Ctrl+S` の全文検索中(スコープ付き live_grep):

| キー | 動作 |
|---|---|
| `Ctrl+O` | 検索対象ディレクトリをファジー選択(`.` で全体にリセット) |
| `Ctrl+E` | 除外する拡張子/グロブを指定(例: `js, json` や `*.test.ts`、空で解除) |

スコープはセッション内で永続し、picker タイトルに表示される。入力途中のクエリも引き継がれる。

## 検索/置換 (grug-far)

| キー | 動作 |
|---|---|
| `Space sp` | プロジェクト全体の検索/置換パネル |
| `Space sW` | カーソル下の単語をプリセットして開く |
| `Space sf` | 現在ファイル内だけで検索/置換 |

## ファイルタブ (bufferline)

| キー | 動作 |
|---|---|
| `Shift+L` / `Shift+H` | 次 / 前のバッファ |
| `Space bch` / `Space bcl` | 左側 / 右側のバッファを閉じる |
| `Space bco` | 他のバッファを全部閉じる |

## LSP (コードジャンプ・リファクタ)

| キー | 動作 |
|---|---|
| `gd` / `gD` | 定義 / 宣言へジャンプ |
| `gr` | 参照一覧 |
| `gI` | 実装へジャンプ |
| `Ctrl+O` / `Ctrl+I` | ジャンプ元へ戻る / 進む |
| `K` | ホバー(型・ドキュメント) |
| `Space D` | 型定義へジャンプ |
| `Space ds` / `Space ws` | ドキュメント / ワークスペースのシンボル検索 |
| `Space rn` | シンボルのリネーム |
| `Space ca` | コードアクション |
| `Space f` | フォーマット(conform.nvim) |
| `Space th` | インレイヒントの表示切替 |
| `[d` / `]d` | 前 / 次の診断へ |
| `Space e` | 診断をフロート表示 |
| `Space q` | 診断を quickfix へ |
| (自動) | カーソル下のシンボルと同じ箇所をハイライト(illuminate、LSP がないバッファでも有効) |

## Git (gitsigns / gitlinker / diffview)

| キー | 動作 |
|---|---|
| `]c` / `[c` | 次 / 前の変更 hunk へ(ステータスラインに `± i/n` で現在位置を常時表示) |
| `Space gh` | hunk 操作モード(hydra)。モード中は `j`/`k`: 移動、`s`: stage、`u`: stage 取消、`r`: reset、`p`: preview、`Esc`: 終了 |
| `Space gy` | 現在行の GitLab パーマリンクをコピー |
| `Space gd` | dev ブランチとの差分を diffview で開く(MR 相当) |
| `Space gr` | 任意 ref との差分(プロンプトで入力) |
| `Space gf` | 現在ファイルの履歴 |
| `Space gq` | diffview を閉じる |
| (自動) | 行末に blame をインライン表示 |

## マージコンフリクト解決 (git-conflict)

コンフリクトを含むファイルを開くと自動で有効化(`<<<`〜`>>>` を手編集せず1キーで解決):

| キー | 動作 |
|---|---|
| `co` | 自分の変更を採用 (Accept Current) |
| `ct` | 相手の変更を採用 (Accept Incoming) |
| `cb` | 両方採用 (Accept Both) |
| `c0` | どちらも破棄 |
| `]x` / `[x` | 次 / 前のコンフリクトへ |
| `Space gx` | 全コンフリクトを quickfix 一覧へ |

検出時は LSP 診断を自動ミュートし、解決キーを通知する。

## ターミナル

| キー | 動作 |
|---|---|
| `Space ts` / `Space tv` | 水平 / 垂直分割でターミナルを開く |
| (自動) | ターミナル内の `git commit` / `git rebase -i` / `nvim file` は親 nvim のバッファとして開く(flatten.nvim)。`:wq` で閉じるとターミナルへフォーカスが戻る |

## AI (Claude Code / CodeCompanion)

| キー | 動作 |
|---|---|
| `Space ac` | Claude Code 起動/切替 |
| `Space af` | Claude にフォーカス |
| `Space ar` / `Space aC` | セッション再開 / 直近を継続 |
| `Space am` | モデル選択 |
| `Space ab` | 現在バッファを Claude に追加 |
| `Space as` (選択中) | 選択範囲を Claude に送信(ツリー内ではファイル追加) |
| `Space aa` / `Space ad` | Claude の差分を承認 / 却下 |
| `Space ai` | CodeCompanion チャット |
| `Space ap` | CodeCompanion アクション |
| `Space ae` | CodeCompanion インライン編集 |

## ウィンドウ操作

| キー | 動作 |
|---|---|
| `Ctrl+H/J/K/L` (ノーマル) | 左/下/上/右のウィンドウへ移動 |
| `Ctrl+H/J/K/L` (挿入モード) | カーソル移動(左/下/上/右) |

## テキスト編集 (mini.nvim / Comment.nvim)

| キー | 動作 |
|---|---|
| `gc` | コメントアウト切替(選択範囲・行) |
| `saiw)` 等 | 囲み文字の追加(mini.surround) |
| `sd'` / `sr)'` | 囲み文字の削除 / 置換 |
| `va)` / `ci'` 等 | 拡張テキストオブジェクト(mini.ai) |

## 標準キーを上書きしている箇所(注意)

| キー | 本来の動作 | 現在の動作 |
|---|---|---|
| `s` / `S` | 1文字置換 / 行置換 | hop ジャンプ(代替: `cl` / `cc`) |
| `f` / `F` | 行内の文字検索 | hop ジャンプ |
| `Shift+H` / `Shift+L` | 画面の最上/最下行へ | バッファ切替(代替: `gg` / `G`) |
| `Ctrl+S` | (端末の画面停止) | 全文検索 |
| `Ctrl+E` | 1行下スクロール | ファイルツリー開閉 |
| `Ctrl+P` | 前のコマンド履歴等 | ファイル名検索 |
