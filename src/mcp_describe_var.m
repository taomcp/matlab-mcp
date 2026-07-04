function info = mcp_describe_var(x, name)
%MCP_DESCRIBE_VAR Describe general variable properties and write JSON.
% Minimum supported MATLAB version: R2016a.

global MCP_OUT_DIR

if nargin < 2 || isempty(name)
    name = 'var';
end

if isempty(MCP_OUT_DIR)
    mcp_init();
end

info.name = char(name);
info.size = size(x);
info.class = class(x);
info.isreal = isreal(x);
info.numel = numel(x);
info.numNaN = 0;
info.numInf = 0;
info.numZero = 0;

if isnumeric(x) || islogical(x)
    xv = x(:);
    info.numZero = sum(xv == 0);

    if isnumeric(x)
        info.numNaN = sum(isnan(xv));
        info.numInf = sum(isinf(xv));
    end

    if isnumeric(x) && isreal(x)
        finiteVals = double(xv(~isnan(xv) & ~isinf(xv)));
        if isempty(finiteVals)
            info.min = NaN;
            info.max = NaN;
            info.mean = NaN;
        else
            info.min = min(finiteVals);
            info.max = max(finiteVals);
            info.mean = mean(finiteVals);
        end
        info = mcp_local_add_peak(info, x);
    elseif isnumeric(x)
        mag = abs(x);
        mv = mag(:);
        finiteMag = double(mv(~isnan(mv) & ~isinf(mv)));
        if isempty(finiteMag)
            info.magMin = NaN;
            info.magMax = NaN;
            info.magMean = NaN;
        else
            info.magMin = min(finiteMag);
            info.magMax = max(finiteMag);
            info.magMean = mean(finiteMag);
        end
        info = mcp_local_add_peak(info, mag);
    end
end

fileName = ['var_' mcp_local_safe_name(name) '.json'];
jsonPath = fullfile(MCP_OUT_DIR, fileName);
mcp_local_write_json(jsonPath, info);
end

function info = mcp_local_add_peak(info, values)
mag = abs(values);
mv = mag(:);
bad = isnan(mv) | isinf(mv);
work = double(mv);
work(bad) = -Inf;

if isempty(work) || all(isinf(work) & work < 0)
    info.peakValue = NaN;
    info.peakIndexLinear = 0;
    return;
end

[peakValue, idx] = max(work);
info.peakValue = peakValue;
info.peakIndexLinear = idx;

dims = size(values);
if isvector(values)
    info.peakIndex = idx;
elseif numel(dims) == 2
    [row, col] = ind2sub(dims, idx);
    info.peakSubscript = [row col];
end
end

function s = mcp_local_safe_name(name)
s = char(name);
s = regexprep(s, '[^A-Za-z0-9_-]', '_');
if isempty(s)
    s = 'var';
end
end

function mcp_local_write_json(pathName, value)
fid = fopen(pathName, 'w');
if fid < 0
    error('mcp_describe_var:io', 'Could not write JSON file.');
end
fprintf(fid, '%s', mcp_json(value));
fclose(fid);
end
