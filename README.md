# Graphql.nvim

Interactive Graphql client for neovim

![image](https://github.com/user-attachments/assets/7b3288a4-8bee-4e44-82de-c2dae76144eb)


> [!CAUTION]
> Currently, this plugin is under development. It may not work as expected.

## Installation

* With **lazy.nvim**
```lua
{
  "letieu/graphql.nvim",
  keys = {
    {
      "<leader>gg",
      function()
        require("graphql").open()
      end,
      desc = "graphql - Open",
    },
    {
      "<leader>gq",
      function()
        require("graphql").close()
      end,
    },
    {
      "<leader>gr",
      function()
        require("graphql").run()
      end,
    }
  },
}
```

* Lsp for autocomplete
```lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#graphql 
require'lspconfig'.graphql.setup{}
```

* Install treesitter for syntax highlight: `:TSInstall graphql`
 

## Usage

1. create new collection
2. update `.graphqlrc.json` file [docs](https://the-guild.dev/graphql/config/docs) and save
3. run the query

```lua
require('graphql').open()
require('graphql').close()
require('graphql').run()
```

## Config

**Default config**

```lua
-- TODO:
```
