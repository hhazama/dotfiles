vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- jjでノーマルモードに戻る
vim.keymap.set('i', 'jj', '<Esc>')
-- Ctrl+w+t で新しいタブ作成
vim.keymap.set('n', '<C-w>t', ':tabnew<CR>', { desc = 'New tab' })

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
-- SJISでファイルを開き直す
vim.keymap.set('n', '<leader>S', '<cmd>e ++enc=sjis<CR>', { desc = 'Reopen as [S]JIS' })

-- ターミナルを開くキーマップ
vim.keymap.set('n', '<leader>ts', ':split | terminal<CR>', { desc = '[T]erminal [T]oggle (horizontal)' })
vim.keymap.set('n', '<leader>tv', ':vsplit | terminal<CR>', { desc = '[T]erminal [V]ertical' })
