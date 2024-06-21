local M = {}

local abidibo_nvim_httpyac = vim.api.nvim_create_augroup(
    "NVIM_HTTPYAC",
    { clear = true }
)

M.exec_httpyac = function(opts)
    local B = require("buffer")
    if opts == nil then
        opts = {}
    end
    if opts.args == nil then
        opts.args = { "-a" }
    end

    local str_args = ""
    for _, arg in pairs(opts.args) do
        str_args = str_args .. " " .. arg
    end

    local file_path = vim.fn.expand('%:p')
    -- open split buffer
    B.open_buffer()
    -- execute a shell command
    local out = vim.fn.system("httpyac " .. file_path .. " " .. str_args)
    -- vim.api.nvim_buf_set_lines(buffer_number, 0, -1, true, {})
    B.log(out)
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "http",
    group = abidibo_nvim_httpyac,

    callback = function()
        vim.api.nvim_create_user_command('NvimHttpYacAll', function()
            M.exec_httpyac({ args = { "-a" } })
        end, {})

        vim.api.nvim_create_user_command('NvimHttpYac', function()
            local curlineNumber = vim.api.nvim_win_get_cursor(0)[1]
            M.exec_httpyac({ args = { "-l " .. curlineNumber } })
        end, {})
    end,
})

function M.setup()
    -- Change ft to http for http extension
    vim.filetype.add({ extension = { http = 'http' } })
end

return M
