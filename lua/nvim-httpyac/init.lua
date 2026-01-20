local B = require("nvim-httpyac.buffer")
local M = {}

local abidibo_nvim_httpyac = vim.api.nvim_create_augroup("NVIM_HTTPYAC", { clear = true })

local function get_named_requests()
    local requests = {}
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
        local name = line:match("# *@name *(.+)")
        if name then
            table.insert(requests, { name = name, line = i })
        end
    end
    return requests
end

local function show_request_picker()
    local requests = get_named_requests()
    local request_names = {}
    for _, req in ipairs(requests) do
        table.insert(request_names, req.name)
    end

    vim.ui.select(request_names, { prompt = "Select a request:" }, function(choice)
        if not choice then
            return
        end
        for _, req in ipairs(requests) do
            if req.name == choice then
                M.exec_httpyac({ args = { "-l " .. req.line } })
                break
            end
        end
    end)
end

M.config = {
    output_view = "vertical",
}

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

    -- create a tmp copy of the file
    local tmp_file_path = vim.fn.expand("%:p:h") .. "/.tmp_httpyac_" .. os.time() .. "_" .. vim.fn.expand("%:t")
    -- save current buffer
    vim.api.nvim_command("w! " .. tmp_file_path)
    
    vim.notify("Running httpyac...", vim.log.levels.INFO)

    local stdout_data = {}

    local function on_stdout(_, data, _)
        if data then
            for _, line in ipairs(data) do
                table.insert(stdout_data, line)
            end
        end
    end

    local function on_exit(_, code, _)
        -- remove tmp file
        vim.fn.delete(tmp_file_path)

        if code == 0 then
            vim.schedule(function()
                B.open_buffer(M.config.output_view)
                B.log(stdout_data)
            end)
        else
            vim.schedule(function()
                vim.notify("HttpYac failed with code " .. code, vim.log.levels.ERROR)
            end)
        end
    end

    vim.fn.jobstart("httpyac " .. tmp_file_path .. " " .. str_args, {
        on_stdout = on_stdout,
        on_exit = on_exit,
        stdout_buffered = true,
    })
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "http",
    group = abidibo_nvim_httpyac,

    callback = function()
        vim.api.nvim_create_user_command("NvimHttpYacAll", function(opts)
            M.exec_httpyac({ args = { "-a" }, userArgs = opts.fargs })
        end, { nargs = "*" })

        vim.api.nvim_create_user_command("NvimHttpYac", function(opts)
            local curlineNumber = vim.api.nvim_win_get_cursor(0)[1]
            M.exec_httpyac({ args = { "-l " .. curlineNumber }, userArgs = opts.fargs })
        end, { nargs = "*" })

        vim.api.nvim_create_user_command("NvimHttpYacPicker", function()
            show_request_picker()
        end, { nargs = 0 })
    end,
})

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    -- Change ft to http for http extension
    vim.filetype.add({ extension = { http = "http" } })
end

return M
