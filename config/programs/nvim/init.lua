-- ─────────────────────────────────────────────────────────────────────────────
-- Neovim Configuration — CachyOS (Arch-based)
-- Uses lazy.nvim for plugin management.
-- All plugin logic is identical to the original NixOS configuration.
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────
-- Bootstrap lazy.nvim
-- ─────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    lazyrepo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to continue..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- ─────────────────────────────
-- Options (set before plugins load)
-- ─────────────────────────────

-- FIX: Auto-create undo directory to prevent E828 error
local undodir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end
vim.opt.undodir = undodir
vim.opt.undofile = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.breakindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ─────────────────────────────
-- DYNAMIC THEME LOGIC
-- ─────────────────────────────
_G.reload_matugen_colors = function()
  -- Point directly to the neovim config directory
  local matugen_path = vim.fn.stdpath("config") .. "/matugen_colors.lua"
  local overrides = {}

  if vim.fn.filereadable(matugen_path) == 1 then
    -- dofile evaluates the file fresh every time, bypassing require's caching
    local ok, colors = pcall(dofile, matugen_path)
    if ok and type(colors) == "table" then
      overrides = { all = colors }
    end
  end

  require("catppuccin").setup({
    flavour = "mocha",
    color_overrides = overrides,
    integrations = {
      cmp = true,
      gitsigns = true,
      nvimtree = true,
      treesitter = true,
      bufferline = true,
      telescope = { enabled = true },
      indent_blankline = { enabled = true },
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
    },
  })
  vim.cmd.colorscheme("catppuccin")
end

-- ─────────────────────────────
-- Plugin Specs (lazy.nvim)
-- ─────────────────────────────
require("lazy").setup({

  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin-nvim",
    lazy = false,
    priority = 1000,
    config = function()
      _G.reload_matugen_colors()
    end,
  },

  -- Icons (dependency for many plugins)
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require('nvim-treesitter.configs').setup {
        -- Install parsers automatically when needed
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      }
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require('lualine').setup { options = { theme = 'catppuccin' } }
    end,
  },

  -- Bufferline (tab bar)
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup {
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          offsets = {
            {
              filetype = "NvimTree",
              text = "File Explorer",
              text_align = "left",
              separator = true,
            },
          },
        },
      }
      vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
      vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
      vim.keymap.set("n", "<leader>x", ":bdelete<CR>", { silent = true, desc = "Close Buffer" })
    end,
  },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup()
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require('gitsigns').setup()
    end,
  },

  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require('which-key').setup()
    end,
  },

  -- File tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        filters = { dotfiles = false },
        view = { width = 30 },
      })
      vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>', { desc = 'Toggle File Explorer' })
    end,
  },

  -- Telescope fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
      local telescope = require('telescope')
      telescope.setup {
        extensions = {
          ["ui-select"] = { require("telescope.themes").get_dropdown {} },
        },
      }
      pcall(telescope.load_extension, 'ui-select')

      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find Files' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live Grep' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find Buffers' })
    end,
  },

  -- telescope-ui-select (loaded as part of telescope deps above)
  { "nvim-telescope/telescope-ui-select.nvim", lazy = true },

  -- Autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require('nvim-autopairs').setup({})
    end,
  },

  -- Comments
  {
    "numToStr/Comment.nvim",
    config = function()
      require('Comment').setup()
    end,
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      local function setup_server(server_name, config)
        local ok, server_config = pcall(require, "lspconfig.server_configurations." .. server_name)
        if not ok then return end

        local default_config = server_config.default_config
        local final_config = vim.tbl_deep_extend("force", default_config, config or {})
        final_config.capabilities = vim.tbl_deep_extend("force", final_config.capabilities or {}, capabilities)

        vim.api.nvim_create_autocmd("FileType", {
          pattern = final_config.filetypes,
          callback = function(args)
            local root_dir = final_config.root_dir
            if type(root_dir) == 'function' then
              root_dir = root_dir(args.file)
            end
            if not root_dir then
              root_dir = vim.fs.dirname(args.file)
            end
            final_config.root_dir = root_dir
            vim.lsp.start(final_config)
          end,
        })
      end

      setup_server("pyright", {})
      -- nil_ls replaced by nixd or nil_ls from AUR; skip if not installed
      pcall(setup_server, "nil_ls", {})
      setup_server("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            globals = { 'vim' },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })
    end,
  },

  -- Completion engine + sources
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert {
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-d>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          },
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        },
      }
    end,
  },

  -- Snippet engine (dependency of nvim-cmp, declared separately for lazy)
  { "L3MON4D3/LuaSnip",            lazy = true },
  { "saadparwaiz1/cmp_luasnip",    lazy = true },
  { "rafamadriz/friendly-snippets", lazy = true },

}, {
  -- lazy.nvim options
  install = {
    colorscheme = { "catppuccin" },
  },
  ui = {
    icons = {
      cmd     = "",
      config  = "",
      event   = "",
      ft      = "",
      init    = "",
      keys    = "",
      plugin  = "",
      runtime = "",
      require = "",
      source  = "",
      start   = "",
      task    = "",
      lazy    = "󰒲 ",
    },
  },
})
