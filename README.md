# LazyVim OpenCode

A [LazyVim starter](https://github.com/LazyVim/starter) fork with an integrated
OpenCode agent workflow.

## Features

- Opens OpenCode in a persistent right-side Neovim terminal.
- Uses `Alt-h` to toggle between the editor and OpenCode.
- Autosaves normal file buffers after a short delay so OpenCode can read the latest
  editor changes from disk.
- Automatically checks for external file changes while OpenCode is running, so files
  edited by OpenCode are reloaded without manual `:edit` or `:checktime`.
- Keeps a small terminal layout and project-root-aware OpenCode startup.

## Install

Back up any existing config first, then clone this repository as your Neovim
config:

```sh
git clone git@github.com:ykn05/lazyvim-codex.git ~/.config/nvim
```

Start Neovim and let LazyVim install plugins:

```sh
nvim
```

## Track Upstream

This repository is a fork of `LazyVim/starter`. To pull template updates:

```sh
git fetch upstream
git merge upstream/main
```

LazyVim itself is managed as a plugin dependency through lazy.nvim. Use
LazyVim's normal update flow inside Neovim to update plugin versions.
