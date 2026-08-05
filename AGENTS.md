# Repository Guidelines

## Project Structure & Module Organization

This repository is a LazyVim starter fork for a Neovim configuration with an OpenCode terminal workflow. `init.lua` is the entry point and loads `lua/config/lazy.lua`, which bootstraps lazy.nvim and imports LazyVim plus local plugins.

- `lua/config/`: core configuration such as options, keymaps, autocmds, lazy.nvim setup, and OpenCode integration.
- `lua/plugins/`: plugin specs and overrides. Keep plugin-specific settings here unless they are shared editor behavior.
- `lazyvim.json` and `lazy-lock.json`: LazyVim metadata and pinned plugin versions.
- `stylua.toml`: Lua formatter settings.

There is no dedicated test or asset directory in this config. Add new files under `lua/config` or `lua/plugins` according to ownership.

## Build, Test, and Development Commands

- `nvim`: start Neovim and let lazy.nvim install or update missing plugins.
- `nvim --headless "+lua require('config.opencode'); print('opencode config ok')" "+qa"`: quick load check for the OpenCode config.
- `nvim --headless "+Lazy! sync" "+qa"`: synchronize plugins in a noninteractive session.
- `/home/zhhuang/.local/share/nvim/mason/bin/stylua .`: format Lua files using the repository style. `stylua` is installed by Mason here and may not be on the shell `PATH`.
- `git status -sb`: inspect local changes before committing.

## Coding Style & Naming Conventions

Write Lua with 2-space indentation, spaces instead of tabs, and a 120-column target, matching `stylua.toml`. Prefer small, focused modules and local helper functions over global state. Use descriptive lowercase filenames such as `opencode.lua` or `snacks.lua`. Keep LazyVim plugin specs declarative in `lua/plugins/*.lua`; keep editor behavior in `lua/config/*.lua`.

## Testing Guidelines

There is no formal test suite. Validate changes by launching `nvim` and by running a focused headless load check for the touched module. For keymaps or terminal behavior, test interactively in Neovim because mode transitions and terminal buffers are user-facing behavior.

## Commit & Pull Request Guidelines

Recent history uses short imperative subjects, sometimes with conventional prefixes such as `docs:` and `fix:`. Examples: `Fix typing text wrapping`, `docs: Explain more about how to add and remove autocmds`. Keep commits scoped to one change and mention affected modules when useful.

Record every behavior or configuration change in `CHANGELOG.md` before committing or handing off work.

Pull requests should include a brief description, validation steps run, and screenshots or terminal notes only when UI or terminal layout behavior changes. Link related issues when applicable and call out any plugin lockfile changes.

## Agent-Specific Instructions

Avoid reverting user edits in this config. Before editing existing files, check current status and preserve unrelated local changes. Prefer `rg` for search and `/home/zhhuang/.local/share/nvim/mason/bin/stylua` for formatting.
