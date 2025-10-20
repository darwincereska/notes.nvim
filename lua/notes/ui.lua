local M = {}

local config = require('notes.config')

function M.create_float(opts)
    opts = opts or {}
    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)
    
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    local buf = vim.api.nvim_create_buf(false, true)
    
    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = config.options.ui.border,
        title = opts.title,
        title_pos = opts.title_pos or 'center'
    }
    
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    
    vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')
    
    return buf, win
end

function M.input(opts, on_confirm)
    opts = opts or {}
    local prompt = opts.prompt or 'Input: '
    local default = opts.default or ''
    
    local width = opts.width or 60
    local height = 3
    
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    local buf = vim.api.nvim_create_buf(false, true)
    
    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = config.options.ui.border,
        title = ' ' .. prompt .. ' ',
        title_pos = 'left'
    }
    
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    
    vim.api.nvim_buf_set_option(buf, 'buftype', 'prompt')
    vim.fn.prompt_setprompt(buf, '> ')
    
    if default ~= '' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })
    end
    
    local function close_and_confirm()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local input = lines[1] and lines[1]:sub(3) or ''
        vim.api.nvim_win_close(win, true)
        if on_confirm then
            on_confirm(input)
        end
    end
    
    local function close_and_cancel()
        vim.api.nvim_win_close(win, true)
        if on_confirm then
            on_confirm(nil)
        end
    end
    
    vim.keymap.set('i', '<CR>', close_and_confirm, { buffer = buf })
    vim.keymap.set('i', '<Esc>', close_and_cancel, { buffer = buf })
    vim.keymap.set('n', '<CR>', close_and_confirm, { buffer = buf })
    vim.keymap.set('n', '<Esc>', close_and_cancel, { buffer = buf })
    vim.keymap.set('n', 'q', close_and_cancel, { buffer = buf })
    
    vim.cmd('startinsert!')
end

function M.select(items, opts, on_select)
    opts = opts or {}
    local prompt = opts.prompt or 'Select: '
    local format_item = opts.format_item or tostring
    
    local width = opts.width or math.floor(vim.o.columns * 0.6)
    local height = math.min(#items + 2, math.floor(vim.o.lines * 0.6))
    
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    local buf = vim.api.nvim_create_buf(false, true)
    
    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = config.options.ui.border,
        title = ' ' .. prompt .. ' ',
        title_pos = 'center'
    }
    
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    
    local lines = {}
    for i, item in ipairs(items) do
        lines[i] = format_item(item)
    end
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'cursorline', true)
    
    local function make_selection()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local idx = cursor[1]
        vim.api.nvim_win_close(win, true)
        if on_select and items[idx] then
            on_select(items[idx])
        end
    end
    
    local function close()
        vim.api.nvim_win_close(win, true)
        if on_select then
            on_select(nil)
        end
    end
    
    vim.keymap.set('n', '<CR>', make_selection, { buffer = buf })
    vim.keymap.set('n', '<Esc>', close, { buffer = buf })
    vim.keymap.set('n', 'q', close, { buffer = buf })
end

function M.confirm(opts, on_confirm)
    opts = opts or {}
    local prompt = opts.prompt or 'Confirm?'
    local choices = opts.choices or { 'Yes', 'No' }
    
    M.select(choices, {
        prompt = prompt,
        width = 40,
        format_item = function(item) return '  ' .. item end
    }, function(choice)
        if on_confirm then
            on_confirm(choice)
        end
    end)
end

function M.notify(msg, level)
    level = level or vim.log.levels.INFO
    
    if config.options.ui.use_native_notify then
        vim.notify(msg, level)
        return
    end
    
    local width = math.min(#msg + 4, math.floor(vim.o.columns * 0.5))
    local height = 3
    
    local row = 2
    local col = vim.o.columns - width - 2
    
    local buf = vim.api.nvim_create_buf(false, true)
    
    local level_icon = {
        [vim.log.levels.ERROR] = ' ',
        [vim.log.levels.WARN] = ' ',
        [vim.log.levels.INFO] = ' ',
    }
    
    local icon = level_icon[level] or ' '
    local display_msg = icon .. ' ' .. msg
    
    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = config.options.ui.border,
        focusable = false
    }
    
    local win = vim.api.nvim_open_win(buf, false, win_opts)
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', '  ' .. display_msg, '' })
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    local hl = level == vim.log.levels.ERROR and 'ErrorMsg' or
               level == vim.log.levels.WARN and 'WarningMsg' or 'None'
    
    vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:' .. hl)
    
    vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, 3000)
end

return M
