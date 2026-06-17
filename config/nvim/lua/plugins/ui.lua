return {
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

  -- colorizer
  {
    'norcalli/nvim-colorizer.lua',
    config = function()
      require('colorizer').setup()
    end,
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
        ['<leader>g'] = { name = '[G]it / Diffview', _ = 'which_key_ignore' },
        ['<leader>b'] = { name = '[B]uffer', _ = 'which_key_ignore' },
      }
      -- visual mode
      require('which-key').register({
        ['<leader>h'] = { 'Git [H]unk' },
      }, { mode = 'v' })
    end,
  },

  -- colorscheme
  {
    'loctvl842/monokai-pro.nvim',
    priority = 1000,
    config = function()
      require('monokai-pro').setup {
        filter = 'pro', -- classic, octagon, pro, machine, ristretto, spectrum
      }
      vim.cmd.colorscheme 'monokai-pro'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  -- Add indentation guides even on blank lines
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {},
  },

  -- bufferline
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup()

      vim.keymap.set('n', '<leader>bch', '<CMD>BufferLineCloseLeft<CR>', { desc = '[B]uffer [C]lose left' })
      vim.keymap.set('n', '<leader>bcl', '<CMD>BufferLineCloseRight<CR>', { desc = '[B]uffer [C]lose right' })
      vim.keymap.set('n', '<leader>bco', '<CMD>BufferLineCloseOthers<CR>', { desc = '[B]uffer [C]lose [O]thers' })
      vim.keymap.set('n', '<S-l>', '<CMD>BufferLineCycleNext<CR>', { desc = 'Go to next Buffer' })
      vim.keymap.set('n', '<S-h>', '<CMD>BufferLineCyclePrev<CR>', { desc = 'Go to prev Buffer' })
    end,
  },

  -- lualine
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup {}
    end,
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
          progress = {
            enabled = false, -- プログレス表示を無効
          },
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
          lsp_doc_border = true, -- add a border to hover docs and signature help
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
      --'rcarriga/nvim-notify',
    },
  },
}
