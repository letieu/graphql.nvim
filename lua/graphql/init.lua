local Helper = require('graphql.helper')

local GRAPHQL_CONFIG_FILE_NAME = '.graphqlrc.json'
local DEFAULT_QUERY_FILE_NAME = 'default.gql'
local DEFAULT_GRAPHQL_CONFIG = {
  schema = 'https://rickandmortyapi.com/graphql',
  url = 'https://rickandmortyapi.com/graphql',
}
local EXAMPLE_QUERY = [[
# Write your query here
query {
  character(id: 1) {
    name
    status
    image
  }
}
  ]]

local M = {}

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
  options = {
    prefix_path = vim.fn.stdpath('data') .. '/graphql.nvim',
  },
}

State.get_collections_path = function()
  return State.options.prefix_path .. '/collections'
end

State.get_selected_collection_path = function()
  return State.get_collections_path() .. '/' .. State.selected_collection
end

M.setup = function(options)
end

M.open = function()
  if State.tab then
    vim.api.nvim_set_current_tabpage(State.tab)
    return
  end

  Helper.init_folders(State.options.prefix_path, State.get_collections_path())

  State.collections = vim.fn.readdir(State.get_collections_path())
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
  Helper.config_sidebar(State.buffers.list_collection, State.buffers.collection, State.wins.sidebar)

  State.buffers.result = vim.api.nvim_create_buf(false, true)
  State.wins.result = vim.api.nvim_open_win(State.buffers.result, false, {
    split = 'right',
  })
  Helper.config_result_buffer(State.buffers.result)

  Helper.render_list_collection(
    State.wins.sidebar,
    State.buffers.list_collection,
    State.collections,
    State.ns_id
  )

  Helper.set_list_collection_keymap(State.buffers.list_collection)
  Helper.set_collection_keymap(State.buffers.collection)

  vim.api.nvim_set_current_win(State.wins.sidebar)
  -- move cursor down to the first collection
  vim.api.nvim_command('normal! 4j')
end

M.close = function()
  local current_tab = vim.api.nvim_get_current_tabpage()

  if current_tab == State.tab then
    vim.api.nvim_command('tabclose')
    State.tab = nil
  end
end

M.select_collection = function()
  local current_bufnr = vim.api.nvim_get_current_buf()
  if current_bufnr ~= State.buffers.list_collection then
    return
  end

  local line = vim.api.nvim_get_current_line()
  if line == '' then
    return
  end

  State.selected_collection = line
  Helper.render_collection(
    State.buffers.collection,
    State.wins.sidebar,
    State.ns_id,
    State.selected_collection,
    State.get_selected_collection_path()
  )

  vim.api.nvim_command('normal! 4j')

  -- Set pwd to the collection path
  vim.api.nvim_command('cd ' .. State.get_selected_collection_path())

  -- Load the graphql config
  local graphql_config = State.get_selected_collection_path() .. '/' .. GRAPHQL_CONFIG_FILE_NAME
  if vim.fn.filereadable(graphql_config) == 1 then
    State.graphql_config = vim.fn.json_decode(vim.fn.join(vim.fn.readfile(graphql_config)))
  end

  -- Try to load the default query
  local default_query = State.get_selected_collection_path() .. '/' .. DEFAULT_QUERY_FILE_NAME
  Helper.open_file(default_query, State.wins.query)
end

M.run = function()
  if State.selected_collection == nil then
    vim.notify('Please select a collection first', 1, {})
    return
  end

  if State.tab == nil then
    vim.notify('Please open the graphql tab first', 1, {})
    return
  end

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
  Helper.format_result(State.buffers.result)
  Helper.show_elapse(elapsed, State.buffers.result, State.ns_id)
end

M.add_collection = function()
  local name = vim.fn.input('Collection name: ')
  if name == '' then
    return
  end

  local collections_path = State.get_collections_path()
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
    vim.fn.writefile(vim.fn.split(EXAMPLE_QUERY, '\n'), default_query)
  end

  table.insert(State.collections, name)
  Helper.render_list_collection(
    State.wins.sidebar,
    State.buffers.list_collection,
    State.collections,
    State.ns_id
  )

  -- move cursor down to the new collection
  vim.api.nvim_command('normal! G')
end

M.open_file = function()
  local file_name = vim.api.nvim_get_current_line()
  if file_name == '' then
    return
  end

  local collection_path = State.get_selected_collection_path()
  local file_path = collection_path .. '/' .. file_name
  Helper.open_file(file_path, State.wins.query)

  if file_name == GRAPHQL_CONFIG_FILE_NAME then
    vim.api.nvim_clear_autocmds({
      buffer = vim.api.nvim_get_current_buf(),
      event = 'BufWritePost',
    })
    -- add autocmd to reload the config
    vim.api.nvim_create_autocmd('BufWritePost', {
      buffer = vim.api.nvim_get_current_buf(),
      callback = function()
        local default_config = collection_path .. '/' .. GRAPHQL_CONFIG_FILE_NAME
        State.graphql_config = vim.fn.json_decode(vim.fn.join(vim.fn.readfile(default_config)))
        vim.api.nvim_command('LspRestart')
        vim.notify('Config reloaded', 1, {})
      end,
    })
  end
end

M.add_query_file = function()
  local collection_path = State.get_selected_collection_path()
  local query_name = vim.fn.input('Query name: ')

  if query_name == '' then
    return
  end

  local query_path = collection_path .. '/' .. query_name .. '.gql'
  if vim.fn.filereadable(query_path) == 0 then
    vim.fn.writefile({ '# Write your query here' }, query_path)
  end

  Helper.open_file(query_path, State.wins.query)
  Helper.render_collection(
    State.buffers.collection,
    State.wins.sidebar,
    State.ns_id,
    State.selected_collection,
    collection_path
  )
end

M.delete_query_file = function()
  local file_name = vim.api.nvim_get_current_line()
  if file_name == '' then
    return
  end

  if file_name == DEFAULT_QUERY_FILE_NAME then
    vim.notify('Cannot delete the default query', 1, {})
    return
  end

  if file_name == GRAPHQL_CONFIG_FILE_NAME then
    vim.notify('Cannot delete the config file', 1, {})
    return
  end

  local collection_path = State.get_selected_collection_path()
  local query_path = collection_path .. '/' .. file_name
  if vim.fn.filereadable(query_path) == 1 then
    -- show confirm dialog
    local confirm = vim.fn.confirm('Are you sure to delete this query?', '&Yes\n&No', 2)
    if confirm == 2 then
      return
    end
    vim.fn.delete(query_path)
    vim.notify('Query deleted', 1, {})

    Helper.render_collection(
      State.buffers.collection,
      State.wins.sidebar,
      State.ns_id,
      State.selected_collection,
      collection_path
    )
  end
end

M.delete_collection = function()
  local collection_name = vim.api.nvim_get_current_line()
  if collection_name == '' then
    return
  end

  local collection_path = State.get_collections_path() .. '/' .. collection_name

  -- show confirm dialog
  local confirm = vim.fn.confirm('Are you sure to delete this collection?', '&Yes\n&No', 2)
  if confirm == 2 then
    return
  end

  vim.fn.delete(collection_path, 'rf')
  vim.notify('Collection deleted', 1, {})

  State.collections = vim.fn.readdir(State.get_collections_path())
  Helper.render_list_collection(
    State.wins.sidebar,
    State.buffers.list_collection,
    State.collections,
    State.ns_id
  )
end

return M
