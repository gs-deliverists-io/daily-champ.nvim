# Agent Guidelines for daily-champ.nvim

## Project Type
Neovim plugin written in Lua for managing daily task markdown files.

## Build/Test Commands
- No build step required (Lua interpreted)
- Test manually: `:source plugin/dailychamp.lua` in Neovim
- Test plugin load: Open a markdown file matching `*/daily.md` pattern
- No automated test suite currently exists

## Code Style
- **Language**: Lua 5.1+ (Neovim LuaJIT)
- **Indentation**: 2 spaces, no tabs
- **Comments**: Start with `--`, descriptive function headers
- **Functions**: Use `function M.function_name()` for module exports, `local function` for helpers
- **Naming**: snake_case for functions/variables (e.g., `insert_new_day`, `get_cursor_pos`)
- **Strings**: Double quotes preferred, single quotes for Vim commands
- **Module pattern**: Return table `M` with exported functions, use `M.config` for configuration
- **Error handling**: Use `if not ... then return end` pattern, print user-friendly messages with `print()`
- **Vim API**: Prefer `vim.api.*` over legacy `:` commands where possible
- **User input**: Use `vim.ui.input()` for prompts, provide defaults and validation
