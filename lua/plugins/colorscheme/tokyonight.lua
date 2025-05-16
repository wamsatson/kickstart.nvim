return {
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-storm'
    end
  },
  {
    'Mofiqul/dracula.nvim',
    priority = 1001, -- Make sure to load this before all the other start plugins.
    config = function()
      -- vim.cmd.colorscheme 'tokyonight-storm'
    end
  }
