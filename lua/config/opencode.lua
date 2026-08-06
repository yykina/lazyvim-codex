local M = {}

local window_sizes = require("config.window_sizes")

local DEFAULT_WIDTH_RATIO = 0.3
local MIN_CODEX_WIDTH = 20
local CODEX_TERMINAL_SCROLLBACK = 100000

local state = {
  bufnr = nil,
  winid = nil,
  job_id = nil,
  last_code_winid = nil,
  last_code_mode = "n",
  opencode_width = window_sizes.get("opencode_width"),
  last_layout = nil,
  applying_width = false,
  opening_opencode = false,
  entering_terminal = false,
  checktime_timer = nil,
}

local sync_opencode_width

local function valid_buf(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function valid_win(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

local function valid_opencode_win(winid)
  return valid_win(winid) and valid_buf(state.bufnr) and vim.api.nvim_win_get_buf(winid) == state.bufnr
end

local function valid_code_win(winid)
  if not valid_win(winid) or valid_opencode_win(winid) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.bo[bufnr].buftype ~= "terminal"
end

local function valid_job(job_id)
  return type(job_id) == "number" and job_id > 0
end

local function current_is_opencode_buffer()
  return valid_buf(state.bufnr) and vim.api.nvim_get_current_buf() == state.bufnr
end

local function opencode_terminal_active()
  return current_is_opencode_buffer() and valid_job(state.job_id)
end

local function stop_checktime_timer()
  if state.checktime_timer then
    state.checktime_timer:stop()
    state.checktime_timer:close()
    state.checktime_timer = nil
  end
end

local function check_external_changes()
  if sync_opencode_width then
    sync_opencode_width()
  end

  if not valid_buf(state.bufnr) or not valid_job(state.job_id) then
    stop_checktime_timer()
    return
  end

  if vim.o.buftype == "nofile" then
    return
  end

  vim.cmd("silent! checktime")
end

local function start_checktime_timer()
  if state.checktime_timer then
    return
  end

  state.checktime_timer = vim.uv.new_timer()
  state.checktime_timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      check_external_changes()
    end)
  )
end

local function project_root()
  if _G.LazyVim and LazyVim.root then
    if type(LazyVim.root.cwd) == "function" then
      return LazyVim.root.cwd()
    end
    if type(LazyVim.root.get) == "function" then
      return LazyVim.root.get()
    end
  end

  local ok, lazyvim = pcall(require, "lazyvim.util")
  if ok and lazyvim.root then
    if type(lazyvim.root.cwd) == "function" then
      return lazyvim.root.cwd()
    end
    if type(lazyvim.root.get) == "function" then
      return lazyvim.root.get()
    end
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  local start = bufname ~= "" and vim.fs.dirname(bufname) or vim.uv.cwd()
  local marker = vim.fs.find({ ".git", "lua", "package.json", "pyproject.toml", "Cargo.toml", "go.mod" }, {
    upward = true,
    path = start,
  })[1]

  return marker and vim.fs.dirname(marker) or vim.uv.cwd()
end

local function current_code_mode()
  local mode = vim.api.nvim_get_mode().mode
  return mode:sub(1, 1) == "i" and "i" or "n"
end

local function remember_code_window(opts)
  if state.opening_opencode then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  local buftype = vim.bo.buftype
  if buftype ~= "terminal" and not valid_opencode_win(winid) then
    state.last_code_winid = winid
    if opts and opts.mode then
      state.last_code_mode = current_code_mode()
    end
  end
end

local function find_opencode_window()
  if valid_opencode_win(state.winid) then
    return state.winid
  end

  if not valid_buf(state.bufnr) then
    return nil
  end

  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if valid_opencode_win(winid) then
        state.winid = winid
        return winid
      end
    end
  end

  return nil
end

local function normal_windows()
  local wins = {}

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if valid_win(winid) and vim.api.nvim_win_get_config(winid).relative == "" then
      wins[#wins + 1] = winid
    end
  end

  table.sort(wins)
  return wins
end

local function layout_signature()
  local wins = normal_windows()

  return {
    columns = vim.o.columns,
    windows = table.concat(wins, ","),
    count = #wins,
  }
end

local function same_layout(left, right)
  return left
    and right
    and left.columns == right.columns
    and left.windows == right.windows
    and left.count == right.count
end

local function clamp_opencode_width(width)
  width = math.floor(tonumber(width) or vim.o.columns * DEFAULT_WIDTH_RATIO)

  local win_count = math.max(#normal_windows(), 1)
  local separators = math.max(win_count - 1, 0)
  local other_window_min = math.max(vim.o.winminwidth, 1) * math.max(win_count - 1, 0)
  local max_width = vim.o.columns - separators - other_window_min
  local min_width = math.min(MIN_CODEX_WIDTH, math.max(max_width, 1))

  return math.max(min_width, math.min(width, math.max(max_width, min_width)))
end

local function default_opencode_width()
  return clamp_opencode_width(vim.o.columns * DEFAULT_WIDTH_RATIO)
end

local function apply_opencode_width(winid, width)
  if not valid_win(winid) then
    return
  end

  local target_width = clamp_opencode_width(width or state.opencode_width or default_opencode_width())

  state.applying_width = true
  pcall(vim.api.nvim_set_option_value, "winfixwidth", true, { win = winid })
  pcall(vim.api.nvim_win_set_width, winid, target_width)
  state.applying_width = false
end

local function update_layout_snapshot()
  state.last_layout = layout_signature()
end

sync_opencode_width = function(opts)
  if state.applying_width or state.opening_opencode then
    return
  end

  local winid = find_opencode_window()
  if not winid then
    update_layout_snapshot()
    return
  end

  local layout = layout_signature()
  local layout_changed = not same_layout(layout, state.last_layout)
  local current_width = vim.api.nvim_win_get_width(winid)

  if not state.opencode_width then
    state.opencode_width = current_width
    update_layout_snapshot()
    return
  end

  if layout_changed or (opts and opts.force_restore) then
    apply_opencode_width(winid, state.opencode_width)
    update_layout_snapshot()
    return
  end

  if current_width ~= state.opencode_width then
    state.opencode_width = current_width
    window_sizes.set("opencode_width", current_width)
  end

  update_layout_snapshot()
end

local function schedule_opencode_width_sync(opts)
  vim.schedule(function()
    if sync_opencode_width then
      sync_opencode_width(opts)
    end
  end)
end

local function start_terminal_mode()
  if state.entering_terminal or not opencode_terminal_active() or vim.api.nvim_get_mode().mode == "t" then
    return
  end

  state.entering_terminal = true
  pcall(vim.cmd.startinsert)
  state.entering_terminal = false
end

local function ensure_terminal_mode()
  if opencode_terminal_active() and vim.api.nvim_get_mode().mode ~= "t" then
    vim.schedule(start_terminal_mode)
  end
end

local function enter_terminal()
  vim.schedule(function()
    start_terminal_mode()
    vim.defer_fn(start_terminal_mode, 20)
  end)
end

local function restore_opencode_window(winid)
  if not valid_win(winid) or not valid_buf(state.bufnr) or not valid_job(state.job_id) then
    return false
  end

  state.winid = winid
  vim.api.nvim_set_current_win(winid)
  vim.api.nvim_win_set_buf(winid, state.bufnr)
  apply_opencode_width(winid, state.opencode_width)
  update_layout_snapshot()
  enter_terminal()
  return true
end

local function focus_code_window(mode)
  if valid_code_win(state.last_code_winid) then
    vim.api.nvim_set_current_win(state.last_code_winid)
  else
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if valid_code_win(winid) then
        vim.api.nvim_set_current_win(winid)
        break
      end
    end

    if valid_opencode_win(vim.api.nvim_get_current_win()) then
      vim.cmd.wincmd("h")
    end
  end

  if mode == "i" and vim.bo.buftype ~= "terminal" then
    vim.schedule(function()
      if vim.bo.buftype ~= "terminal" then
        vim.cmd.startinsert()
      end
    end)
  end
end

local function terminal_to_code()
  pcall(vim.cmd.stopinsert)

  vim.schedule(function()
    if valid_buf(state.bufnr) then
      M.focus_code()
    end
  end)
end

local function enter_opencode_input()
  enter_terminal()
end

local function set_terminal_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, desc = "Focus code window" }

  vim.keymap.set("t", "<M-h>", terminal_to_code, opts)
  vim.keymap.set("t", "<A-h>", terminal_to_code, opts)
  vim.keymap.set("t", "<Esc>h", terminal_to_code, opts)

  vim.keymap.set("n", "<M-h>", function()
    M.focus_code()
  end, opts)
  vim.keymap.set("n", "<A-h>", function()
    M.focus_code()
  end, opts)
  vim.keymap.set("n", "i", enter_opencode_input, {
    buffer = bufnr,
    silent = true,
    desc = "Enter OpenCode input",
  })
  vim.keymap.set("n", "a", enter_opencode_input, {
    buffer = bufnr,
    silent = true,
    desc = "Enter OpenCode input",
  })
  vim.keymap.set("n", "<CR>", enter_opencode_input, {
    buffer = bufnr,
    silent = true,
    desc = "Enter OpenCode input",
  })
end

local function start_opencode()
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, state.bufnr)
  vim.bo[state.bufnr].bufhidden = "hide"
  vim.bo[state.bufnr].filetype = "opencode"
  vim.bo[state.bufnr].scrollback = CODEX_TERMINAL_SCROLLBACK
  vim.api.nvim_buf_set_name(state.bufnr, "OpenCode Agent")

  state.job_id = vim.fn.termopen({ "opencode" }, {
    cwd = project_root(),
    on_exit = function()
      state.job_id = nil
      stop_checktime_timer()
    end,
  })

  if not valid_job(state.job_id) then
    vim.notify("Failed to start opencode", vim.log.levels.ERROR)
    return
  end

  set_terminal_keymaps(state.bufnr)
  start_checktime_timer()
end

local function open_window()
  remember_code_window()
  state.opening_opencode = true
  vim.cmd("botright vertical split")
  state.winid = vim.api.nvim_get_current_win()
  state.opening_opencode = false
  state.opencode_width = state.opencode_width or default_opencode_width()
  apply_opencode_width(state.winid, state.opencode_width)
  update_layout_snapshot()
end

function M.focus_code()
  focus_code_window(state.last_code_mode)
end

function M.focus_code_insert()
  focus_code_window("i")
end

function M.restore_width()
  schedule_opencode_width_sync({ force_restore = true })
  vim.defer_fn(function()
    sync_opencode_width({ force_restore = true })
  end, 50)
end

function M.toggle()
  local opencode_winid = find_opencode_window()
  if opencode_winid then
    local current = vim.api.nvim_get_current_win()
    if current == opencode_winid then
      focus_code_window(state.last_code_mode)
    else
      remember_code_window({ mode = true })
      vim.api.nvim_set_current_win(opencode_winid)
      enter_terminal()
    end
    return
  end

  if valid_win(state.winid) and valid_buf(state.bufnr) and valid_job(state.job_id) then
    restore_opencode_window(state.winid)
    return
  else
    remember_code_window({ mode = true })
    if vim.bo.buftype == "terminal" then
      focus_code_window("n")
    end
    open_window()
  end

  if valid_buf(state.bufnr) and valid_job(state.job_id) then
    vim.api.nvim_win_set_buf(0, state.bufnr)
    start_checktime_timer()
  else
    if valid_buf(state.bufnr) then
      vim.api.nvim_buf_delete(state.bufnr, { force = true })
    end
    start_opencode()
  end

  enter_terminal()
end

function M.setup()
  local group = vim.api.nvim_create_augroup("opencode_agent_terminal", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      if valid_opencode_win(winid) then
        state.winid = winid
        enter_terminal()
      elseif winid == state.winid and valid_buf(state.bufnr) and valid_job(state.job_id) then
        restore_opencode_window(winid)
      else
        remember_code_window()
        check_external_changes()
      end
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = "*",
    callback = function()
      ensure_terminal_mode()
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "CursorHold", "CursorHoldI" }, {
    group = group,
    callback = ensure_terminal_mode,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "WinNew", "VimResized", "TabEnter" }, {
    group = group,
    callback = function()
      schedule_opencode_width_sync({ force_restore = true })
    end,
  })

  pcall(vim.api.nvim_create_autocmd, "WinResized", {
    group = group,
    callback = function()
      schedule_opencode_width_sync()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = stop_checktime_timer,
  })
end

return M
