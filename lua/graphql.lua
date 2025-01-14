local M = {}
local Helper = {}
local State = {
  ns_id = nil,
  tab = nil,
  selected_collection = nil,
  collections = {},
  buffers = {
    list_collection = nil,
    collection = nil,
    result = nil,
  },
  wins = {
    sidebar = nil,
    query = nil,
    result = nil,
  },
  graphql_config = {},
  options = {},
}

local prefix_path = vim.fn.stdpath('data') .. '/graphql.nvim'

local GRAPHQL_CONFIG_FILE_NAME = '.graphqlrc.json'
local DEFAULT_QUERY_FILE_NAME = 'default.gql'
local DEFAULT_GRAPHQL_CONFIG = {
  schema = 'https://rickandmortyapi.com/graphql',
  url = 'https://rickandmortyapi.com/graphql',
}

Helper.config_result_buffer = function(buf)
  vim.api.nvim_set_option_value('filetype', 'json', {
    buf = buf,
  })
end

Helper.config_sidebar_buffer = function(buf)
  vim.api.nvim_set_option_value('buftype', 'nofile', {
    buf = buf,
  })
  vim.api.nvim_set_option_value('number', false, {
    win = State.wins.sidebar,
  })
  vim.api.nvim_set_option_value('modifiable', false, {
    buf = buf,
  })

  vim.api.nvim_set_option_value('modifiable', false, {
    buf = State.buffers.collection,
  })
  vim.api.nvim_set_option_value('relativenumber', false, {
    win = State.wins.sidebar,
  })
end

Helper.render_list_collection = function()
  vim.api.nvim_set_option_value('modifiable', true, {
    buf = State.buffers.list_collection,
  })

  vim.api.nvim_buf_set_lines(State.buffers.list_collection, 0, -1, false, {})

  local collections = { '', '' }
  for _, collection in ipairs(State.collections) do
    table.insert(collections, collection)
  end

  vim.api.nvim_buf_set_lines(State.buffers.list_collection, 0, -1, false, collections)
  vim.api.nvim_buf_set_extmark(
    State.buffers.list_collection,
    State.ns_id,
    0,
    0,
    {
      virt_text = {
        {
          'Select a collections',
          'Comment',
        },
      },
    }
  )
  vim.api.nvim_buf_set_extmark(
    State.buffers.list_collection,
    State.ns_id,
    1,
    0,
    {
      virt_text = {
        { 'Press a to add new', 'Comment' },
      },
    }
  )

  vim.api.nvim_win_set_buf(State.wins.sidebar, State.buffers.list_collection)

  vim.api.nvim_set_option_value('modifiable', false, {
    buf = State.buffers.list_collection,
  })
end

Helper.render_collection = function()
  vim.api.nvim_set_option_value('modifiable', true, {
    buf = State.buffers.collection,
  })
  vim.api.nvim_buf_set_lines(State.buffers.collection, 0, -1, false, {})

  local collections_path = prefix_path .. '/collections'
  local collection_path = collections_path .. '/' .. State.selected_collection
  local files = vim.fn.readdir(collection_path)

  local items = { '', '' }
  for _, file in ipairs(files) do
    table.insert(items, file)
  end

  vim.api.nvim_buf_set_lines(State.buffers.collection, 0, -1, false, items)

  vim.api.nvim_win_set_buf(State.wins.sidebar, State.buffers.collection)

  vim.api.nvim_buf_set_extmark(
    State.buffers.collection,
    State.ns_id,
    0,
    0,
    {
      virt_text = {
        { State.selected_collection, 'Comment' },
      },
    }
  )

  vim.api.nvim_set_option_value('modifiable', false, {
    buf = State.buffers.collection,
  })
end

Helper.setup_keymaps = function()
  vim.api.nvim_set_keymap('n', '<leader>q', ':lua require("graphql").close()<CR>', {
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(State.buffers.list_collection, 'n', '<CR>',
    ':lua require("graphql").select_collection()<CR>', {
      noremap = true,
      silent = true,
    })

  vim.api.nvim_buf_set_keymap(State.buffers.list_collection, 'n', 'a', ':lua require("graphql").add_collection()<CR>', {
    noremap = true,
    silent = true,
  })

  vim.api.nvim_set_keymap('n', '<leader>r', ':lua require("graphql").run()<CR>', {
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(State.buffers.collection, 'n', '<CR>',
    ':lua require("graphql").open_file()<CR>', {
      noremap = true,
      silent = true,
    })

  vim.api.nvim_buf_set_keymap(State.buffers.collection, 'n', 'a',
    ':lua require("graphql").add_query_file()<CR>', {
      noremap = true,
      silent = true,
    })

  vim.api.nvim_buf_set_keymap(State.buffers.collection, 'n', 'd',
    ':lua require("graphql").delete_query_file()<CR>', {
      noremap = true,
      silent = true,
    })

  vim.api.nvim_buf_set_keymap(State.buffers.list_collection, 'n', 'd',
    ':lua require("graphql").delete_collection()<CR>', {
      noremap = true,
      silent = true,
    })
end

Helper.open_file = function(path)
  if vim.fn.filereadable(path) == 1 then
    vim.api.nvim_win_call(State.wins.query, function()
      vim.api.nvim_command('e ' .. path)
    end)
    vim.api.nvim_set_current_win(State.wins.query)
  end
end

Helper.show_elapse = function(elapsed)
  vim.api.nvim_buf_set_extmark(
    State.buffers.result,
    State.ns_id,
    0,
    0,
    {
      virt_text = {
        { string.format('Elapsed: %d.%d seconds  ', elapsed[1], elapsed[2] / 1000), 'Comment' },
      },
      virt_text_pos = 'right_align',
    }
  )
end

Helper.format_result = function()
  local status, conform = pcall(require, 'conform')
  if not status then
    vim.api.nvim_notify('conform is not installed', 1, {})
  else
    conform.format { async = true, lsp_fallback = true, bufnr = State.buffers.result }
  end
end

M.setup = function(options)
end

M.open = function()
  if State.tab then
    vim.api.nvim_set_current_tabpage(State.tab)
    return
  end

  -- check if prefix_path exists, if not, create it
  if vim.fn.isdirectory(prefix_path) == 0 then
    vim.fn.mkdir(prefix_path, 'p')
  end


  -- load list of collections base on list folder
  local collections_path = prefix_path .. '/collections'
  if vim.fn.isdirectory(collections_path) == 0 then
    vim.fn.mkdir(collections_path, 'p')
  end
  local collections = vim.fn.readdir(collections_path)
  State.collections = collections

  State.ns_id = vim.api.nvim_create_namespace('graphql.nvim')

  vim.api.nvim_command('tabnew')
  State.tab = vim.api.nvim_get_current_tabpage()

  State.wins.query = vim.api.nvim_get_current_win()

  State.buffers.list_collection = State.buffers.list_collection or vim.api.nvim_create_buf(false, true)
  State.buffers.collection = State.buffers.collection or vim.api.nvim_create_buf(false, true)
  State.wins.sidebar = vim.api.nvim_open_win(State.buffers.list_collection, false, {
    split = 'left',
    width = 35,
  })
  Helper.config_sidebar_buffer(State.buffers.list_collection)

  State.buffers.result = vim.api.nvim_create_buf(false, true)
  State.wins.result = vim.api.nvim_open_win(State.buffers.result, false, {
    split = 'right',
  })
  Helper.config_result_buffer(State.buffers.result)

  Helper.render_list_collection()

  Helper.setup_keymaps()

  vim.api.nvim_set_current_win(State.wins.sidebar)
  -- move cursor down to the first collection
  vim.api.nvim_command('normal! 2j')
end

M.close = function()
  local current_tab = vim.api.nvim_get_current_tabpage()

  if current_tab == State.tab then
    vim.api.nvim_command('tabclose')
    State.tab = nil
  end
end

M.select_collection = function(name)
  if (not name) then
    local line = vim.api.nvim_get_current_line()
    if line == '' then
      return
    end

    M.select_collection(line)
    return
  end

  State.selected_collection = name
  Helper.render_collection()

  -- Set pwd to the collection path
  local collections_path = prefix_path .. '/collections'
  local collection_path = collections_path .. '/' .. State.selected_collection
  vim.api.nvim_command('cd ' .. collection_path)

  -- Try to load the default query
  local default_query = collection_path .. '/' .. DEFAULT_QUERY_FILE_NAME
  Helper.open_file(default_query)

  -- Set the url
  local default_config = collection_path .. '/' .. GRAPHQL_CONFIG_FILE_NAME
  if vim.fn.filereadable(default_config) == 1 then
    State.graphql_config = vim.fn.json_decode(vim.fn.join(vim.fn.readfile(default_config)))
  end
end

M.run = function()
  -- clear the result buffer
  vim.api.nvim_buf_set_lines(State.buffers.result, 0, -1, false, {})

  if State.graphql_config.url == nil then
    vim.notify('URL is not set, please set the `url` in' .. GRAPHQL_CONFIG_FILE_NAME, 1, {})
    return
  end

  local query_bufnr = vim.api.nvim_win_get_buf(State.wins.query)

  local lines = vim.api.nvim_buf_get_lines(query_bufnr, 0, -1, false)
  local query = table.concat(lines, '\n')

  local cmd = string.format('curl -sS -X POST -H "Content-Type: application/json" -d \'%s\' %s',
    vim.fn.json_encode({ query = query }),
    State.graphql_config.url
  )

  local start = vim.fn.reltime()
  local result = vim.fn.system(cmd)
  local elapsed = vim.fn.reltime(start)

  vim.api.nvim_buf_set_lines(State.buffers.result, 0, -1, false, vim.fn.split(result, '\n'))
  Helper.format_result()
  Helper.show_elapse(elapsed)
end

M.add_collection = function()
  local name = vim.fn.input('Collection name: ')
  if name == '' then
    return
  end

  local collections_path = prefix_path .. '/collections'
  local collection_path = collections_path .. '/' .. name
  if vim.fn.isdirectory(collection_path) == 0 then
    vim.fn.mkdir(collection_path, 'p')
  end

  -- init the default config file and default query file
  local default_config = collection_path .. '/' .. GRAPHQL_CONFIG_FILE_NAME
  if vim.fn.filereadable(default_config) == 0 then
    vim.fn.writefile({ vim.fn.json_encode(DEFAULT_GRAPHQL_CONFIG) }, default_config)
  end
  local default_query = collection_path .. '/' .. DEFAULT_QUERY_FILE_NAME
  if vim.fn.filereadable(default_query) == 0 then
    vim.fn.writefile({ '# Write your query here' }, default_query)
  end

  table.insert(State.collections, name)
  Helper.render_list_collection()
end

M.open_file = function()
  local line = vim.api.nvim_get_current_line()
  if line == '' then
    return
  end

  local collection_path = prefix_path .. '/collections/' .. State.selected_collection
  local file_path = collection_path .. '/' .. line
  Helper.open_file(file_path)

  if line == GRAPHQL_CONFIG_FILE_NAME then
    vim.api.nvim_clear_autocmds({
      buffer = vim.api.nvim_get_current_buf(),
      event = 'BufWritePost',
    })
    -- add autocmd to reload the config
    vim.api.nvim_create_autocmd('BufWritePost', {
      buffer = vim.api.nvim_get_current_buf(),
      callback = function()
        local default_config = prefix_path ..
            '/collections/' .. State.selected_collection .. '/' .. GRAPHQL_CONFIG_FILE_NAME
        State.graphql_config = vim.fn.json_decode(vim.fn.join(vim.fn.readfile(default_config)))
        vim.notify('Config reloaded', 1, {})

        -- reload the lspconfig
        vim.api.nvim_command('LspRestart')
      end,
    })
  end
end

M.add_query_file = function()
  local collection_path = prefix_path .. '/collections/' .. State.selected_collection
  local query_name = vim.fn.input('Query name: ')

  if query_name == '' then
    return
  end

  local query_path = collection_path .. '/' .. query_name .. '.gql'
  if vim.fn.filereadable(query_path) == 0 then
    vim.fn.writefile({ '# Write your query here' }, query_path)
  end

  Helper.open_file(query_path)
  Helper.render_collection()
end

M.delete_query_file = function()
  local line = vim.api.nvim_get_current_line()
  if line == '' then
    return
  end

  local collection_path = prefix_path .. '/collections/' .. State.selected_collection
  local query_path = collection_path .. '/' .. line
  if vim.fn.filereadable(query_path) == 1 then
    -- show confirm dialog
    local confirm = vim.fn.confirm('Are you sure to delete this query?', '&Yes\n&No', 2)
    if confirm == 2 then
      return
    end
    vim.fn.delete(query_path)
    vim.notify('Query deleted', 1, {})
    Helper.render_collection()
  end
end

M.delete_collection = function()
  local line = vim.api.nvim_get_current_line()
  if line == '' then
    return
  end

  local collection_path = prefix_path .. '/collections/' .. line
  if vim.fn.isdirectory(collection_path) == 1 then
    vim.fn.delete(collection_path)
  end
end

return M
