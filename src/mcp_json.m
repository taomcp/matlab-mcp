function json = mcp_json(value)
%MCP_JSON Encode MATLAB values as strict JSON.
% Minimum supported MATLAB version: R2016a.

json = mcp_local_encode(value);
end

function out = mcp_local_encode(value)
if isstruct(value)
    out = mcp_local_encode_struct(value);
elseif iscell(value)
    out = mcp_local_encode_cell(value);
elseif ischar(value)
    out = mcp_local_encode_char(value);
elseif islogical(value)
    out = mcp_local_encode_logical(value);
elseif isnumeric(value)
    out = mcp_local_encode_numeric(value);
else
    out = 'null';
end
end

function out = mcp_local_encode_struct(value)
if isempty(value)
    out = '[]';
    return;
end

if numel(value) > 1
    parts = cell(1, numel(value));
    for i = 1:numel(value)
        parts{i} = mcp_local_encode_struct(value(i));
    end
    out = ['[' mcp_local_join(parts, ',') ']'];
    return;
end

fields = fieldnames(value);
parts = cell(1, numel(fields));
for i = 1:numel(fields)
    key = mcp_local_encode_char(fields{i});
    val = mcp_local_encode(value.(fields{i}));
    parts{i} = [key ':' val];
end
out = ['{' mcp_local_join(parts, ',') '}'];
end

function out = mcp_local_encode_cell(value)
if isempty(value)
    out = '[]';
    return;
end

parts = cell(1, numel(value));
for i = 1:numel(value)
    parts{i} = mcp_local_encode(value{i});
end
out = ['[' mcp_local_join(parts, ',') ']'];
end

function out = mcp_local_encode_logical(value)
if isempty(value)
    out = '[]';
elseif isscalar(value)
    if value
        out = 'true';
    else
        out = 'false';
    end
elseif isvector(value)
    parts = cell(1, numel(value));
    for i = 1:numel(value)
        parts{i} = mcp_local_encode_logical(value(i));
    end
    out = ['[' mcp_local_join(parts, ',') ']'];
else
    out = mcp_local_encode_matrix(value);
end
end

function out = mcp_local_encode_numeric(value)
if isempty(value)
    out = '[]';
elseif ~isreal(value)
    out = mcp_local_encode(abs(value));
elseif isscalar(value)
    if isnan(value) || isinf(value)
        out = 'null';
    else
        out = sprintf('%.17g', double(value));
    end
elseif isvector(value)
    parts = cell(1, numel(value));
    for i = 1:numel(value)
        parts{i} = mcp_local_encode_numeric(value(i));
    end
    out = ['[' mcp_local_join(parts, ',') ']'];
else
    out = mcp_local_encode_matrix(value);
end
end

function out = mcp_local_encode_matrix(value)
dims = size(value);
rows = dims(1);
cols = prod(dims(2:end));
reshaped = reshape(value, rows, cols);
parts = cell(1, rows);
for r = 1:rows
    rowParts = cell(1, cols);
    for c = 1:cols
        rowParts{c} = mcp_local_encode(reshaped(r, c));
    end
    parts{r} = ['[' mcp_local_join(rowParts, ',') ']'];
end
out = ['[' mcp_local_join(parts, ',') ']'];
end

function out = mcp_local_encode_char(value)
q = char(34);
bs = char(92);
parts = cell(1, length(value));

for i = 1:length(value)
    ch = value(i);
    if ch == char(34)
        parts{i} = [bs q];
    elseif ch == char(92)
        parts{i} = [bs bs];
    elseif ch == char(10)
        parts{i} = [bs 'n'];
    elseif ch == char(13)
        parts{i} = [bs 'r'];
    elseif ch == char(9)
        parts{i} = [bs 't'];
    elseif ch == char(8)
        parts{i} = [bs 'b'];
    elseif ch == char(12)
        parts{i} = [bs 'f'];
    elseif double(ch) < 32
        parts{i} = sprintf('\\u%04x', double(ch));
    else
        parts{i} = ch;
    end
end

out = [q mcp_local_join(parts, '') q];
end

function out = mcp_local_join(parts, sep)
if isempty(parts)
    out = '';
    return;
end

out = parts{1};
for i = 2:numel(parts)
    out = [out sep parts{i}];
end
end
