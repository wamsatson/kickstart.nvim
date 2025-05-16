
return {
  "Mofiqul/dracula.nvim",
  lazy = false, -- Load it on startup
  priority = 1000, -- Ensure it's loaded before other plugins
  config = function()
    vim.cmd("colorscheme dracula-soft")
  end,
}

