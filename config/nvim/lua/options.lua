-- leader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- encoding
vim.opt.encoding = 'utf-8'

-- font
vim.g.have_nerd_font = true

-- インデントの設定
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- 行番号
vim.opt.number = true
-- vim.opt.relativenumber = true

-- 行や列のハイライト
vim.opt.cursorline = true
vim.opt.cursorcolumn = true

-- マウスモード
vim.opt.mouse = 'a'

-- モードはステータスラインに表示するので非表示
vim.opt.showmode = false

-- クリップボード
vim.opt.clipboard = 'unnamedplus'

vim.filetype.add {
  extension = {
    sqltmpl = 'sql',
  },
}

-- Save undo history
vim.opt.undofile = true

-- 検索時の大文字小文字の無視
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- TrueColorの設定
vim.opt.termguicolors = true

-- floating windowの設定
vim.opt.pumblend = 10
vim.opt.winblend = 10

-- signcolumn表示
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- 長い行を折り返す
vim.opt.wrap = true

-- 入力中のコマンドを表示
vim.opt.showcmd = true

-- swapfileの設定
vim.opt.swapfile = true -- スワップファイルを有効（デフォルト）

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.opt.incsearch = true
