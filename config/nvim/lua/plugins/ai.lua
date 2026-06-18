return {
  -- snacks.nvim: claudecode.nvim のターミナル provider に必須
  {
    'folke/snacks.nvim',
    opts = {
      terminal = {},
    },
  },

  -- Claude Code を nvim に接続(選択範囲・診断を渡し、差分を nvim 内で承認/却下)
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    opts = {},
    cmd = {
      'ClaudeCode',
      'ClaudeCodeFocus',
      'ClaudeCodeSelectModel',
      'ClaudeCodeAdd',
      'ClaudeCodeSend',
      'ClaudeCodeTreeAdd',
      'ClaudeCodeStatus',
      'ClaudeCodeDiffAccept',
      'ClaudeCodeDiffDeny',
    },
    keys = {
      { '<leader>ac', '<cmd>ClaudeCode<cr>', desc = 'Claude Code 起動/切替' },
      { '<leader>af', '<cmd>ClaudeCodeFocus<cr>', desc = 'Claude にフォーカス' },
      { '<leader>ar', '<cmd>ClaudeCode --resume<cr>', desc = 'Claude セッション再開' },
      { '<leader>aC', '<cmd>ClaudeCode --continue<cr>', desc = 'Claude 直近を継続' },
      { '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'Claude モデル選択' },
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = '現在バッファを Claude に追加' },
      { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = '選択範囲を Claude に送信' },
      {
        '<leader>as',
        '<cmd>ClaudeCodeTreeAdd<cr>',
        desc = 'ファイルを Claude に追加',
        ft = { 'neo-tree', 'NvimTree', 'oil' },
      },
      { '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Claude の差分を承認' },
      { '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Claude の差分を却下' },
    },
  },

  -- バッファ内 AI チャット/インライン編集。claude_code ACP アダプタで Claude Code のサブスク認証を流用(API 従量課金なし)
  -- 認証: `claude setup-token` で OAuth トークンを発行し、環境変数 CLAUDE_CODE_OAUTH_TOKEN に設定する(設定ファイルにトークンは書かない)
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {
      strategies = {
        chat = { adapter = 'claude_code' },
        inline = { adapter = 'claude_code' },
      },
    },
    cmd = { 'CodeCompanion', 'CodeCompanionChat', 'CodeCompanionActions' },
    keys = {
      { '<leader>ai', '<cmd>CodeCompanionChat Toggle<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion チャット' },
      { '<leader>ap', '<cmd>CodeCompanionActions<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion アクション' },
      { '<leader>ae', '<cmd>CodeCompanion<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion インライン編集' },
    },
  },

  -- copilot.vim を Lua 実装に移行。インライン補完(ghost text)は Tab を奪うため無効化し、:Copilot コマンドのみ利用
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
}
