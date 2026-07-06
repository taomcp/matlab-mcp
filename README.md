# MATLAB_MCP

MATLAB_MCP is a small file-based bridge for AI agents that need MATLAB to save figures as PNG files and write structured JSON summaries of figures and variables.

It is intentionally simple:

- The agent can run shell commands.
- The agent can read local files.
- The machine has MATLAB R2016a or newer.
- MATLAB can be called from the command line as `matlab`, or by using the full path to `matlab.exe`.

No Python, no server process, no MATLAB toolbox, and no third-party dependency is required.

## Check MATLAB

Windows PowerShell:

```powershell
Get-Command matlab
matlab -help
```

If `matlab` is not on `PATH`, use the full executable path, for example:

```powershell
& 'C:\Program Files\MATLAB\R2024b\bin\matlab.exe' -help
```

## Output Contract

By default, output is written to `mcp_out/` under the current MATLAB working directory. You can override this with `mcp_init(outdir)`.

Typical files:

- `manifest.json`: figure capture list.
- `001_tag.png`: captured figure image.
- `fig_1.json`: figure summary.
- `var_name.json`: variable summary.

## Functions

- `mcp_init(outdir)`: create the output directory, reset capture state, and hide figure windows.
- `mcp_capture(tag, figs)`: save figures to PNG and update `manifest.json`.
- `mcp_describe_fig(fig)`: summarize axes, line data, and CData objects as JSON.
- `mcp_describe_var(x, name)`: summarize generic array properties as JSON.
- `mcp_json(value)`: encode MATLAB values as strict JSON for R2016a and newer.
- `mcp_run(scriptPath, outdir)`: initialize output state and run a script.

## Newer MATLAB Command

MATLAB R2019a and newer can use `-batch`:

```powershell
matlab -batch "addpath('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/src'); mcp_init('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/mcp_out'); run('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/test/demo.m');"
```

## MATLAB R2016a-Compatible Command

MATLAB R2016a can use `-r` with an explicit `exit`:

```powershell
matlab -nosplash -nodesktop -r "addpath('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/src'); mcp_init('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/mcp_out'); run('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/test/demo.m'); exit"
```

For scripts that need to capture outputs manually, call the functions after the user code:

```matlab
addpath('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/src');
mcp_init('D:/Obsidian/01_Projects/MATLAB/MATLAB_MCP/mcp_out');
run('user_script.m');
mcp_capture('check');
mcp_describe_var(workspace_value, 'workspace_value');
exit
```

The agent then reads `mcp_out/manifest.json`, the PNG files, and the JSON summaries.
