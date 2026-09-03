vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.undofile = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
-- Homebrew is not on PATH inside GUI-launched Neovim, and does not exist at
-- all on Linux. Prepend whichever prefixes are actually present.
for _, dir in ipairs({ "/opt/homebrew/bin", "/usr/local/bin", "/home/linuxbrew/.linuxbrew/bin" }) do
  if vim.fn.isdirectory(dir) == 1 then
    vim.env.PATH = dir .. ":" .. vim.env.PATH
  end
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

local neo_tree_width_file = vim.fn.stdpath("state") .. "/neo-tree-width"

local function read_neo_tree_width()
  local file = io.open(neo_tree_width_file, "r")
  if not file then
    return 26
  end
  local width = tonumber(file:read("*l"))
  file:close()
  if width and width >= 10 then
    return width
  end
  return 26
end

local function save_neo_tree_width()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      vim.fn.mkdir(vim.fn.fnamemodify(neo_tree_width_file, ":h"), "p")
      local file = io.open(neo_tree_width_file, "w")
      if file then
        file:write(tostring(vim.api.nvim_win_get_width(win)))
        file:close()
      end
      return
    end
  end
end

require("lazy").setup({
  { "folke/tokyonight.nvim", priority = 1000, opts = { style = "night" } },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.setup()

      local languages = {
        "css", "html", "javascript", "jsdoc", "json", "regex", "scss", "tsx",
        "typescript", "yaml",
      }
      local installed = treesitter.get_installed()
      local missing = vim.tbl_filter(function(lang)
        return not vim.list_contains(installed, lang)
      end, languages)
      if #missing > 0 then
        treesitter.install(missing)
      end
    end,
  },
  { "nvim-tree/nvim-web-devicons" },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      hide_root_node = true,
      retain_hidden_root_indent = false,
      filesystem = {
        filtered_items = { visible = true, hide_dotfiles = false, hide_gitignored = true },
        follow_current_file = { enabled = true },
      },
      window = { width = read_neo_tree_width, auto_expand_width = false },
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local actions = require("telescope.actions")
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/", "dist/", "build/", "target/" },
          preview = { treesitter = false },
          mappings = { i = { ["<esc>"] = actions.close } },
        },
      })
    end,
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Smart jump" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = { delay = 500 },
    },
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = {
        "bashls", "cssls", "dockerls", "emmet_language_server", "eslint",
        "graphql", "html", "jsonls", "lua_ls", "prismals", "tailwindcss",
        "ts_ls", "yamlls",
      },
      automatic_enable = false,
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "eslint_d",
        "prettier",
        "prettierd",
        "stylua",
      },
      auto_update = false,
      run_on_start = true,
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "buffer" },
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local opts = { buffer = event.buf, silent = true }
          local function bmap(lhs, rhs, desc)
            opts.desc = desc
            vim.keymap.set("n", lhs, rhs, opts)
          end
          bmap("gd", vim.lsp.buf.definition, "Go to definition")
          bmap("gr", vim.lsp.buf.references, "Find references")
          bmap("gI", vim.lsp.buf.implementation, "Go to implementation")
          bmap("gl", vim.diagnostic.open_float, "Show line diagnostics")
          bmap("K", vim.lsp.buf.hover, "Hover docs")
          bmap("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          bmap("<leader>ca", vim.lsp.buf.code_action, "Code action")
          bmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "Document symbols")
          bmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Workspace symbols")
        end,
      })

      local servers = {
        bashls = {},
        cssls = {},
        dockerls = {},
        emmet_language_server = {
          filetypes = {
            "css", "eruby", "html", "javascript", "javascriptreact",
            "less", "sass", "scss", "typescriptreact",
          },
        },
        eslint = {
          settings = {
            workingDirectories = { mode = "auto" },
          },
        },
        graphql = {},
        html = {},
        jsonls = {},
        prismals = {},
        tailwindcss = {},
        ts_ls = {},
        yamlls = {},
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
      }

      for server, config in pairs(servers) do
        config.capabilities = capabilities
        vim.lsp.config(server, config)
      end
      vim.lsp.enable(vim.tbl_keys(servers))

      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = ">" },
        severity_sort = true,
        float = { border = "rounded", source = true },
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        lua = { "stylua" },
        python = { "black", "isort" },
        go = { "gofmt" },
        sh = { "shfmt" },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        python = { "ruff" },
        sh = { "shellcheck" },
      }
    end,
  },
  {
    "stevearc/overseer.nvim",
    opts = {},
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = dapui.open
      dap.listeners.before.event_terminated["dapui_config"] = dapui.close
      dap.listeners.before.event_exited["dapui_config"] = dapui.close
    end,
  },
})

vim.cmd.colorscheme("tokyonight")

map("n", "<leader>e", function()
  save_neo_tree_width()
  require("neo-tree.command").execute({ toggle = true })
end, "Toggle file tree")
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", "Find files")
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", "Search text")
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", "Find buffers")
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", "Help")
map("n", "<leader>fn", function()
  require("telescope.builtin").find_files({ cwd = "node_modules/.bin", hidden = true })
end, "Find local node binaries")
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics")
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer diagnostics")
map("n", "<leader>tt", "<cmd>TodoTelescope<cr>", "TODOs")
map("n", "<leader>gg", "<cmd>Neotree git_status<cr>", "Git status")
map("n", "<leader>or", "<cmd>OverseerRun<cr>", "Run task")
map("n", "<leader>ot", "<cmd>OverseerToggle<cr>", "Toggle tasks")
map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, "Format file")
map("n", "[d", vim.diagnostic.goto_prev, "Previous diagnostic")
map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
map("n", "<leader>db", function()
  require("dap").toggle_breakpoint()
end, "Toggle breakpoint")
map("n", "<leader>dc", function()
  require("dap").continue()
end, "Debug continue")
map("n", "<leader>do", function()
  require("dap").step_over()
end, "Debug step over")
map("n", "<leader>di", function()
  require("dap").step_into()
end, "Debug step into")
map("n", "<leader>du", function()
  require("dapui").toggle()
end, "Debug UI")

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = save_neo_tree_width,
})

vim.api.nvim_create_autocmd("WinResized", {
  callback = save_neo_tree_width,
})
