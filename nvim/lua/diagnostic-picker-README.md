# Diagnostic Picker with Clangd Config Integration

## Summary

Your diagnostic-picker now has complete clangd integration:

1. **Global Config**: `~/.config/clangd/config.yaml` with verbose defaults (C++17, many checks enabled)
2. **Runtime Toggling**: Use `<leader>dg` to open picker and toggle any check on/off
3. **C++ Standard Selection**: Switch between c++98 through c++26 in the picker
4. **Config Merging**: Reads both global and local `.clangd` files, shows which is active
5. **Visual Indicators**:
   - 🌍 = Check from global config
   - 📁 = Check from local .clangd
   - ❌ = Disabled check
6. **Auto-Restart**: Automatically runs `:LspRestart clangd` when you apply changes

## Usage

1. Open a C/C++ file
2. Press `<leader>dg` (or your mapped key)
3. Navigate with j/k, toggle with Space, expand categories with Tab
4. Change C++ standard by pressing Space on desired version
5. Press Enter to apply (creates/updates `.clangd` and restarts LSP)

## Files Modified

- `~/.config/nvim/lua/diagnostic-picker.lua` - Enhanced with clangd support
- `~/.config/clangd/config.yaml` - New global config file
- `~/.config/clangd/README.md` - Documentation

## Testing

Test file created at `/tmp/test-clangd-picker/test.cpp` with intentional violations:
- Magic numbers
- Old-style loops
- C-style casts
- Unused variables

## Next Steps

To make this truly language-agnostic:

1. Extract clangd-specific logic into a "provider" module
2. Create provider interface with standard methods
3. Implement providers for other languages (pylsp, rust-analyzer, lua_ls, etc)
4. Registry system to auto-detect and load appropriate provider
5. Keep core picker logic language-neutral

See architecture discussion below.
