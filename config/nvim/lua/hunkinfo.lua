-- gitsigns の情報から「今何番目の hunk にいるか」を返す(lualine 表示用)
local M = {}

---バッファ全体の hunk 数 n と、カーソル位置以前にある hunk 数 i から "± i/n" を返す
---(]c で進むごとにカウントが進む)。gitsigns 未ロードや変更なしの場合は空文字
function M.status(bufnr)
  local gs = package.loaded.gitsigns
  if not gs then
    return ''
  end
  local ok, hunks = pcall(gs.get_hunks, bufnr or 0)
  if not ok or not hunks or #hunks == 0 then
    return ''
  end
  local lnum = vim.fn.line '.'
  local idx = 0
  for i, h in ipairs(hunks) do
    local s = (h.added and h.added.start) or (h.removed and h.removed.start)
    if s and lnum >= math.max(s, 1) then
      idx = i
    end
  end
  return string.format('± %d/%d', idx, #hunks)
end

return M
