local M = {}

local DEFAULTS = {
  opencode_width = nil,
  explorer_width = 25,
  terminal_height = nil,
}

local MIN_EXPLORER_WIDTH = 20
local MIN_TERMINAL_HEIGHT = 3

local state_path = vim.fn.stdpath("state") .. "/layout-sizes.json"
local sizes = nil
local save_timer = nil

local function load()
  if sizes then
    return sizes
  end

  sizes = vim.deepcopy(DEFAULTS)

  local ok, lines = pcall(vim.fn.readfile, state_path)
  if not ok or #lines == 0 then
    return sizes
  end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if decoded_ok and type(decoded) == "table" then
    sizes = vim.tbl_extend("force", sizes, decoded)
  end

  return sizes
end

local function save()
  local dir = vim.fs.dirname(state_path)
  if dir then
    vim.fn.mkdir(dir, "p")
  end

  pcall(vim.fn.writefile, { vim.json.encode(load()) }, state_path)
end

local function schedule_save()
  if save_timer then
    save_timer:stop()
  else
    save_timer = vim.uv.new_timer()
  end

  save_timer:start(
    150,
    0,
    vim.schedule_wrap(function()
      save()
    end)
  )
end

local function set_number(key, value)
  value = math.floor(tonumber(value) or 0)
  if value <= 0 then
    return
  end

  local current = load()[key]
  if current == value then
    return
  end

  sizes[key] = value
  schedule_save()
end

function M.get(key)
  return load()[key]
end

function M.set(key, value)
  set_number(key, value)
end

function M.explorer_width()
  return math.max(tonumber(load().explorer_width) or DEFAULTS.explorer_width, MIN_EXPLORER_WIDTH)
end

function M.terminal_height()
  local height = tonumber(load().terminal_height)
  return height and math.max(height, MIN_TERMINAL_HEIGHT) or 0.2
end

local function remember_terminal_height()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local snacks_win = vim.w[winid].snacks_win
    if
      vim.api.nvim_win_get_config(winid).relative == ""
      and vim.bo[bufnr].filetype == "snacks_terminal"
      and type(snacks_win) == "table"
      and snacks_win.position == "bottom"
    then
      set_number("terminal_height", vim.api.nvim_win_get_height(winid))
    end
  end
end

local function remember_explorer_width()
  local ok, picker = pcall(require, "snacks.picker.core.picker")
  if not ok then
    return
  end

  for _, active in ipairs(picker.get({ source = "explorer", tab = false })) do
    local root = active.layout and active.layout.root
    if root and root.win and vim.api.nvim_win_is_valid(root.win) then
      set_number("explorer_width", vim.api.nvim_win_get_width(root.win))
    end
  end
end

local function remember_layout_sizes()
  remember_terminal_height()
  remember_explorer_width()
end

function M.setup()
  local group = vim.api.nvim_create_augroup("remember_layout_sizes", { clear = true })

  pcall(vim.api.nvim_create_autocmd, "WinResized", {
    group = group,
    callback = function()
      vim.schedule(remember_layout_sizes)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      remember_layout_sizes()
      save()
      if save_timer then
        save_timer:stop()
        save_timer:close()
        save_timer = nil
      end
    end,
  })
end

return M
