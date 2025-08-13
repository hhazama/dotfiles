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

-- 検索時の大文字小文字の無視
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- クリップボード
vim.opt.clipboard = 'unnamedplus'

-- Save undo history
vim.opt.undofile = true

-- 検索時の大文字小文字の無視
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- TrueColorの設定
vim.opt.termguicolors = true

-- swapfileの設定
vim.opt.swapfile = false

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- jjでノーマルモードに戻る
vim.keymap.set('i', 'jj', '<Esc>')

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- WSL clipboard
if vim.fn.has 'wsl' == 1 then
  if vim.fn.executable 'wl-copy' == 0 then
    print "wl-clipboard not found, clipboard integration won't work"
  else
    vim.g.clipboard = {
      name = 'wl-clipboard (wsl)',
      copy = {
        ['+'] = 'wl-copy --foreground --type text/plain',
        ['*'] = 'wl-copy --foreground --primary --type text/plain',
      },
      paste = {
        ['+'] = function()
          return vim.fn.systemlist('wl-paste --no-newline|sed -e "s/\r$//"', { '' }, 1) -- '1' keeps empty lines
        end,
        ['*'] = function()
          return vim.fn.systemlist('wl-paste --primary --no-newline|sed -e "s/\r$//"', { '' }, 1)
        end,
      },
      cache_enabled = true,
    }
  end
end