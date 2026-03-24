local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Line wrapping
opt.wrap = false

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Appearance
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"
opt.cursorline = true
opt.colorcolumn = "100"

-- Behavior
opt.hidden = true
opt.errorbells = false
opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undo"

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Performance
opt.updatetime = 100
opt.timeoutlen = 300
opt.lazyredraw = false

-- Scrolling
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }

-- Clipboard
opt.clipboard = "unnamedplus"

-- Mouse
opt.mouse = "a"

-- Fill chars
opt.fillchars = { eob = " ", fold = " ", vert = "│" }

-- Disable intro message
opt.shortmess:append("sI")
