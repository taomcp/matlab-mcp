rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rootDir, 'src'));

outdir = fullfile(rootDir, 'mcp_out');
mcp_init(outdir);

x = 1:100;
y = sin(x ./ 8);
y(60) = 2.5;

figure(1);
plot(x, y);
xlabel('sample');
ylabel('value');
title('MATLAB MCP demo line');

grid = peaks(40);
figure(2);
imagesc(grid);
title('MATLAB MCP demo grid');
colorbar;

mcp_capture('demo');
mcp_describe_fig(1);
mcp_describe_var(y, 'demo_line');
mcp_describe_var(grid, 'demo_grid');
