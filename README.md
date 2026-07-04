# matlab-mcp

`matlab-mcp` is a small file-based MATLAB bridge for AI agents that cuts token usage and speeds up figure and data validation.

Instead of spending multiple chat turns asking an agent to inspect plots, export arrays, and restate results, `matlab-mcp` turns MATLAB outputs into PNG files plus structured JSON summaries that an agent can read directly.

This community edition is intentionally simple:

- the agent can run shell commands
- the agent can read local files
- the machine has MATLAB R2016a or newer
- MATLAB can be called as `matlab` or by full executable path

No Python, no server process, and no MATLAB toolbox dependency are required.

## Why it helps

- reduce token burn by moving repetitive plot and array inspection into MATLAB-side helpers
- shorten the validation loop when checking figures, spectra, traces, matrices, and workspace values
- keep the interface transparent: files in, files out, easy to inspect and debug

## Check MATLAB

```powershell
Get-Command matlab
matlab -help
```

If `matlab` is not on `PATH`, use the full executable path for your local install.

## Output Contract

By default, output is written to `mcp_out/` under the current MATLAB working directory. You can override this with `mcp_init(outdir)`.

Typical files:

- `manifest.json`
- `001_tag.png`
- `fig_1.json`
- `var_name.json`

## Functions

- `mcp_init(outdir)`: create the output directory, reset capture state, and hide figure windows
- `mcp_capture(tag, figs)`: save figures to PNG and update `manifest.json`
- `mcp_describe_fig(fig)`: summarize axes, line data, and CData objects as JSON
- `mcp_describe_var(x, name)`: summarize generic array properties as JSON
- `mcp_json(value)`: encode MATLAB values as strict JSON for R2016a and newer
- `mcp_run(scriptPath, outdir)`: initialize output state and run a script

## Community Edition Scope

This public repository is the community edition. It is meant to be small, inspectable, and easy to adapt for local agent workflows.

It is a good fit for:

- local MATLAB validation loops
- figure and variable inspection for AI-assisted analysis
- reproducible file-based handoff between shell tools and MATLAB

## Commercial Extensions

If this workflow proves useful in a team or production setting, the natural commercial path is not charging for basic source access. The better path is charging for higher-value deployment and integration work around it, for example:

- private deployment inside enterprise environments
- domain-specific extensions for FPGA, DSP, verification, and lab workflows
- team conventions, wrappers, and higher-level automation on top of the file bridge
- consulting and integration into broader AI engineering pipelines

That keeps the public repo useful enough to build trust, while leaving real room for paid work around reliability, deployment, and specialized workflow design.

## Example Commands

From the repository root in PowerShell:

```powershell
$repo = (Resolve-Path .).Path.Replace('\', '/')
matlab -batch "addpath('$repo/src'); mcp_init('$repo/mcp_out'); run('$repo/test/demo.m');"
```

MATLAB R2016a-compatible form:

```powershell
$repo = (Resolve-Path .).Path.Replace('\', '/')
matlab -nosplash -nodesktop -r "addpath('$repo/src'); mcp_init('$repo/mcp_out'); run('$repo/test/demo.m'); exit"
```

For scripts that need manual capture after user code:

```matlab
addpath(fullfile(pwd, 'src'));
mcp_init(fullfile(pwd, 'mcp_out'));
run('user_script.m');
mcp_capture('check');
mcp_describe_var(workspace_value, 'workspace_value');
exit
```

The agent then reads `mcp_out/manifest.json`, the PNG files, and the JSON summaries.

## License

This public preparation copy is set up for `AGPL-3.0`. See `THIRD_PARTY.md` for dependency notes and publishing boundaries.
