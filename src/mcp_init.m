function outdir = mcp_init(outdir)
%MCP_INIT Prepare output state for MATLAB_MCP.
% Minimum supported MATLAB version: R2016a.

global MCP_OUT_DIR MCP_FIG_COUNTER MCP_MANIFEST

if nargin < 1 || isempty(outdir)
    outdir = fullfile(pwd, 'mcp_out');
end

outdir = mcp_local_abs_path(outdir);

if exist(outdir, 'dir') ~= 7
    mkdir(outdir);
end

MCP_OUT_DIR = outdir;
MCP_FIG_COUNTER = 0;
MCP_MANIFEST = mcp_local_empty_manifest();

set(0, 'DefaultFigureVisible', 'off');

manifestPath = fullfile(outdir, 'manifest.json');
fid = fopen(manifestPath, 'w');
if fid < 0
    error('mcp_init:io', 'Could not write manifest file.');
end
fprintf(fid, '%s', mcp_json(MCP_MANIFEST));
fclose(fid);
end

function out = mcp_local_abs_path(p)
if isempty(p)
    out = fullfile(pwd, 'mcp_out');
    return;
end

if mcp_local_is_abs_path(p)
    out = p;
else
    out = fullfile(pwd, p);
end
end

function tf = mcp_local_is_abs_path(p)
tf = 0;
if length(p) >= 2 && p(2) == ':'
    tf = 1;
elseif length(p) >= 1 && (p(1) == filesep || p(1) == '/' || p(1) == '\')
    tf = 1;
end
end

function s = mcp_local_empty_manifest()
s = struct('index', {}, 'tag', {}, 'figNumber', {}, 'file', {}, 'timestamp', {});
end
