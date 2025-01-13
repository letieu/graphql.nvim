local M = {}
local Helper = {}
local State = {
  ns_id = nil,
  tab = nil,
  query_buffer = nil,
  result_buffer = nil,
  options = {
    default_keymap = true,
    url = 'https://rickandmortyapi.com/graphql'
  },
}

Helper.config_query_buffer = function(buf)
  vim.api.nvim_set_option_value('filetype', 'graphql', {
    buf = buf,
  })
end

Helper.config_result_buffer = function(buf)
  vim.api.nvim_set_option_value('filetype', 'json', {
    buf = buf,
  })
end

Helper.setup_keymaps = function()
  if State.options.default_keymap then
    vim.api.nvim_buf_set_keymap(State.query_buffer, 'n', '<leader>r', ':lua require("graphql").run()<CR>', {
      noremap = true,
      silent = true,
    })

    vim.api.nvim_set_keymap('n', '<leader>q', ':lua require("graphql").close()<CR>', {
      noremap = true,
      silent = true,
    })
  end
end

Helper.show_elapse = function(elapsed)
  vim.api.nvim_buf_set_extmark(
    State.result_buffer,
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
    conform.format { async = true, lsp_fallback = true, bufnr = State.result_buffer }
  end
end

M.setup = function(options)
end

M.open = function()
  if State.tab then
    vim.api.nvim_set_current_tabpage(State.tab)
    return
  end

  State.ns_id = vim.api.nvim_create_namespace('graphql.nvim')

  vim.api.nvim_command('tabnew')
  State.tab = vim.api.nvim_get_current_tabpage()

  State.query_buffer = State.query_buffer or vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, State.query_buffer)
  Helper.config_query_buffer(State.query_buffer)

  State.result_buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(State.result_buffer, false, {
    split = 'right',
  })
  Helper.config_result_buffer(State.result_buffer)

  Helper.setup_keymaps()
end

M.close = function()
  local current_tab = vim.api.nvim_get_current_tabpage()

  if current_tab == State.tab then
    vim.api.nvim_command('tabclose')
    State.tab = nil
  end
end

M.run = function()
  local lines = vim.api.nvim_buf_get_lines(State.query_buffer, 0, -1, false)
  local query = table.concat(lines, '\n')

  local cmd = string.format('curl -sS -X POST -H "Content-Type: application/json" -d \'%s\' %s',
    vim.fn.json_encode({ query = query }),
    State.options.url
  )

  local start = vim.fn.reltime()
  local result = vim.fn.system(cmd)
  local elapsed = vim.fn.reltime(start)

  vim.api.nvim_buf_set_lines(State.result_buffer, 0, -1, false, vim.fn.split(result, '\n'))
  Helper.format_result()
  Helper.show_elapse(elapsed)
end

return M
