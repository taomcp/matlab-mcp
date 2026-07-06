# MATLAB_MCP Plan

MATLAB_MCP is a file-based bridge for AI agents that need to inspect MATLAB figures and arrays without relying on a live MCP server, Python, or MATLAB Engine.

## Goal

Provide a stable way for an AI agent to:
- launch MATLAB from the command line
- run user code in a headless session
- capture figures as PNG files
- summarize figures and variables as strict JSON
- read those artifacts back for validation and reasoning

The tool targets MATLAB R2016a and newer.

## Design Principles

1. Pure MATLAB only.
   No Python, no third-party packages, no toolbox dependency.
2. R2016a-compatible behavior.
   Avoid newer APIs such as `jsonencode`, `exportgraphics`, `string`, `contains`, `isfile`, `xline`, and `yline`.
3. Waveform-agnostic outputs.
   The tool reports generic figure and array properties rather than domain-specific radar conclusions.
4. Agent-agnostic workflow.
   Any agent that can run shell commands and read local files can use this tool.
5. Headless-first execution.
   The primary loop is a cold MATLAB start with file outputs, not a persistent interactive session.

## Repository Contract

```text
MATLAB_MCP/
  README.md
  PLAN.md
  src/
    mcp_init.m
    mcp_capture.m
    mcp_describe_fig.m
    mcp_describe_var.m
    mcp_json.m
    mcp_run.m
  test/
    test_mcp.m
    demo.m
  mcp_out/         (generated, gitignored)
```

## Core Functions

- `mcp_init(outdir)`
  Create or reset the output directory, clear capture state, and hide figure windows.
- `mcp_capture(tag, figs)`
  Save one or more figures as PNG files and update `manifest.json`.
- `mcp_describe_fig(fig)`
  Export a generic JSON summary of axes, lines, and CData-based objects.
- `mcp_describe_var(x, name)`
  Export a generic JSON summary of an array or scalar value.
- `mcp_json(value)`
  Encode MATLAB data as strict JSON that remains valid on R2016a.
- `mcp_run(scriptPath, outdir)`
  Optional convenience wrapper that initializes the session and runs a script.

## Output Rules

Default output goes to `mcp_out/` under the current working directory unless overridden by `mcp_init(outdir)`.

Typical artifacts:
- `manifest.json`
- `001_<tag>.png`
- `002_<tag>.png`
- `fig_<n>.json`
- `var_<name>.json`

JSON output must remain strict and parser-friendly:
- convert `NaN` and `Inf` to `null`
- use predictable field names
- avoid MATLAB-only serialization behavior

## Compatibility Constraints

The implementation should continue to avoid:
- `exportgraphics`
- `jsonencode` and `jsondecode`
- `string` arrays and double-quoted string literals
- `contains`, `startsWith`, `endsWith`
- `isfile`, `isfolder`
- `xline`, `yline`
- toolbox-only APIs

Use base MATLAB alternatives such as:
- `print(..., '-dpng', '-r150')`
- `strfind`, `regexp`, `strncmp`
- `exist(path, 'file')`, `exist(path, 'dir')`
- `sprintf('\n')` or `char(10)`

## Validation Expectations

A valid release should pass:
1. Static compatibility review against the R2016a restriction list.
2. `test/test_mcp.m` in a real MATLAB installation.
3. A headless end-to-end demo run that produces readable PNG and JSON outputs.

## Non-Goals

The tool should not become:
- a domain-specific radar analysis package
- a GUI dashboard
- a persistent MATLAB daemon by default
- a replacement for a full MATLAB MCP server

It is a low-friction bridge focused on repeatable evidence export for AI-assisted MATLAB work.
