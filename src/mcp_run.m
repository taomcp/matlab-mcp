function outdir = mcp_run(scriptPath, outdir)
%MCP_RUN Initialize output state and run a MATLAB script.
% Minimum supported MATLAB version: R2016a.

if nargin < 2 || isempty(outdir)
    outdir = mcp_init();
else
    outdir = mcp_init(outdir);
end

run(scriptPath);
end
