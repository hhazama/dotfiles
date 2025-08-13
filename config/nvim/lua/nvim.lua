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

-- TrueColorの設定
vim.opt.termguicolors = true

-- floating windowの設定
vim.opt.pumblend = 10
vim.opt.winblend = 10

-- swapfileの設定
vim.opt.swapfile = false

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- jjでノーマルモードに戻る
vim.keymap.set('i', 'jj', '<Esc>')

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Keybinds to move in insert mode
vim.keymap.set('i', '<C-h>', '<Left>', { desc = 'Move cursor left' })
vim.keymap.set('i', '<C-l>', '<Right>', { desc = 'Move cursor right' })
vim.keymap.set('i', '<C-j>', '<Down>', { desc = 'Move cursor down' })
vim.keymap.set('i', '<C-k>', '<Up>', { desc = 'Move cursor up' })

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

-- vim loader
vim.loader.enable()

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- alpha.nvim
  {
    'goolord/alpha-nvim',
    dependencies = {
      'kyazdani42/nvim-web-devicons',
    },
    config = function()
      local dashboard = require 'alpha.themes.dashboard'

      -- header
      dashboard.section.header.val = {
        '                                                     ',
        '  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ',
        '  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ',
        '  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ',
        '  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ',
        '  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ',
        '  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ',
        '                                                     ',
      }

      dashboard.section.header.val = {
        '⠀⠀⠀⠀⠀⠀⠀⣀⣤⠶⠖⠒⠲⣤⡀⠀⠀⠀⠀⠀⠀⠀⣠⠴⠖⠒⠶⢤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⣠⡤⠖⠋⠉⠀⠀⢀⡀⠀⠀⢻⣄⠀⠀⠀⠀⢀⣼⠁⠀⢀⡀⠀⠀⠀⠉⠙⠒⢦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠤⠤⠤⢤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⢠⣾⠃⠀⢀⣠⣤⣶⣿⣿⣿⣧⠀⠀⠛⠋⠉⠉⠛⡾⠇⠀⢠⣿⣿⣿⣷⣶⣤⣄⡀⠀⢻⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡾⠏⠀⣀⣀⡀⠈⠹⡆⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⣼⡟⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⢠⡧⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣀⣀⣀⣀⠀⠀⣾⡃⢀⣴⣿⣿⣿⡄⠀⣷⠀⠀⠀⠀⠀⠀⠀⠀',
        '⢠⡏⢧⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⣼⣃⣀⣠⣀⣀⠀⠀⠀⣶⠏⠁⠀⠀⠈⠉⠉⠉⠻⠷⠀⠘⣿⣿⣿⠉⠁⢠⣿⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⢻⡜⣧⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠉⠉⠀⠀⠈⠈⢿⣄⣸⡉⠀⢠⣶⣶⣶⣦⣤⣄⠀⠀⠀⡀⣸⣿⣿⣧⠀⠈⠙⠛⠓⠶⠦⢤⣀⠀⠀',
        '⠀⠀⢷⡘⣆⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⣀⣠⣤⣤⣶⣶⡆⠀⠀⣿⣿⠀⠀⢸⣿⣿⣿⣿⣿⣿⣧⠀⠀⢿⣿⣿⡿⠃⠀⣀⣄⣀⣀⠀⠀⠀⠈⢷⡄',
        '⠀⠀⠈⢷⡘⣦⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⣿⣿⣿⣿⣿⣿⣷⠀⠀⢺⡟⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠉⠉⠁⣠⣾⣿⣿⣿⣿⣿⣿⠆⠀⠀⣷',
        '⠀⠀⠀⠘⢧⣘⣧⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣧⠀⣾⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⡄⠀⠈⠁⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⣸⠇',
        '⠀⠀⠀⠀⠈⣷⠺⣇⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⡿⠀',
        '⠀⠀⠀⠀⠀⠈⢷⡸⣆⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣷⠀⠀⠀⠀⣸⣿⣿⣿⣿⣿⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⢸⠇⠀',
        '⠀⠀⠀⠀⠀⠀⠘⣷⠹⣆⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⣿⣿⣿⣿⣿⣿⠀⢻⣿⣿⣿⣿⣿⣿⡿⢡⣿⣿⣿⣿⣿⡟⠀⢀⡿⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠘⣇⠹⣆⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⡇⠀⠀⢠⣿⣿⣿⣿⣿⣿⡆⠈⣿⣿⣿⣿⣿⠏⠀⣾⣿⣿⣿⣿⣿⠇⠀⢰⠇⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠘⣧⠽⣆⠀⠈⢿⣿⣿⣿⣿⣿⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣷⠀⠀⢸⣿⣿⣿⣿⣿⡟⠃⠀⠈⠉⠙⠛⠁⠀⣸⣿⣿⣿⣿⣿⡟⠀⠀⣾⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣏⢹⡆⠀⠈⠛⠛⠛⠛⠛⠛⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⡀⠀⠘⠿⣿⢿⡿⠿⠇⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⠃⠀⢀⡟⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣧⡇⠀⣴⡄⣀⢀⡀⣴⣶⣦⠀⠀⠀⠀⠀⢀⣶⣶⣤⡀⠀⢸⣿⣿⣿⣿⣿⣿⡇⠀⣴⣶⣿⣿⣷⢀⣀⣀⠀⠀⠀⠀⠀⠀⠘⠿⢿⣿⣿⣿⡟⠀⠀⣸⠃⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⡇⠀⠿⠏⢿⣿⡏⠙⢻⡇⠀⠀⠀⠀⣰⣾⣿⣿⣿⣧⣤⣬⠛⠛⠛⠋⠉⠉⠀⠀⣩⣿⣿⣿⠏⢸⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠁⠀⢠⡟⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠿⠦⣄⣀⠀⠀⢀⣀⣀⣀⣀⡀⠀⠀⠛⠛⠻⣿⣿⣏⠉⠋⠀⣤⣦⠀⠀⣶⣾⡄⣿⣿⣿⣿⣆⣈⣿⡉⠁⠀⠀⠀⢠⣿⠇⠀⢀⣤⠤⠤⠤⢴⣿⠁⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢦⣄⠀⠈⠉⠩⢉⠡⡭⠟⡁⢿⣓⣶⠀⠀⣠⣿⣿⡏⠀⠀⠀⢻⣿⣶⡄⠸⠟⠃⠀⠉⠙⠿⣿⣿⠿⠛⠀⣴⡆⢀⣿⡟⠀⣰⢏⣿⣀⣀⣤⠾⠃⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠓⠒⠚⠋⠛⠒⢛⡿⠋⠁⠀⠀⠈⠻⡿⠋⠀⠀⠀⠀⣀⣻⣿⣃⣀⣀⣀⣤⣀⠀⠀⠀⠀⠀⠀⣰⣿⠁⣾⡿⠀⢠⡿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⡇⠀⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⢰⣿⠇⠀⣀⣀⣠⣾⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡇⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⠀⠈⠁⠀⣼⠫⢉⣰⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡇⠀⠸⠿⠿⠿⠿⠿⠛⠛⠛⠛⠛⠛⠛⠛⠛⠋⠉⠉⠉⠉⠀⣠⠞⠉⠉⠛⠚⢛⡿⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⠻⢤⣄⣀⣀⣀⣀⣤⠤⠀⠀⠤⠤⠤⠶⠶⠶⠂⠐⠒⠒⠚⠋⣵⠟⠛⠓⠶⠒⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣦⣀⠀⢀⣀⠀⣀⣀⣀⣀⣀⣀⣤⣤⣤⣠⣤⣤⠤⠴⠶⠶⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
        '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
      }

      -- Set menu
      dashboard.section.buttons.val = {
        dashboard.button('t', '  Neotree', ':Neotree toggle<Return>'),
        dashboard.button('n', '  New file', ':ene <BAR> startinsert <CR>'),
        dashboard.button('r', '  Recent file', ':Telescope oldfiles <CR>'),
        dashboard.button('f', '󰥨  Find file', ':Telescope find_files <CR>'),
        dashboard.button('g', '󰱼  Find text', ':Telescope live_grep <CR>'),
        dashboard.button('s', '  Settings', ':e $MYVIMRC | :cd %:p:h | split . | wincmd k | pwd<CR>'),
        dashboard.button('q', '  Quit', ':qa<CR>'),
      }

      -- Set footer
      local function footer()
        local total_plugins = #require('lazy').plugins()
        local datetime = os.date ' %Y-%m-%d   %H:%M:%S'
        local version = vim.version()
        local version_info = '   v' .. version.major .. '.' .. version.minor .. '.' .. version.patch
        return datetime .. '  ⚡' .. total_plugins .. ' plugins' .. version_info
      end
      dashboard.section.footer.val = footer()

      -- Send config to alpha
      require('alpha').setup(dashboard.opts)

      -- Disable folding on alpha buffer
      vim.cmd [[autocmd FileType alpha setlocal nofoldenable]]
    end,
  },

  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

  -- colorizer
  {
    'norcalli/nvim-colorizer.lua',
    config = function()
      require('colorizer').setup()
    end,
  },

  -- Adds git related signs to the gutter, as well as utilities for managing changes
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  -- Useful plugin to show you pending keybinds.
  {
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      require('which-key').setup()

      -- Document existing key chains
      require('which-key').register {
        ['<leader>c'] = { name = '[C]ode', _ = 'which_key_ignore' },
        ['<leader>d'] = { name = '[D]ocument', _ = 'which_key_ignore' },
        ['<leader>r'] = { name = '[R]ename', _ = 'which_key_ignore' },
        ['<leader>s'] = { name = '[S]earch', _ = 'which_key_ignore' },
        ['<leader>w'] = { name = '[W]orkspace', _ = 'which_key_ignore' },
        ['<leader>t'] = { name = '[T]oggle', _ = 'which_key_ignore' },
        ['<leader>h'] = { name = 'Git [H]unk', _ = 'which_key_ignore' },
        ['<leader>b'] = { name = '[B]uffer', _ = 'which_key_ignore' },
      }
      -- visual mode
      require('which-key').register({
        ['<leader>h'] = { 'Git [H]unk' },
      }, { mode = 'v' })
    end,
  },

  -- Fuzzy Finder (files, lsp, etc)
  {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',

        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- [[ Configure Telescope ]]
      require('telescope').setup {
        pickers = {
          find_command = '/home/hatano/.local/share/zinit/plugins/BurntSushi---ripgrep/ripgrep-14.1.0-x86_64-unknown-linux-musl/rg',
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Configuration & Plugins
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- `neodev` configures Lua LSP for your Neovim config, runtime and plugins
      -- used for completion, annotations and signatures of Neovim apis
      { 'folke/neodev.nvim', opts = {} },
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- Find references for the word under your cursor.
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

          -- Opens a popup that displays documentation about the word under your cursor
          --  See `:help K` for why this keymap.
          map('K', vim.lsp.buf.hover, 'Hover Documentation')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.server_capabilities.documentHighlightProvider then
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              callback = vim.lsp.buf.clear_references,
            })
          end

          -- The following autocommand is used to enable inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(0, not vim.lsp.inlay_hint.is_enabled())
            end, '[T]oggle Inlay [H]ints')
          end

          vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
            update_in_insert = true,
            virtual_text = {
              spacing = 5,
              severity_limit = 'Warning',
            },
            underline = true,
          })
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`tsserver`) will work just fine
        -- tsserver = {},
        --

        lua_ls = {
          -- cmd = {...},
          -- filetypes = { ...},
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              workspace = {
                checkThirdParty = false,
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --  To check the current status of installed tools and/or manually install
      --  other tools, you can run
      --    :Mason
      --
      --  You can press `g?` for help in this menu.
      require('mason').setup()

      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
        'biome', -- Used to format JavaScript and TypeScript code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for tsserver)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  -- typescript-tools
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {},
  },

  -- Autoformat
  {
    'stevearc/conform.nvim',
    lazy = false,
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_fallback = true }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        return {
          timeout_ms = 500,
          lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
        }
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use a sub-list to tell conform to run *until* a formatter
        -- is found.
        javascript = { { 'biome', 'prettierd', 'prettier' } },
        typescript = { { 'biome', 'prettierd', 'prettier' } },
        typescriptreact = { { 'biome', 'prettierd', 'prettier' } },
        javascriptreact = { { 'biome', 'prettierd', 'prettier' } },
      },
    },
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in man6y windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
      },
      'saadparwaiz1/cmp_luasnip',

      -- Adds other completion capabilities.
      --  nvim-cmp does not ship with all sources by default. They are split
      --  into multiple repos for maintenance purposes.
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
    },
    config = function()
      -- See `:help cmp`
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'
      luasnip.config.setup {}

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = 'menu,menuone,noinsert' },

        -- For an understanding of why these mappings were
        -- chosen, you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        mapping = cmp.mapping.preset.insert {
          -- Select the [n]ext item
          ['<C-n>'] = cmp.mapping.select_next_item(),
          -- Select the [p]revious item
          ['<C-p>'] = cmp.mapping.select_prev_item(),

          -- Scroll the documentation window [b]ack / [f]orward
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),

          -- Accept ([y]es) the completion.
          --  This will auto-import if your LSP supports it.
          --  This will expand snippets if the LSP sent a snippet.
          ['<CR>'] = cmp.mapping.confirm { select = true },

          -- Manually trigger a completion from nvim-cmp.
          --  Generally you don't need this, because nvim-cmp will display
          --  completions whenever it has completion options available.
          ['<C-Space>'] = cmp.mapping.complete {},

          -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
          --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
        },
      }
    end,
  },

  -- colorscheme
  {
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      vim.cmd.colorscheme 'tokyonight-night'
      vim.cmd.hi 'Comment gui=none'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  -- Collection of various small independent plugins/modules
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },

  -- Highlight, edit, and navigate code
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    opts = {
      ensure_installed = { 'bash', 'c', 'html', 'lua', 'luadoc', 'markdown', 'vim', 'vimdoc' },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    config = function(_, opts)
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

      -- Prefer git instead of curl in order to improve connectivity in some environments
      require('nvim-treesitter.install').prefer_git = true
      require('nvim-treesitter.configs').setup(opts)

      -- There are additional nvim-treesitter modules that you can use to interact
      -- with nvim-treesitter. You should go explore a few and see what interests you:
      --
      --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
      --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
      --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
    end,
  },

  -- Add indentation guides even on blank lines
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {},
  },

  -- Autopair
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    -- Optional dependency
    dependencies = { 'hrsh7th/nvim-cmp' },
    config = function()
      require('nvim-autopairs').setup {}
    end,
  },

  {
    'windwp/nvim-ts-autotag',
    event = 'InsertEnter',
    config = function()
      require('nvim-ts-autotag').setup()
    end,
  },
  -- explorer
  {
    'nvim-neo-tree/neo-tree.nvim',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
    keys = {
      { '\\', ':Neotree reveal<CR>', { desc = 'NeoTree reveal' } },
    },
    opts = {
      window = {
        position = 'left',
      },
      filesystem = {
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = {
            'node_modules',
            '.git',
          },
        },
        window = {
          mappings = {
            ['\\'] = 'close_window',
            ['m'] = {
              'move',
              config = {
                show_path = 'relative',
              },
            },
          },
        },
      },
    },
  },

  {
    'antosha417/nvim-lsp-file-operations',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-neo-tree/neo-tree.nvim',
    },
    config = function()
      require('lsp-file-operations').setup()
    end,
  },

  -- bufferline
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
  },

  -- lualine
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },

  -- GitHub Copilot
  {
    'github/copilot.vim',
    lazy = false,
  },

  -- Autosave
  {
    'okuuva/auto-save.nvim',
    cmd = 'ASToggle', -- optional for lazy loading on command
    event = { 'BufLeave', 'FocusLost' }, -- optional for lazy loading on trigger events
    opts = {},
  },

  -- Scrollbar
  {
    'dstein64/nvim-scrollview',
    event = 'BufRead',
    config = function()
      require('scrollview').setup()
    end,
  },
  -- notice
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    config = function()
      require('noice').setup {
        lsp = {
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
            ['vim.lsp.util.stylize_markdown'] = true,
            ['cmp.entry.get_documentation'] = true, -- requires hrsh7th/nvim-cmp
          },
        },
        -- you can enable a preset for easier configuration
        presets = {
          bottom_search = true, -- use a classic bottom cmdline for search
          command_palette = true, -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be nt to a split
          inc_rename = false, -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false, -- add a border to hover docs and signature help
        },
      }
    end,
    opts = {
      -- add any options here
    },
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      'MunifTanjim/nui.nvim',
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      'rcarriga/nvim-notify',
    },
  },

  -- Hop
  {
    'phaazon/hop.nvim',
    branch = 'v2',
    event = 'BufRead',
    config = function()
      require('hop').setup { keys = 'etovxqpdygfblzhckisuran' }

      -- Keybinds
      vim.keymap.set('n', 's', '<cmd>HopChar1<CR>', { desc = 'Hop to 1st character' })
      vim.keymap.set('n', 'S', '<cmd>HopChar2<CR>', { desc = 'Hop to 2nd character' })
      vim.keymap.set('n', 'f', '<cmd>HopWord<CR>', { desc = 'Hop to word' })
      vim.keymap.set('n', 'F', '<cmd>HopLine<CR>', { desc = 'Hop to line' })
    end,
  },

  -- Code Lens
  {
    'Wansmer/symbol-usage.nvim',
    event = 'BufReadPre', -- need run before LspAttach if you use nvim 0.9. On 0.10 use 'LspAttach'
    config = function()
      require('symbol-usage').setup {
        vt_position = 'end_of_line',
      }
    end,
  },
}

require('bufferline').setup()
vim.keymap.set('n', '<leader>bch', '<CMD>BufferLineCloseLeft<CR>', { desc = '[B]uffer [C]lose left' })
vim.keymap.set('n', '<leader>bcl', '<CMD>BufferLineCloseRight<CR>', { desc = '[B]uffer [C]lose right' })
vim.keymap.set('n', '<leader>bco', '<CMD>BufferLineCloseOthers<CR>', { desc = '[B]uffer [C]lose [O]thers' })
vim.keymap.set('n', '<S-l>', '<CMD>BufferLineCycleNext<CR>', { desc = 'Go to next Buffer' })
vim.keymap.set('n', '<S-h>', '<CMD>BufferLineCyclePrev<CR>', { desc = 'Go to prev Buffer' })
require('lualine').setup {}
