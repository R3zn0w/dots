return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file = true,
          hijack_netrw_behavior = "open_default",
        },
      })

      -- Toggle file explorer with <leader>e
      vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>')
    end,
  },
}

