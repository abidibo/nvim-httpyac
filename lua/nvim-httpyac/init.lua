local B = require("nvim-httpyac.buffer")
local M = {}

local abidibo_nvim_httpyac = vim.api.nvim_create_augroup("NVIM_HTTPYAC", { clear = true })

-- Current sticky environment (nil means no env selected)
M.current_env = nil

--- Discover available environments by searching for env files
--- in the same directory as the current file, project root, and env/ subfolder.
local function discover_environments()
    local envs = {}
    local seen = {}

    local file_dir = vim.fn.expand("%:p:h")
    local project_root = vim.fn.getcwd()

    local search_dirs = { file_dir }
    if file_dir ~= project_root then
        table.insert(search_dirs, project_root)
    end
    local env_dir = project_root .. "/env"
    if vim.fn.isdirectory(env_dir) == 1 then
        table.insert(search_dirs, env_dir)
    end

    for _, dir in ipairs(search_dirs) do
        -- Parse http-client.env.json (IntelliJ format): top-level keys are env names
        local env_json_path = dir .. "/http-client.env.json"
        if vim.fn.filereadable(env_json_path) == 1 then
            local content = table.concat(vim.fn.readfile(env_json_path), "\n")
            local ok, decoded = pcall(vim.json.decode, content)
            if ok and type(decoded) == "table" then
                for key, _ in pairs(decoded) do
                    if not seen[key] then
                        seen[key] = true
                        table.insert(envs, key)
                    end
                end
            end
        end

        -- Parse http-client.private.env.json
        local private_env_json_path = dir .. "/http-client.private.env.json"
        if vim.fn.filereadable(private_env_json_path) == 1 then
            local content = table.concat(vim.fn.readfile(private_env_json_path), "\n")
            local ok, decoded = pcall(vim.json.decode, content)
            if ok and type(decoded) == "table" then
                for key, _ in pairs(decoded) do
                    if not seen[key] then
                        seen[key] = true
                        table.insert(envs, key)
                    end
                end
            end
        end

        -- Scan for dotenv files: .env.{name} and {name}.env
        local files = vim.fn.glob(dir .. "/.env.*", false, true)
        for _, file in ipairs(files) do
            local basename = vim.fn.fnamemodify(file, ":t")
            local name = basename:match("^%.env%.(.+)$")
            if name and name ~= "example" and not seen[name] then
                seen[name] = true
                table.insert(envs, name)
            end
        end

        files = vim.fn.glob(dir .. "/*.env", false, true)
        for _, file in ipairs(files) do
            local basename = vim.fn.fnamemodify(file, ":t")
            local name = basename:match("^(.+)%.env$")
            if name and name ~= "" and name ~= "." and not seen[name] then
                seen[name] = true
                table.insert(envs, name)
            end
        end
    end

    table.sort(envs)
    return envs
end

local function show_env_picker()
    local envs = discover_environments()

    if #envs == 0 then
        vim.notify("No environments found", vim.log.levels.WARN)
        return
    end

    -- Mark the currently active env in the list
    local display = {}
    for _, env in ipairs(envs) do
        if env == M.current_env then
            table.insert(display, env .. " (active)")
        else
            table.insert(display, env)
        end
    end

    vim.ui.select(display, { prompt = "Select environment:" }, function(choice)
        if not choice then
            return
        end
        -- Strip " (active)" suffix if present
        local env = choice:gsub(" %(active%)$", "")
        M.current_env = env
        vim.notify("Environment set to: " .. env, vim.log.levels.INFO)
    end)
end

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

    -- Append sticky environment if set and not already specified by user
    if M.current_env and not str_args:match("%-%-env%s") then
        str_args = str_args .. " --env " .. M.current_env
    end

    -- create a tmp copy of the file
    local tmp_file_path = vim.fn.expand("%:p:h") .. "/.tmp_httpyac_" .. os.time() .. "_" .. vim.fn.expand("%:t")
    -- save current buffer
    vim.api.nvim_command("w! " .. tmp_file_path)
    
    local env_info = M.current_env and (" [env: " .. M.current_env .. "]") or ""
    vim.notify("Running httpyac..." .. env_info, vim.log.levels.INFO)

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

        vim.api.nvim_create_user_command("NvimHttpYacEnv", function()
            show_env_picker()
        end, { nargs = 0 })

        vim.api.nvim_create_user_command("NvimHttpYacEnvClear", function()
            M.current_env = nil
            vim.notify("Environment cleared", vim.log.levels.INFO)
        end, { nargs = 0 })
    end,
})

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    -- Change ft to http for http extension
    vim.filetype.add({ extension = { http = "http" } })
end

return M
