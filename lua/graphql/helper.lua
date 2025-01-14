local Helper = {}

Helper.config_result_buffer = function(buf)
  vim.api.nvim_set_option_value('filetype', 'json', {
    buf = buf,
  })
end

Helper.config_sidebar = function(list_collection_buf, collection_buf, sidebar_win)
  vim.api.nvim_set_option_value('modifiable', false, {
    buf = list_collection_buf,
  })
  vim.api.nvim_set_option_value('modifiable', false, {
    buf = collection_buf,
  })

  vim.api.nvim_set_option_value('number', false, {
    win = sidebar_win,
  })
  vim.api.nvim_set_option_value('relativenumber', false, {
    win = sidebar_win,
  })
end

Helper.render_list_collection = function(win, buf, collections, ns_id)
  vim.api.nvim_set_option_value('modifiable', true, {
    buf = buf,
  })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  local items = { '', '', '', '' }
  for _, collection in ipairs(collections) do
    table.insert(items, collection)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, items)
  Helper.render_list_collection_help(buf, ns_id)

  vim.api.nvim_win_set_buf(win, buf)

  vim.api.nvim_set_option_value('modifiable', false, {
    buf = buf,
  })
end

Helper.render_collection = function(buf, win, ns_id, collection_name, collection_path)
  vim.api.nvim_set_option_value('modifiable', true, {
    buf = buf,
  })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  local files = vim.fn.readdir(collection_path)

  local items = { '', '', '', '' }
  for _, file in ipairs(files) do
    table.insert(items, file)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, items)

  Helper.render_collection_help(collection_name, buf, ns_id)

  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_option_value('modifiable', false, {
    buf = buf,
  })
end

Helper.render_list_collection_help = function(buf, ns_id)
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    0,
    0,
    {
      virt_text = {
        { 'Collections', 'Label' },
      },
    }
  )

  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    1,
    0,
    {
      virt_text = {
        { '"<CR>" to select', 'Comment' },
      },
    }
  )
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    2,
    0,
    {
      virt_text = {
        { '"a" add new', 'Comment' },
      },
    }
  )
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    3,
    0,
    {
      virt_text = {
        { '"d" delete', 'Comment' },
      },
    }
  )
end

Helper.render_collection_help = function(collection_name, buf, ns_id)
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    0,
    0,
    {
      virt_text = {
        { collection_name, 'Label' },
      },
    }
  )

  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    1,
    0,
    {
      virt_text = {
        { '"<C-o>" back to list', 'Comment' },
      },
    }
  )
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    2,
    0,
    {
      virt_text = {
        { '"a" add new', 'Comment' },
      },
    }
  )
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    3,
    0,
    {
      virt_text = {
        { '"d" delete', 'Comment' },
      },
    }
  )
end

Helper.open_file = function(path, win)
  if vim.fn.filereadable(path) == 1 then
    vim.api.nvim_win_call(win, function()
      vim.api.nvim_command('e ' .. path)
    end)
    vim.api.nvim_set_current_win(win)
  end
end

Helper.show_elapse = function(elapsed, buf, ns_id)
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
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

Helper.render_query_help = function(buf, ns_id)
  vim.api.nvim_buf_set_extmark(
    buf,
    ns_id,
    0,
    0,
    {
      virt_text = {
        { '"<leader>r" to run', 'Comment' },
      },
    }
  )
end

Helper.format_result = function(buf)
  local status, conform = pcall(require, 'conform')
  if not status then
    vim.api.nvim_notify('conform is not installed', 1, {})
  else
    conform.format { async = true, lsp_fallback = true, bufnr = buf }
  end
end

Helper.init_folders = function(prefix_path, collections_path)
  if vim.fn.isdirectory(prefix_path) == 0 then
    vim.fn.mkdir(prefix_path, 'p')
  end

  if vim.fn.isdirectory(collections_path) == 0 then
    vim.fn.mkdir(collections_path, 'p')
  end
end

Helper.set_list_collection_keymap = function(buf)
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua require("graphql").select_collection()<CR>', {
    noremap = true,
    silent = true,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'a', ':lua require("graphql").add_collection()<CR>', {
    noremap = true,
    silent = true,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'd', ':lua require("graphql").delete_collection()<CR>', {
    noremap = true,
    silent = true,
  })
end

Helper.set_collection_keymap = function(buf)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'a', ':lua require("graphql").add_query_file()<CR>', {
    noremap = true,
    silent = true,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'd', ':lua require("graphql").delete_query_file()<CR>', {
    noremap = true,
    silent = true,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua require("graphql").open_file()<CR>', {
    noremap = true,
    silent = true,
  })
end

Helper.set_query_keymap = function(buf)
  vim.api.nvim_buf_set_keymap(buf, 'n', '<leader>r', ':lua require("graphql").run()<CR>', {
    noremap = true,
    silent = true,
  })
end

return Helper
