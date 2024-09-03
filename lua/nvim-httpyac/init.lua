local B = require("nvim-httpyac.buffer")
local M = {}

local abidibo_nvim_httpyac = vim.api.nvim_create_augroup(
    "NVIM_HTTPYAC",
    { clear = true }
)

M.exec_httpyac = function(opts)
    if opts == nil then
        opts = {}
    end
    if opts.args == nil then
        opts.args = { "-a" }
    end

    if opts.userArgs == nil then
        opts.userArgs = {}
    end

    local str_args = ""
    for _, arg in pairs(opts.args) do
        str_args = str_args .. " " .. arg
    end

    for _, arg in pairs(opts.userArgs) do
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
        vim.api.nvim_create_user_command('NvimHttpYacAll', function(opts)
            M.exec_httpyac({ args = { "-a" }, userArgs = opts.fargs })
        end, { nargs = "*" })

        vim.api.nvim_create_user_command('NvimHttpYac', function(opts)
            local curlineNumber = vim.api.nvim_win_get_cursor(0)[1]
            M.exec_httpyac({ args = { "-l " .. curlineNumber }, userArgs = opts.fargs })
        end, { nargs = "*" })
    end,
})

function M.setup()
    -- Change ft to http for http extension
    vim.filetype.add({ extension = { http = 'http' } })
end

return M
