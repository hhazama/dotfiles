return {
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

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

  -- Autosave
  {
    'okuuva/auto-save.nvim',
    cmd = 'ASToggle', -- optional for lazy loading on command
    event = { 'BufLeave', 'FocusLost' }, -- optional for lazy loading on trigger events
    opts = {
      -- claudecode の差分バッファ(buftype=acwrite)は自動保存しない:承認待ちなしに差分が確定するのを防ぐ
      condition = function(buf)
        if vim.bo[buf].buftype == 'acwrite' then
          return false
        end
        if vim.b[buf].claudecode_diff_new_win ~= nil then
          return false
        end
        return true
      end,
    },
  },

  -- カーソル下のシンボルと同じ箇所をハイライト(LSP がないバッファでも treesitter/regex で動く)
  {
    'RRethy/vim-illuminate',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      require('illuminate').configure {
        -- セマンティックな一致(LSP)を優先し、treesitter / 素のテキストにフォールバック
        providers = { 'lsp', 'treesitter', 'regex' },
        delay = 120,
        filetypes_denylist = { 'neo-tree', 'TelescopePrompt', 'alpha' },
      }
    end,
  },

  -- VSCode 風のプロジェクト全体 検索/置換パネル
  {
    'MagicDuck/grug-far.nvim',
    opts = {},
    keys = {
      {
        '<leader>sp',
        function()
          require('grug-far').open()
        end,
        desc = '[S]earch / re[P]lace (project)',
      },
      {
        '<leader>sW',
        function()
          require('grug-far').open { prefills = { search = vim.fn.expand '<cword>' } }
        end,
        desc = '[S]earch / replace [W]ord under cursor',
      },
      {
        '<leader>sf',
        function()
          require('grug-far').open { prefills = { paths = vim.fn.expand '%' } }
        end,
        desc = '[S]earch / replace in current [F]ile',
      },
    },
  },

  -- ターミナル内の `git commit` / `git rebase -i` / `nvim file` を
  -- ネストした nvim ではなくこのインスタンスのバッファとして開く
  {
    'willothy/flatten.nvim',
    lazy = false,
    priority = 1001, -- ゲスト側の検出のため他プラグインより先に初期化する必要がある
    config = function()
      vim.env.GIT_EDITOR = 'nvim'
      require('flatten').setup {
        hooks = {
          -- 編集完了(:wq)で git が再開するので、ターミナルウィンドウへフォーカスを戻す
          block_end = function()
            vim.schedule(function()
              for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'terminal' then
                  vim.api.nvim_set_current_win(win)
                  vim.cmd 'startinsert'
                  return
                end
              end
            end)
          end,
        },
      }
    end,
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
}
