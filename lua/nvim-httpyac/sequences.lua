local B = require("nvim-httpyac.buffer")
local M = {}

local NAME_PREFIX = "# *@name *"

M.is_recording = false
M.recorded_requests = {} -- list of { file = string, request_name = string }

-- Monotonic counter avoids os.time() 1-second granularity collisions in tmp names.
local _tmp_counter = 0

local function get_sequences_path()
    return vim.fn.getcwd() .. "/.httpyac-sequences.json"
end

-- Returns parsed sequences table, or { sequences = {} } on missing/invalid file.
function M.load_sequences()
    local path = get_sequences_path()
    if vim.fn.filereadable(path) == 0 then
        return { sequences = {} }
    end
    local content = table.concat(vim.fn.readfile(path), "\n")
    local ok, decoded = pcall(vim.json.decode, content)
    if not ok or type(decoded) ~= "table" then
        return { sequences = {} }
    end
    return decoded
end

-- Writes the full data table to disk as JSON.
function M.save_sequences(data)
    local path = get_sequences_path()
    local ok = vim.fn.writefile({ vim.json.encode(data) }, path)
    if ok ~= 0 then
        vim.notify("HttpYac: failed to save sequences to " .. path, vim.log.levels.ERROR)
    end
end

-- Appends a named request entry when recording is active. Warns and skips unnamed requests.
function M.capture(file, request_name)
    if not M.is_recording then
        return
    end
    if not file then
        return
    end
    if not request_name then
        vim.notify(
            "HttpYac: unnamed request skipped — add '# @name <name>' above the request to include it in a sequence",
            vim.log.levels.WARN
        )
        return
    end
    table.insert(M.recorded_requests, { file = file, request_name = request_name })
end

-- Runs all requests in seq one by one, appending each result to the output buffer.
function M.run_sequence(seq, config, current_env)
    local requests = seq.requests
    if not requests or #requests == 0 then
        vim.notify("HttpYac: sequence '" .. seq.name .. "' has no requests", vim.log.levels.WARN)
        return
    end

    vim.notify("HttpYac: running sequence '" .. seq.name .. "' (" .. #requests .. " requests)...", vim.log.levels.INFO)
    B.open_buffer(config.output_view)

    local index = 0

    local function run_next()
        index = index + 1
        if index > #requests then
            vim.notify("HttpYac: sequence '" .. seq.name .. "' completed", vim.log.levels.INFO)
            return
        end

        local entry = requests[index]

        if not entry or not entry.file or not entry.request_name then
            vim.notify("HttpYac: sequence entry #" .. index .. " is malformed", vim.log.levels.ERROR)
            return
        end

        if vim.fn.filereadable(entry.file) == 0 then
            vim.notify(
                "HttpYac: sequence aborted — file not readable: " .. entry.file,
                vim.log.levels.ERROR
            )
            return
        end

        local file_lines = vim.fn.readfile(entry.file)

        -- Resolve current line by scanning for # @name <request_name>
        local line = nil
        for i, file_line in ipairs(file_lines) do
            if file_line:match(NAME_PREFIX .. vim.pesc(entry.request_name) .. "%s*$") then
                line = i
                break
            end
        end

        if not line then
            vim.notify(
                "HttpYac: sequence aborted — request '" .. entry.request_name .. "' not found in " .. entry.file,
                vim.log.levels.ERROR
            )
            return
        end

        _tmp_counter = _tmp_counter + 1
        local tmp = vim.fn.fnamemodify(entry.file, ":h")
            .. "/.tmp_httpyac_" .. _tmp_counter .. "_" .. vim.fn.fnamemodify(entry.file, ":t")
        vim.fn.writefile(file_lines, tmp)

        -- Use table form to avoid shell injection from paths or env values.
        local cmd = { "httpyac", tmp, "-l", tostring(line) }
        if current_env then
            vim.list_extend(cmd, { "--env", current_env })
        end

        local stdout_data = {}

        local job_id = vim.fn.jobstart(cmd, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if data then
                    for _, data_line in ipairs(data) do
                        table.insert(stdout_data, data_line)
                    end
                end
            end,
            on_exit = function(_, code, _)
                vim.schedule(function()
                    vim.fn.delete(tmp)
                    if code == 0 then
                        B.append(stdout_data)
                        run_next()
                    else
                        vim.notify(
                            "HttpYac: sequence aborted at request " .. index .. " (exit code " .. code .. ")",
                            vim.log.levels.ERROR
                        )
                    end
                end)
            end,
        })

        if job_id <= 0 then
            vim.fn.delete(tmp)
            vim.notify(
                "HttpYac: failed to start httpyac for request '" .. entry.request_name .. "'",
                vim.log.levels.ERROR
            )
        end
    end

    run_next()
end

-- Toggles recording mode. First call starts recording; second call stops and prompts for a name.
function M.toggle_recording()
    if not M.is_recording then
        M.is_recording = true
        M.recorded_requests = {}
        vim.notify("HttpYac: recording started — run requests to add them to the sequence", vim.log.levels.INFO)
        return
    end

    M.is_recording = false

    if #M.recorded_requests == 0 then
        vim.notify("HttpYac: recording stopped — no requests were captured", vim.log.levels.WARN)
        return
    end

    vim.ui.input({ prompt = "Sequence name (ESC to discard): " }, function(name)
        if not name or name == "" then
            vim.notify("HttpYac: sequence discarded", vim.log.levels.INFO)
            return
        end

        local data = M.load_sequences()

        for _, existing in ipairs(data.sequences) do
            if existing.name == name then
                vim.notify("HttpYac: sequence '" .. name .. "' already exists — choose a different name", vim.log.levels.WARN)
                return
            end
        end

        table.insert(data.sequences, {
            name = name,
            requests = vim.deepcopy(M.recorded_requests),
        })
        M.save_sequences(data)
        vim.notify("HttpYac: sequence '" .. name .. "' saved (" .. #M.recorded_requests .. " requests)", vim.log.levels.INFO)
    end)
end

local function show_action_menu(seq, idx, config, current_env)
    vim.ui.select({ "Run", "Delete" }, { prompt = "Action for '" .. seq.name .. "':" }, function(action)
        if not action then
            return
        end
        if action == "Run" then
            M.run_sequence(seq, config, current_env)
        elseif action == "Delete" then
            -- Reload from disk to avoid overwriting concurrent changes.
            local fresh = M.load_sequences()
            for i, s in ipairs(fresh.sequences) do
                if s.name == seq.name then
                    table.remove(fresh.sequences, i)
                    break
                end
            end
            M.save_sequences(fresh)
            vim.notify("HttpYac: sequence '" .. seq.name .. "' deleted", vim.log.levels.INFO)
        end
    end)
end

-- Opens a picker listing saved sequences; selecting one opens a Run/Delete action menu.
function M.show_picker(config, current_env)
    local data = M.load_sequences()
    local seqs = data.sequences

    if not seqs or #seqs == 0 then
        vim.notify("HttpYac: no sequences saved", vim.log.levels.WARN)
        return
    end

    local names = {}
    for _, seq in ipairs(seqs) do
        table.insert(names, seq.name .. " (" .. #(seq.requests or {}) .. " requests)")
    end

    vim.ui.select(names, { prompt = "Select a sequence:" }, function(choice, idx)
        if not choice then
            return
        end
        show_action_menu(seqs[idx], idx, config, current_env)
    end)
end

return M
