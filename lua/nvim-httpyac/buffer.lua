local M = {}
M.buffer_number = -1

local function to_lines(data)
    if type(data) == "string" then return vim.split(data, "\n") end
    return data
end

local function finalise_buf()
    vim.api.nvim_set_option_value("readonly", true, { buf = M.buffer_number })
    -- Mark as not modified, otherwise you'll get an error when attempting to exit vim.
    vim.api.nvim_set_option_value("modified", false, { buf = M.buffer_number })
    vim.api.nvim_set_option_value("filetype", "httpResult", { buf = M.buffer_number })
end

M.open_buffer = function(output_view)
    -- Get a boolean that tells us if the buffer number is visible anymore.
    -- :help bufwinnr
    local buffer_visible = vim.api.nvim_call_function("bufwinnr", { M.buffer_number }) ~= -1

    if M.buffer_number == -1 or not buffer_visible then
        -- Create a new buffer with the name "HTTPYAC_OUT".
        -- Same name will reuse the current buffer.
        local cmd = "botright vsplit HTTPYAC_OUT"
        if output_view == "horizontal" then
            cmd = "botright split HTTPYAC_OUT"
        end
        vim.api.nvim_command(cmd)

        -- Collect the buffer's number.
        M.buffer_number = vim.api.nvim_get_current_buf()

        -- Mark the buffer as readonly.
        vim.opt_local.readonly = true
    end
end

M.log = function(data)
    if not data then return end
    local lines = to_lines(data)
    vim.api.nvim_set_option_value("readonly", false, { buf = M.buffer_number })
    vim.api.nvim_buf_set_text(M.buffer_number, 0, 0, -1, -1, lines)
    finalise_buf()

    -- Get the window the buffer is in and set the cursor position to the top.
    local buffer_window = vim.api.nvim_call_function("bufwinid", { M.buffer_number })
    vim.api.nvim_win_set_cursor(buffer_window, { 1, 0 })
end

-- Appends lines to the end of the output buffer (used by sequence runner for per-request output).
M.append = function(data)
    if not data or M.buffer_number == -1 or not vim.api.nvim_buf_is_valid(M.buffer_number) then
        return
    end
    local lines = to_lines(data)
    vim.api.nvim_set_option_value("readonly", false, { buf = M.buffer_number })

    local line_count = vim.api.nvim_buf_line_count(M.buffer_number)
    -- Use -2,-1 (not -1,-1) to retrieve the actual last line for column detection.
    local last_line = vim.api.nvim_buf_get_lines(M.buffer_number, -2, -1, false)
    local last_col = last_line[1] and #last_line[1] or 0
    vim.api.nvim_buf_set_text(M.buffer_number, line_count - 1, last_col, line_count - 1, last_col, lines)

    finalise_buf()
end

return M
