return {
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup {
        -- リアルタイムでblame情報を表示
        current_line_blame = true,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = 'eol', -- 行末に表示
          delay = 100, -- 100ms後に表示
          ignore_whitespace = false,
        },
        current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
        },
      }
    end,
  },

  -- マージコンフリクトを VSCode 風に解決する
  -- バッファローカルマッピング(コンフリクトを含むファイルでのみ有効):
  --   co: 自分側 / ct: 相手側 / cb: 両方 / c0: 両方破棄 / ]x / [x: 次/前のコンフリクトへ
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      { '<leader>gx', '<cmd>GitConflictListQf<cr>', desc = '[G]it conflict list (quickfix)' },
    },
    config = function()
      require('git-conflict').setup {
        default_mappings = true,
        default_commands = true,
        -- プラグイン側の disable_diagnostics は nvim 0.12 で削除された
        -- vim.diagnostic.disable() を使うため無効にし、下の autocmd で同等処理を行う
        disable_diagnostics = false,
        list_opener = 'copen',
      }

      -- コンフリクト検出時: マーカーが LSP には構文エラーに見えるため診断をミュートし、解決キーを通知する
      vim.api.nvim_create_autocmd('User', {
        pattern = 'GitConflictDetected',
        callback = function()
          vim.diagnostic.enable(false, { bufnr = vim.api.nvim_get_current_buf() })
          vim.notify('コンフリクト検出: co=自分 / ct=相手 / cb=両方 / ]x=次へ', vim.log.levels.INFO)
        end,
      })
      vim.api.nvim_create_autocmd('User', {
        pattern = 'GitConflictResolved',
        callback = function()
          vim.diagnostic.enable(true, { bufnr = vim.api.nvim_get_current_buf() })
        end,
      })
    end,
  },

  -- GitLab link generation
  {
    'ruifm/gitlinker.nvim',
    dependencies = 'nvim-lua/plenary.nvim',
    config = function()
      -- カスタムHTTPコールバック関数 gitlab.fdev用にhttpsで生成されるリンクはhttpにする
      local function get_gitlab_http_url(url_data)
        local url = require('gitlinker.hosts').get_gitlab_type_url(url_data)
        -- httpsをhttpに置換
        return url:gsub('^https://', 'http://')
      end

      require('gitlinker').setup {
        opts = {
          add_current_line_on_normal_mode = true,
          action_callback = require('gitlinker.actions').copy_to_clipboard,
          print_url = true,
        },
        callbacks = {
          ['gitlab.fdev'] = get_gitlab_http_url,
        },
        mappings = '<leader>gy',
      }
    end,
  },

  -- Diffview: GitLab MRライクな差分ビュー
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewRefresh' },
    keys = {
      -- dev との差分(MRと等価)
      { '<leader>gd', '<cmd>DiffviewOpen dev...HEAD<cr>', desc = '[G]it [D]iff vs dev' },
      -- 任意の ref と比較したい時はプロンプトで入力(origin/dev, main, HEAD~3 等)
      {
        '<leader>gr',
        function()
          local ref = vim.fn.input('Diffview ref (例: origin/dev, main, HEAD~3): ')
          if ref ~= '' then
            vim.cmd('DiffviewOpen ' .. ref)
          end
        end,
        desc = '[G]it diff vs [R]ef (任意指定)',
      },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = '[G]it diffview [Q]uit' },
      -- 現在ファイルの履歴
      { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it [F]ile history (current)' },
    },
    config = function()
      require('diffview').setup {
        enhanced_diff_hl = true, -- 同一行内の差分箇所を強調
        view = {
          merge_tool = {
            layout = 'diff3_mixed', -- マージコンフリクト時の3-way表示
          },
        },
        file_panel = {
          listing_style = 'tree', -- ファイル一覧をツリー表示(GitLabに近い)
          win_config = {
            width = 40,
          },
        },
      }
    end,
  },
}
