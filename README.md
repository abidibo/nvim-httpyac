# Neovim HttpYac

![Screenshot](screenshots/screen.png)

A very simple plugin which integrates [HttpYac](https://httpyac.github.io/) in Neovim.

I currently use it to to run REST requests, I don't need much, but I'll add functionalities once I need them.

It basically runs httpyac cli against the current file, executing all request or the one under the cursor, so you can use vars, envs, etc...
It provides syntax highlighting for the responses.

> [!IMPORTANT]
> You need to have [HttpYac](https://httpyac.github.io/) installed and in path!
  i.e. `npm install -g httpyac`

## Installation

With [LazyVim](https://github.com/LazyVim/LazyVim):

```lua
return {
  "abidibo/nvim-httpyac",
  config = function ()
    require('nvim-httpyac').setup({
      output_view = "vertical" -- "vertical" | "horizontal"
    })
    -- if you want to set up the keymaps
    vim.keymap.set('n', '<Leader>rr', '<cmd>:NvimHttpYac<CR>', { desc='Run request'})
    vim.keymap.set('n', '<Leader>ra', '<cmd>:NvimHttpYacAll<CR>', { desc='Run all requests'})
    vim.keymap.set('n', '<Leader>rp', '<cmd>:NvimHttpYacPicker<CR>', { desc='Run named request'})
    vim.keymap.set('n', '<Leader>re', '<cmd>:NvimHttpYacEnv<CR>', { desc='Select environment'})
    vim.keymap.set('n', '<Leader>rc', '<cmd>:NvimHttpYacEnvClear<CR>', { desc='Clear environment'})
    vim.keymap.set('n', '<Leader>rq', '<cmd>:NvimHttpYacSequence<CR>', { desc='Toggle sequence recording'})
    vim.keymap.set('n', '<Leader>rs', '<cmd>:NvimHttpYacSequencePicker<CR>', { desc='Sequence picker'})
  end
}
```

## Configuration

You can configure the plugin by passing a table to the `setup` function.

- `output_view`: Defines how the output window is opened. Can be `"vertical"` (default) or `"horizontal"`.

## Commands

> [!TIP]
> It's not mandatory to save the file before running the requests,the current buffer content will be used

- **NvimHttpYac**: executes the request under the cursor
- **NvimHttpYacAll**: executes all the requests
- **NvimHttpYacPicker**: shows a picker with all the named requests
- **NvimHttpYacEnv**: shows a picker to select the active environment (sticky across requests)
- **NvimHttpYacEnvClear**: clears the active environment
- **NvimHttpYacSequence**: toggles sequence recording on/off. When stopped, prompts for a name to save the sequence; press ESC to discard
- **NvimHttpYacSequencePicker**: opens a picker listing all saved sequences. Selecting one opens a secondary menu to Run or Delete it

The first three commands take optional parameters that are passed to `httpyac`.
E.g. to use a specific dev environment call `:NvimHttpYac --env dev`

### Environment selector

The `:NvimHttpYacEnv` command discovers environments automatically by scanning for:

- `http-client.env.json` / `http-client.private.env.json` (IntelliJ format — top-level keys are environment names)
- `.env.{name}` and `{name}.env` dotenv files

Files are searched in the current file's directory, the project root, and the `env/` subfolder.

Once selected, the environment is **sticky** — it is automatically appended to all subsequent requests until cleared with `:NvimHttpYacEnvClear` or a new environment is selected. If you pass `--env` explicitly to a command, the sticky environment is ignored for that execution.

### Sequences

The `:NvimHttpYacSequence` command toggles recording mode. While active, every named request you run (via `:NvimHttpYacPicker`) is captured. Stopping recording prompts for a sequence name — press Enter to save, ESC to discard. Unnamed requests (cursor-based or run-all) are skipped with a warning suggesting you add a `# @name` annotation.

Sequences are persisted to `.httpyac-sequences.json` in the project root. Use `:NvimHttpYacSequencePicker` to browse, run, or delete saved sequences.

When a sequence runs, requests execute one by one in the order they were recorded. Output from each request is appended to the output buffer as it completes. If any request fails, the sequence is aborted and an error is shown.

## Credits

This plugin was inspired by the following projects:

- [HttpYac](https://httpyac.github.io/): for the great cli tool
- [rest.nvim](https://github.com/rest-nvim/rest.nvim): for the syntax highlighting
- [vimyac](https://github.com/oxcafedead/vimyac): for the idea
