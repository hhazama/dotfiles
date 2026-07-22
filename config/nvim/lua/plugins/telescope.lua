return {
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

      -- スコープ付き live_grep: picker 内で検索範囲を調整できる
      --   <C-o> -> 検索対象ディレクトリをファジー選択("backend" 等で絞り込み)
      --   <C-e> -> 除外する拡張子/グロブを指定(例: "js, json" や "*.test.ts")
      -- どちらもセッション内で永続し、picker タイトルに表示され、入力途中のクエリも引き継がれる
      local grep_scope = { dir = nil, exclude = {} }

      local scoped_grep -- 前方宣言(pick_scope_dir が再オープンで参照する)

      -- ディレクトリのファジー選択。"." を選ぶとプロジェクト全体にリセット
      local function pick_scope_dir(query)
        local pickers = require 'telescope.pickers'
        local finders = require 'telescope.finders'
        local conf = require('telescope.config').values
        local actions = require 'telescope.actions'
        local action_state = require 'telescope.actions.state'
        pickers
          .new({}, {
            prompt_title = '検索ディレクトリ (スペース区切りでAND絞り込み / . = 全体)',
            finder = finders.new_oneshot_job({
              'find',
              '.',
              '-maxdepth',
              '8',
              '(',
              '-name',
              'node_modules',
              '-o',
              '-name',
              '.git',
              '-o',
              '-name',
              'cdk.out',
              ')',
              '-prune',
              '-o',
              '-type',
              'd',
              '-print',
            }, {}),
            sorter = conf.generic_sorter {},
            attach_mappings = function(bufnr)
              actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(bufnr)
                local dir = (entry and entry[1] or '.'):gsub('^%./', '')
                grep_scope.dir = (dir ~= '' and dir ~= '.') and dir or nil
                vim.schedule(function()
                  scoped_grep(query)
                end)
              end)
              return true
            end,
          })
          :find()
      end

      scoped_grep = function(default_text)
        local title = 'Live Grep'
        if grep_scope.dir then
          title = title .. '  ' .. grep_scope.dir
        end
        if #grep_scope.exclude > 0 then
          title = title .. '  !' .. table.concat(grep_scope.exclude, ',')
        end
        builtin.live_grep {
          prompt_title = title .. '  (C-o:dir C-e:除外)',
          search_dirs = grep_scope.dir and { grep_scope.dir } or nil,
          additional_args = function()
            local args = {}
            for _, g in ipairs(grep_scope.exclude) do
              args[#args + 1] = '--glob=!' .. g
            end
            return args
          end,
          default_text = default_text,
          attach_mappings = function(bufnr, map)
            local actions = require 'telescope.actions'
            local action_state = require 'telescope.actions.state'
            map({ 'i', 'n' }, '<C-o>', function()
              local query = action_state.get_current_line()
              actions.close(bufnr)
              vim.schedule(function()
                pick_scope_dir(query)
              end)
            end)
            map({ 'i', 'n' }, '<C-e>', function()
              local query = action_state.get_current_line()
              actions.close(bufnr)
              vim.ui.input({
                prompt = '無視する拡張子/グロブ (例: js, json / 空=解除): ',
                default = table.concat(grep_scope.exclude, ', '),
              }, function(v)
                if v ~= nil then
                  grep_scope.exclude = {}
                  for token in v:gmatch '[^,%s]+' do
                    -- 拡張子だけなら *.ext に展開、* や / を含むものはそのまま使う
                    grep_scope.exclude[#grep_scope.exclude + 1] = token:find '[*/]' and token or ('*.' .. token)
                  end
                end
                vim.schedule(function()
                  scoped_grep(query)
                end)
              end)
            end)
            return true
          end,
        }
      end

      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<C-s>', scoped_grep, { desc = '[S]earch by [G]rep (scoped)' })
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
}
