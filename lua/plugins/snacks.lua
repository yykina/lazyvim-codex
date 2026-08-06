return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>e",
        function()
          local name = vim.api.nvim_buf_get_name(0)
          local dir = name ~= "" and vim.fn.fnamemodify(name, ":h") or vim.uv.cwd()
          Snacks.explorer({ cwd = dir })
        end,
        desc = "Explorer Snacks (current file dir)",
      },
    },
    opts = {
      dashboard = {
        preset = {
          header = [[
                ⢀⡤⠤⠤⣄
           ⢀⣠⠴⠖⠚⠉⣠⣶⣆⠘⣆
         ⢀⡴⠋⣠⣴⣶⣿⣿⣿⣿⣿⣧⣈⠑⢦⡀
       ⣠⠴⠋⢠⣾⣿⣿⣿⠿⣟⢻⣿⢿⣿⣿⣷⣄⠙⣄
   ⣀⣀⣠⠞⢁⣴⣶⣾⢟⣿⢻⣿⣿⣿⣯⣿⣷⣭⡻⣿⣿⣆⠘⡆
⢠⠞⢉⣉⣁⣤⣴⣿⣿⣿⣳⣿⣿⢿⣿⣿⣻⣿⣿⣿⣿⣿⡞⠿⠟ ⠓⠲⠤⣀
⢻⡀⢻⣿⣿⣿⣿⣿⣿⡇⣿⣿⣿⢸⣿⣿⡟⣽⣿⣿⡿⣟⣿⡇⣿⣿⣿⣷⣆⠘⣆
⠈⣧⠘⣿⣿⣿⣿⣿⣿⡟⣿⣿⣿⣯⣛⠿⠱⢟⣯⣵⣾⣿⣿⢱⣿⣿⣿⣿⣿⣦⠘⣆
 ⠘⣆⠘⢿⣿⣿⣿⣿⡇⠿⣿⣿⣿⣿⣿⢾⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⠟⢋⣠⠏
  ⠈⠳⣄⠉⢛⣛⣯⣾⣿⣯⡻⣿⣿⠏⣾⣿⣿⣿⣿⢟⣵⣿⣻⠿⠿⠋⣰⠏⠁
    ⣸⡄⠻⣿⣿⣿⣿⣿⣿⣷⣾⣷⢩⣽⣿⣭⣷⣿⣿⣿⣿⣷⢀⡞⠁
 ⢀⡴⠋⣁⣤⣶⣮⡹⣿⣿⣿⣿⣿⣿⡿⣸⣿⣿⠿⢿⣿⣿⣿⣿⠏⢸⠇
⢰⠏⢠⣾⣿⣿⣿⣿⠇⣿⣿⣿⣿⡿⢛⣵⣿⠉⣾⣿⣿⣾⣭⣥⡀⢰⡏
⠘⠦⣤⣤⣭⣭⣥⣤⣤⣤⣤⣤⡀⢸⣿⡿⠟⢀⠘⠿⣿⣿⣿⣿⣿⠆⢹
            ⢿⡀⠋⣠⠞⠋⠙⠦⣤⣉⣉⣉⣤⠴⠋
             ⠉⠉⠁
]],
        },
      },
      picker = {
        sources = {
          explorer = {
            config = function(opts)
              opts = require("snacks.picker.source.explorer").setup(opts)
              local confirm = require("snacks.explorer.actions").actions.confirm

              opts.actions.confirm = function(picker, item, action)
                confirm(picker, item, action)
                vim.schedule(function()
                  if not picker.closed then
                    pcall(function()
                      picker:focus("list", { show = true })
                    end)
                  end
                end)
              end

              return opts
            end,
            layout = {
              preset = "sidebar",
              preview = false,
              layout = {
                width = function()
                  return require("config.window_sizes").explorer_width()
                end,
                min_width = 20,
              },
            },
          },
        },
      },
      styles = {
        terminal = {
          height = function()
            return require("config.window_sizes").terminal_height()
          end,
          min_height = 3,
          wo = {
            winbar = "%{exists('b:snacks_terminal') ? b:snacks_terminal.id : ''}",
          },
        },
      },
    },
  },
}
