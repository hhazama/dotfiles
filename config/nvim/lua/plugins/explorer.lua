return {
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
      { '<C-e>', ':Neotree reveal<CR>', { desc = 'NeoTree reveal' } },
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
            ['<C-e>'] = 'close_window',
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
}
