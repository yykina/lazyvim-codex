-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local autosave_group = vim.api.nvim_create_augroup("opencode_autosave", { clear = true })
local autosave_timers = {}

local function can_autosave(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "" then
    return false
  end

  return vim.bo[bufnr].modifiable
    and not vim.bo[bufnr].readonly
    and vim.bo[bufnr].modified
    and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function stop_autosave_timer(bufnr)
  local timer = autosave_timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    autosave_timers[bufnr] = nil
  end
end

local function write_buffer(bufnr)
  stop_autosave_timer(bufnr)

  if not can_autosave(bufnr) then
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    local ok, err = pcall(vim.cmd, "silent noautocmd write")
    if not ok then
      vim.notify("Autosave failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end)
end

local function schedule_autosave(bufnr, delay)
  if not can_autosave(bufnr) then
    stop_autosave_timer(bufnr)
    return
  end

  stop_autosave_timer(bufnr)
  local timer = vim.uv.new_timer()
  autosave_timers[bufnr] = timer
  timer:start(delay or 750, 0, vim.schedule_wrap(function()
    write_buffer(bufnr)
  end))
end

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = autosave_group,
  callback = function(event)
    schedule_autosave(event.buf, 750)
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "FocusLost" }, {
  group = autosave_group,
  callback = function(event)
    write_buffer(event.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = autosave_group,
  callback = function(event)
    stop_autosave_timer(event.buf)
  end,
})
