return {
  -- GitHub Copilot
  {
    'github/copilot.vim',
    lazy = false,
  },

  {
    'epwalsh/obsidian.nvim',
    version = '*',
    lazy = false,
    dependencies = { 'nvim-lua/plenary.nvim' },
    ft = 'markdown',
    config = function()
      require('obsidian').setup {
        workspaces = {
          {
            name = 'main',
            path = '~/obsidian_vault/main/',
          },
        },
        daily_notes = {
          folder = 'daily',
          date_format = '%Y-%m-%d',
          template = 'daily.md',
        },
        templates = {
          folder = 'templates',
        },
      }
    end,
  },
}
