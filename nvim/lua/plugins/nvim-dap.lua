return {
  {
    "mfussenegger/nvim-dap",
    keys = { "<leader>db", "<leader>dc", "<leader>dO", "<leader>di", "<leader>do" },
    cmd = { "DapContinue", "DapToggleBreakpoint", "DapNew" },
    config = function()
      local dap = require("dap")

      -- Adapters are functions so they resolve when a session starts, not
      -- when dap loads: Mason (lua/config/mason_tools.lua) may still be
      -- installing them on a fresh machine.

      -- Python: Mason's debugpy (its own venv), else a debugpy importable
      -- from the system python.
      dap.adapters.python = function(callback)
        if vim.fn.executable("debugpy-adapter") == 1 then
          callback({ type = "executable", command = "debugpy-adapter" })
        else
          callback({ type = "executable", command = "python", args = { "-m", "debugpy.adapter" } })
        end
      end
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch Python file",
          program = "${file}",   -- Current file
          pythonPath = "python", -- Adjust if needed (e.g., "/usr/bin/python3")
        },
      }

      -- C/C++ and CUDA (cpptools): Mason's OpenDebugAD7, else a VS Code
      -- install of the extension.
      dap.adapters.cppdbg = function(callback)
        local command = vim.fn.exepath("OpenDebugAD7")
        if command == "" then
          command = vim.fn.glob("~/.vscode/extensions/ms-vscode.cpptools-*/debugAdapters/bin/OpenDebugAD7", false, true)[1]
            or "OpenDebugAD7"
        end
        callback({
          id = "cppdbg",
          type = "executable",
          command = command,
          options = { detached = false },
        })
      end
      dap.configurations.cpp = {
        {
          name = "Launch C/C++/CUDA",
          type = "cppdbg",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.expand("%:p:r"), "file")
          end,
          cwd = "${workspaceFolder}",
          stopAtEntry = true,
          setupCommands = {
            {
              text = "-enable-pretty-printing",
              description = "Enable pretty-printing for gdb",
              ignoreFailures = true,
            },
          },
        },
      }
      -- Reuse C++ config for C and CUDA
      dap.configurations.c = dap.configurations.cpp
      dap.configurations.cuda = dap.configurations.cpp -- CUDA uses same debugger (gdb/lldb via cpptools)

      -- Go: delve from AppStream; `dlv dap` speaks DAP natively.
      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }
      dap.configurations.go = {
        { type = "delve", name = "Debug file", request = "launch", program = "${file}" },
        { type = "delve", name = "Debug package", request = "launch", program = "${fileDirname}" },
        { type = "delve", name = "Debug test (package)", request = "launch", mode = "test", program = "${fileDirname}" },
      }

      -- Keymaps
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { noremap = true, silent = true, desc = "DAP: Toggle breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue, { noremap = true, silent = true, desc = "DAP: Continue" })
      -- Step over is <leader>dO, not <leader>ds: LSP buffers bind
      -- <leader>ds to document symbols (lua/config/autocmds.lua).
      vim.keymap.set("n", "<leader>dO", dap.step_over, { noremap = true, silent = true, desc = "DAP: Step over" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { noremap = true, silent = true, desc = "DAP: Step into" })
      vim.keymap.set("n", "<leader>do", dap.step_out, { noremap = true, silent = true, desc = "DAP: Step out" })
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    name = "dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    keys = { "<leader>dt", "<leader>dr" },
    config = function()
      require("dapui").setup()
      vim.keymap.set("n", "<leader>dt", require("dapui").toggle, { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>dr", function() require("dapui").open({ reset = true }) end,
        { noremap = true, silent = true })
    end,
  },
}

