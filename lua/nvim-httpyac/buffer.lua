local M = {}
M.buffer_number = -1

M.open_buffer = function()
    -- Get a boolean that tells us if the buffer number is visible anymore.
    -- :help bufwinnr
    local buffer_visible = vim.api.nvim_call_function("bufwinnr", { M.buffer_number }) ~= -1

    if M.buffer_number == -1 or not buffer_visible then
        -- Create a new buffer with the name "HTTPYAC_OUT".
        -- Same name will reuse the current buffer.
        vim.api.nvim_command("botright vsplit HTTPYAC_OUT")

        -- Collect the buffer's number.
        M.buffer_number = vim.api.nvim_get_current_buf()

        -- Mark the buffer as readonly.
        vim.opt_local.readonly = true
    end
end

M.log = function(data)
    if data then
        -- Append the data.
        vim.api.nvim_set_option_value("readonly", false, { buf = M.buffer_number })
        vim.api.nvim_buf_set_text(M.buffer_number, 0, 0, -1, -1, vim.split(data, "\n"))
        vim.api.nvim_set_option_value("readonly", true, { buf = M.buffer_number })
        -- Mark as not modified, otherwise you'll get an error when attempting to exit vim.
        vim.api.nvim_set_option_value("modified", false, { buf = M.buffer_number })
        vim.api.nvim_set_option_value("modified", false, { buf = M.buffer_number })
        -- set httpResult ft for syntax highlighting
        vim.api.nvim_set_option_value("filetype", "httpResult", { buf = M.buffer_number })

        -- Get the window the buffer is in and set the cursor position to the top.
        local buffer_window = vim.api.nvim_call_function("bufwinid", { M.buffer_number })
        vim.api.nvim_win_set_cursor(buffer_window, { 1, 0 })
    end
end

return M
