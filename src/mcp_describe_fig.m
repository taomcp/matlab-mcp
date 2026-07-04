function info = mcp_describe_fig(fig)
%MCP_DESCRIBE_FIG Describe general figure content and write JSON.
% Minimum supported MATLAB version: R2016a.

global MCP_OUT_DIR

if isempty(MCP_OUT_DIR)
    mcp_init();
end

if nargin < 1 || isempty(fig)
    fig = gcf;
else
    fig = mcp_local_resolve_fig(fig);
end

if ~ishandle(fig)
    error('mcp_describe_fig:badFigure', 'Input is not a valid figure.');
end

figNumber = mcp_local_fig_number(fig);
axesList = findobj(fig, 'Type', 'axes');
axesList = flipud(axesList(:));

info.type = 'figure';
info.figureNumber = figNumber;
info.numAxes = numel(axesList);
info.axes = struct('xlim', {}, 'ylim', {}, 'xscale', {}, 'yscale', {}, ...
    'xlabel', {}, 'ylabel', {}, 'title', {}, 'lines', {}, 'cdataObjects', {});

for a = 1:numel(axesList)
    ax = axesList(a);
    axInfo.xlim = get(ax, 'XLim');
    axInfo.ylim = get(ax, 'YLim');
    axInfo.xscale = get(ax, 'XScale');
    axInfo.yscale = get(ax, 'YScale');
    axInfo.xlabel = mcp_local_text(get(get(ax, 'XLabel'), 'String'));
    axInfo.ylabel = mcp_local_text(get(get(ax, 'YLabel'), 'String'));
    axInfo.title = mcp_local_text(get(get(ax, 'Title'), 'String'));
    axInfo.lines = mcp_local_describe_lines(ax);
    axInfo.cdataObjects = mcp_local_describe_cdata(ax);
    info.axes(end + 1) = axInfo;
end

jsonPath = fullfile(MCP_OUT_DIR, sprintf('fig_%d.json', figNumber));
mcp_local_write_json(jsonPath, info);
end

function fig = mcp_local_resolve_fig(fig)
if ishandle(fig)
    return;
end

match = findobj(0, 'Type', 'figure', 'Number', fig);
if isempty(match)
    error('mcp_describe_fig:notFound', 'Figure number was not found.');
end
fig = match(1);
end

function lines = mcp_local_describe_lines(ax)
objs = findobj(ax, 'Type', 'line');
objs = flipud(objs(:));
lines = struct('peakValue', {}, 'peakX', {}, 'ymin', {}, 'ymax', {}, ...
    'numPoints', {}, 'hasNaN', {}, 'hasInf', {});

for i = 1:numel(objs)
    y = get(objs(i), 'YData');
    x = get(objs(i), 'XData');
    yv = y(:);
    av = abs(yv);
    nanMask = isnan(av);
    infMask = isinf(av);
    validMask = ~nanMask;

    item.peakValue = NaN;
    item.peakX = NaN;
    if any(validMask)
        work = av;
        work(nanMask) = -Inf;
        [item.peakValue, idx] = max(work);
        xv = x(:);
        if ~isempty(xv)
            idx = min(idx, numel(xv));
            item.peakX = xv(idx);
        end
    end

    finiteY = yv(~isnan(yv) & ~isinf(yv));
    if isempty(finiteY)
        item.ymin = NaN;
        item.ymax = NaN;
    else
        item.ymin = min(finiteY);
        item.ymax = max(finiteY);
    end

    item.numPoints = numel(y);
    item.hasNaN = sum(nanMask);
    item.hasInf = sum(infMask);
    lines(end + 1) = item;
end
end

function objsInfo = mcp_local_describe_cdata(ax)
objs = findobj(ax, '-property', 'CData');
objs = flipud(objs(:));
objsInfo = struct('type', {}, 'cdataSize', {}, 'cmin', {}, 'cmax', {}, ...
    'dynamicRangeLinear', {}, 'numNaN', {}, 'numInf', {});

for i = 1:numel(objs)
    c = get(objs(i), 'CData');
    if ~isnumeric(c) && ~islogical(c)
        continue;
    end

    cv = double(c(:));
    nanMask = isnan(cv);
    infMask = isinf(cv);
    finiteC = cv(~nanMask & ~infMask);

    item.type = get(objs(i), 'Type');
    item.cdataSize = size(c);
    if isempty(finiteC)
        item.cmin = NaN;
        item.cmax = NaN;
        item.dynamicRangeLinear = NaN;
    else
        item.cmin = min(finiteC);
        item.cmax = max(finiteC);
        item.dynamicRangeLinear = item.cmax - item.cmin;
    end
    item.numNaN = sum(nanMask);
    item.numInf = sum(infMask);
    objsInfo(end + 1) = item;
end
end

function s = mcp_local_text(v)
if iscell(v)
    parts = cell(size(v));
    for i = 1:numel(v)
        parts{i} = char(v{i});
    end
    s = strjoin(parts, char(10));
else
    s = char(v);
end
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

function mcp_local_write_json(pathName, value)
fid = fopen(pathName, 'w');
if fid < 0
    error('mcp_describe_fig:io', 'Could not write JSON file.');
end
fprintf(fid, '%s', mcp_json(value));
fclose(fid);
end
