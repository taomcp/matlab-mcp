function test_mcp()
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rootDir, 'src'));

outdir = fullfile(rootDir, 'mcp_out');
mcp_init(outdir);
close all;

x = 1:100;
y = zeros(size(x));
y(87) = 42;
figure(1);
plot(x, y);
figInfo = mcp_describe_fig(1);
assert(abs(figInfo.axes(1).lines(1).peakX - 87) < 1e-12);

z = [1 + 1i, 2 + 2i; 3 + 4i, 0];
varInfo = mcp_describe_var(z, 'complex_matrix');
assert(varInfo.isreal == 0);
assert(abs(varInfo.magMax - 5) < 1e-12);

n = [1 NaN 2; NaN 3 NaN];
nanInfo = mcp_describe_var(n, 'nan_matrix');
assert(nanInfo.numNaN == 3);

a = zeros(16, 1000);
b = zeros(2048, 500);
aInfo = mcp_describe_var(a, 'a_dims');
bInfo = mcp_describe_var(b, 'b_dims');
assert(isequal(aInfo.size, [16 1000]));
assert(isequal(bInfo.size, [2048 500]));

close all;
figure(1);
plot(1:10, 1:10);
figure(2);
plot(1:10, (1:10) .^ 2);
records = mcp_capture('t');
assert(numel(records) == 2);
assert(exist(records(1).file, 'file') == 2);
assert(exist(records(2).file, 'file') == 2);

manifestText = mcp_local_read_all(fullfile(outdir, 'manifest.json'));
assert(mcp_local_count_text(manifestText, 'figNumber') == 2);

obj.name = 'json test';
obj.values = [1 NaN Inf -Inf 5];
obj.child.ok = true;
obj.child.text = ['a' char(10) 'b'];
jsonText = mcp_json(obj);
assert(isempty(strfind(jsonText, 'NaN')));
assert(isempty(strfind(jsonText, 'Inf')));
assert(~isempty(strfind(jsonText, 'null')));
mcp_local_json_smoke(jsonText);

disp('MATLAB_MCP test_mcp passed.');
end

function text = mcp_local_read_all(pathName)
fid = fopen(pathName, 'r');
assert(fid >= 0);
cleaner = onCleanup(@() fclose(fid));
text = fread(fid, '*char')';
end

function n = mcp_local_count_text(text, needle)
n = 0;
pos = 1;
while true
    idx = strfind(text(pos:end), needle);
    if isempty(idx)
        break;
    end
    n = n + 1;
    pos = pos + idx(1) + length(needle) - 1;
end
end

function mcp_local_json_smoke(text)
assert(~isempty(text));
assert(text(1) == '{' || text(1) == '[');
assert(text(end) == '}' || text(end) == ']');
try
    manager = javax.script.ScriptEngineManager;
    engine = manager.getEngineByName('javascript');
    if ~isempty(engine)
        engine.eval(['JSON.parse(' mcp_json(text) ');']);
    end
catch err
    error('test_mcp:json', ['JSON parser rejected output: ' err.message]);
end
end
