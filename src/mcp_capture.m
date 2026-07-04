function records = mcp_capture(tag, figs)
%MCP_CAPTURE Save figures to PNG files and update manifest.json.
% Minimum supported MATLAB version: R2016a.

global MCP_OUT_DIR MCP_FIG_COUNTER MCP_MANIFEST

if nargin < 1 || isempty(tag)
    tag = 'figure';
end

if isempty(MCP_OUT_DIR)
    mcp_init();
end

if isempty(MCP_FIG_COUNTER)
    MCP_FIG_COUNTER = 0;
end

if isempty(MCP_MANIFEST)
    MCP_MANIFEST = mcp_local_empty_manifest();
end

if nargin < 2 || isempty(figs)
    figs = findobj(0, 'Type', 'figure');
    figs = mcp_local_sort_figs(figs);
end

if isempty(figs)
    warning('mcp_capture:noFigures', 'No open figures to capture.');
    records = struct('file', {}, 'tag', {}, 'figNumber', {});
    mcp_local_write_manifest(MCP_OUT_DIR, MCP_MANIFEST);
    return;
end

safeTag = mcp_local_safe_tag(tag);
records = struct('file', {}, 'tag', {}, 'figNumber', {});

for k = 1:numel(figs)
    fig = figs(k);
    if ~ishandle(fig)
        continue;
    end

    MCP_FIG_COUNTER = MCP_FIG_COUNTER + 1;
    figNumber = mcp_local_fig_number(fig);
    fileName = sprintf('%03d_%s.png', MCP_FIG_COUNTER, safeTag);
    filePath = fullfile(MCP_OUT_DIR, fileName);

    print(fig, filePath, '-dpng', '-r150');

    rec.file = filePath;
    rec.tag = tag;
    rec.figNumber = figNumber;
    records(end + 1) = rec;

    man.index = MCP_FIG_COUNTER;
    man.tag = tag;
    man.figNumber = figNumber;
    man.file = filePath;
    man.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    MCP_MANIFEST(end + 1) = man;
end

mcp_local_write_manifest(MCP_OUT_DIR, MCP_MANIFEST);
end

function figs = mcp_local_sort_figs(figs)
if isempty(figs)
    return;
end

nums = zeros(size(figs));
for i = 1:numel(figs)
    nums(i) = mcp_local_fig_number(figs(i));
end
[dummy, idx] = sort(nums);
figs = figs(idx);
end

function n = mcp_local_fig_number(fig)
n = 0;
try
    n = get(fig, 'Number');
catch
    n = double(fig);
end
if isempty(n)
    n = 0;
end
end

function tag = mcp_local_safe_tag(tag)
tag = char(tag);
tag = regexprep(tag, '[^A-Za-z0-9_-]', '_');
if isempty(tag)
    tag = 'figure';
end
end

function mcp_local_write_manifest(outdir, manifest)
manifestPath = fullfile(outdir, 'manifest.json');
fid = fopen(manifestPath, 'w');
if fid < 0
    error('mcp_capture:io', 'Could not write manifest file.');
end
fprintf(fid, '%s', mcp_json(manifest));
fclose(fid);
end

function s = mcp_local_empty_manifest()
s = struct('index', {}, 'tag', {}, 'figNumber', {}, 'file', {}, 'timestamp', {});
end
