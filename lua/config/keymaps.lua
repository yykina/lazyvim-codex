-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local opencode = require("config.opencode")
local window_sizes = require("config.window_sizes")

local MIN_TERMINAL_WIDTH = 40
local MAX_TERMINALS = 3

opencode.setup()
window_sizes.setup()

local function current_snacks_terminal()
  return type(vim.b.snacks_terminal) == "table" and vim.b.snacks_terminal or nil
end

local function terminal_count(count)
  count = math.floor(tonumber(count) or 1)
  return ((count - 1) % MAX_TERMINALS) + 1
end

local function numbered_terminal(count, cwd)
  count = terminal_count(count)
  for _, terminal in ipairs(Snacks.terminal.list()) do
    local info = terminal.buf and vim.b[terminal.buf].snacks_terminal
    if type(info) == "table" and tostring(info.id) == tostring(count) and (not cwd or info.cwd == cwd) then
      return terminal
    end
  end
end

local function visible_terminal_windows()
  local windows = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local info = vim.b[bufnr].snacks_terminal
    local snacks_win = vim.w[winid].snacks_win
    if
      type(info) == "table"
      and type(snacks_win) == "table"
      and snacks_win.position == "bottom"
      and vim.api.nvim_win_get_config(winid).relative == ""
    then
      local pos = vim.api.nvim_win_get_position(winid)
      windows[#windows + 1] = {
        winid = winid,
        info = info,
        id = tonumber(info.id) or math.huge,
        row = pos[1],
        col = pos[2],
      }
    end
  end

  table.sort(windows, function(a, b)
    return a.row == b.row and a.col < b.col or a.row < b.row
  end)

  return windows
end

local function visible_terminal_infos()
  local infos = {}
  for _, terminal_win in ipairs(visible_terminal_windows()) do
    infos[#infos + 1] = terminal_win.info
  end
  return infos
end

local function sort_visible_terminals(preferred_win)
  local fallback_win = vim.api.nvim_get_current_win()

  for _ = 1, MAX_TERMINALS * MAX_TERMINALS do
    local windows = visible_terminal_windows()
    local swapped = false

    for index = 1, #windows - 1 do
      if windows[index].id > windows[index + 1].id then
        vim.api.nvim_set_current_win(windows[index].winid)
        vim.cmd("wincmd x")
        swapped = true
        break
      end
    end

    if not swapped then
      break
    end
  end

  local restore_win = preferred_win and vim.api.nvim_win_is_valid(preferred_win) and preferred_win or fallback_win
  if restore_win and vim.api.nvim_win_is_valid(restore_win) then
    vim.api.nvim_set_current_win(restore_win)
  end
end

local function first_visible_terminal_count()
  local first = nil
  for _, info in ipairs(visible_terminal_infos()) do
    local id = tonumber(info.id)
    if id and (not first or id < first) then
      first = id
    end
  end
  return first or 1
end

local function has_room_for_new_terminal()
  return math.floor(vim.o.columns / (#visible_terminal_infos() + 1)) >= MIN_TERMINAL_WIDTH
end

local function leave_terminal_input()
  if vim.bo.buftype == "terminal" then
    pcall(vim.cmd.stopinsert)
  end
end

local function code_cwd()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    local dir = vim.fn.fnamemodify(bufname, ":p:h")
    if dir ~= "" and vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return vim.uv.cwd()
end

local function focus_numbered_terminal(count)
  count = terminal_count(count)
  local terminal = current_snacks_terminal()
  local cwd = terminal and terminal.cwd or nil
  leave_terminal_input()

  if vim.bo.filetype == "opencode" then
    opencode.focus_code()
  end

  vim.schedule(function()
    local terminal = Snacks.terminal.focus(nil, { cwd = cwd or code_cwd(), count = count })
    sort_visible_terminals(terminal and terminal.win)
    vim.cmd("redraw!")
  end)
end

local function toggle_current_terminal()
  local terminal = current_snacks_terminal()
  if terminal then
    focus_numbered_terminal(terminal.id)
  else
    focus_numbered_terminal(1)
  end
end

local function focus_next_root_terminal()
  local terminal = current_snacks_terminal()
  local cwd = terminal and terminal.cwd or code_cwd()
  local count = terminal and terminal_count((tonumber(terminal.id) or 1) + 1) or 1
  local target = numbered_terminal(count, cwd)
  if not (target and target.win and vim.api.nvim_win_is_valid(target.win)) and not has_room_for_new_terminal() then
    count = first_visible_terminal_count()
  end
  focus_numbered_terminal(count)
end

local function insert_left()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if vim.bo.buftype ~= "" or col > 0 then
    return "<Left>"
  end

  return row > 1 and "<Up><End>" or ""
end

vim.keymap.set({ "n", "i" }, "<M-h>", opencode.toggle, { desc = "Toggle OpenCode agent" })
vim.keymap.set({ "n", "i" }, "<A-h>", opencode.toggle, { desc = "Toggle OpenCode agent" })
vim.keymap.set("i", "<Esc>h", opencode.toggle, { desc = "Toggle OpenCode agent" })

vim.keymap.set({ "n", "i", "t" }, "<C-/>", toggle_current_terminal, { desc = "Toggle Current Terminal" })
vim.keymap.set({ "n", "i", "t" }, "<C-_>", toggle_current_terminal, { desc = "Toggle Current Terminal" })
vim.keymap.set({ "n", "i", "t" }, "<M-u>", function()
  focus_numbered_terminal(1)
end, { desc = "Terminal 1 (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<M-i>", function()
  focus_numbered_terminal(2)
end, { desc = "Terminal 2 (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<M-o>", function()
  focus_numbered_terminal(3)
end, { desc = "Terminal 3 (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<A-u>", function()
  focus_numbered_terminal(1)
end, { desc = "Terminal 1 (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<A-i>", function()
  focus_numbered_terminal(2)
end, { desc = "Terminal 2 (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<A-o>", function()
  focus_numbered_terminal(3)
end, { desc = "Terminal 3 (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<M-/>", focus_next_root_terminal, { desc = "Next Terminal (Root Dir)" })
vim.keymap.set({ "n", "i", "t" }, "<A-/>", focus_next_root_terminal, { desc = "Next Terminal (Root Dir)" })

local function focus_code_window()
  if vim.bo.buftype == "terminal" then
    pcall(vim.cmd.stopinsert)
  end

  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev ~= 0 and vim.api.nvim_win_is_valid(prev) then
    local bufnr = vim.api.nvim_win_get_buf(prev)
    if vim.bo[bufnr].buftype ~= "terminal" then
      vim.api.nvim_set_current_win(prev)
      return
    end
  end

  local current = vim.api.nvim_get_current_win()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if winid ~= current and vim.bo[vim.api.nvim_win_get_buf(winid)].buftype ~= "terminal" then
      vim.api.nvim_set_current_win(winid)
      return
    end
  end
end

vim.keymap.set({ "n", "t" }, "<M-;>", focus_code_window, { desc = "Focus Code Window (keep terminal open)" })
vim.keymap.set("i", "<Left>", insert_left, { expr = true, replace_keycodes = true, desc = "Move left across lines" })
