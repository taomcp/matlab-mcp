# matlab-mcp —— Claude 与 MATLAB 之间的"看图/看数据"桥

> 架构:Claude(总体架构师、验收人) · Codex(执行、写代码) · Claude(验收)
> 目标运行环境:MATLAB R2016a 及以后的**任意**版本,纯 MATLAB,无 Python、无第三方依赖。

## 0. 定位:这是一个给 AI Agent 用的工具(不是给人用的)

使用者**默认是一个 AI Agent**(Claude、Codex、DeepSeek 或任何同类),不是人类。
工具的完整价值链是:Agent 起 MATLAB → MATLAB 出 PNG + JSON → **Agent** Read 图和 JSON 并下判断。

### 0.1 对使用者(Agent)的唯一要求 —— 两个通用能力
1. 能执行 shell 命令(用来起 `matlab -batch` / `matlab -r`)。
2. 能读取本地文件(读 PNG 做视觉判读,读 JSON 拿结论化数字)。

只要 Agent 具备这两点 + 机器上有 MATLAB R2016a+,即闭环。**无任何额外环境安装。**
唯一配置点:`matlab` 可执行文件需能被命令行调用(在 PATH 中,或使用完整路径 `...\bin\matlab.exe`)。README 需给出如何检查。

### 0.2 Agent 无关(Agent-agnostic)—— 与"波形无关"同构的设计原则
- 工具通过**文件契约**通信(命令行入,PNG+JSON 出),**不依赖任何 Agent 的私有 API**。
- 因此 Claude 能用、Codex 能用、DeepSeek 能用、未来的新 Agent 也能用。
- 对 Agent 的唯一耦合就是 §0.1 的两个通用能力——这是所有 Agent 的最小公约数。
- 哲学:**不绑波形,也不绑 Agent,只认"文件 + 命令行"这个最小公约数。**

### 0.3 由"读者是机器"推出的硬性输出要求
- 输出的 JSON 必须是**严格合法**的、能被标准 JSON 解析器解析的(不是"MATLAB 能读回"就算数)。
- 禁止出现 `NaN`/`Inf` 等非法 JSON 字面量 → 一律转 `null`(见 §5.4)。
- 字段名固定、结构可预测,Agent 无需猜测或容错解析。

---

## 1. 这个工具要解决的问题

每次让 Claude 用 MATLAB 处理雷达数据、并"配合图和数据判断代码对不对"时,Claude 都要重复走同一条路径:

1. 写 `exportgraphics`/`saveas` 代码把图存下来
2. 猜/找 PNG 的保存路径
3. 用 Read 打开图
4. 再写一段 MATLAB 提取峰值/维度/统计量
5. 跑、解析文本、下判断

**这条路径每次都几乎一样,烧 token、耗往返。** 本工具把这条路径固化成几个 MATLAB 函数,让 Claude 从"七八轮往返"压到"两三轮"。

### 1.1 最核心的设计原则:波形无关(Waveform-agnostic)

用户的波形会不断变:这次 FMCW、下次 LFM 脉冲;这次 CPI 含 16 个 PRT、下次 2048 个;每个 PRT 长度还不一样。

**因此本工具对波形、CPI 结构、PRT、距离/速度轴一无所知,也照样能用。**
- 工具里**绝不**出现 `range_axis`、`doppler_bin`、`PRT`、`CPI` 这类词。
- 抽象层不在"雷达",而在"MATLAB 的 figure 和数组长什么样"。
- 一个 figure 就是 figure;一个数组就是数组。它只报"这张图/这个数组的通用属性和结论",领域判断(这是不是镜像谱、这个 SNR 够不够)由 Claude 在对话里用取到的数字自己推——推理只花当次 token,不占工具的维护成本。

省的绝对量不算大(每次省几轮往返),但**这几个函数用户一辈子的雷达代码都不用改**:低维护、零绑定、天天有用。这就是它的价值。

---

## 2. 架构总览

```
┌─────────┐   Bash: matlab -batch "..."    ┌──────────────────┐
│ Claude  │ ─────────────────────────────► │  MATLAB (冷启动)  │
│         │                                 │  run 用户脚本     │
│         │                                 │  + mcp_* 函数     │
│         │   Read: PNG / JSON              │        │          │
│         │ ◄───────────────────────────── │   写到 mcp_out/   │
└─────────┘        文件契约                  └──────────────────┘
```

- **桥的本体 = 一组 MATLAB 函数 + 一个固定的输出目录契约。**
- Claude 通过 Bash 用命令行启动 MATLAB,跑用户脚本,并在末尾调用 `mcp_*` 函数。
- MATLAB 把图(PNG)和结论(JSON)写到 `mcp_out/`。
- Claude 用 Read 看 PNG(多模态渲染)、看 JSON(结论化数字)。
- **没有常驻进程、没有 MCP server、没有 Python。**

### 2.1 默认冷启动,热会话为可选的 Phase 2

- **Phase 1(本方案主体,先做):** 冷启动。每次 `matlab -batch` 起一个新进程。简单、最兼容、零基础设施。代价:MATLAB 启动 ~10-20s。可接受,因为验证不是高频到毫秒级。
- **Phase 2(可选,验证顺手后再加):** 纯 MATLAB 的"热会话守护"——一个 `mcp_daemon.m` 循环轮询 `inbox/` 目录里的命令文件,执行后把结果写 `outbox/`,让 MATLAB 保持热态省去启动开销。仍然纯 MATLAB。**Phase 1 不实现它,先验证桥本身是否好用。**

---

## 3. 兼容性约束(R2016a+,Codex 必须遵守)

### 3.1 禁用函数(这些在 2016a 不存在或行为不同)

| 禁用 | 首次出现版本 | 替代方案 |
|---|---|---|
| `exportgraphics` | R2020a | 用 `print(fig, path, '-dpng', '-r150')` |
| `jsonencode` / `jsondecode` | R2016b | 用自带的 `mcp_json.m` 编码器(见 §5.4) |
| `string` 类型 / 双引号字符串 | R2016b | 一律用 char 数组(单引号) |
| `contains`/`startsWith`/`endsWith` | R2016b | 用 `strfind`/`regexp`/`strncmp` |
| `isfile`/`isfolder` | R2017b | 用 `exist(p,'file')` / `exist(p,'dir')` |
| `xline`/`yline` | R2018b | 不用,不需要 |
| `newline` 常量 | R2016b | 用 `sprintf('\n')` 或 `char(10)` |

### 3.2 必须遵守
- 所有函数加版本注释,说明最低支持 R2016a。
- 无图形界面时仍要能出图:`mcp_init` 里设 `set(0, 'DefaultFigureVisible', 'off')`,figure 照建照 `print`,但不弹窗。**不要**用 `-noFigureWindows`(那会阻止 figure 存在,导致无法 print)。
- 只用 base MATLAB,**不依赖任何 toolbox**(不用 Signal/Phased Array 等)。
- 全部代码用英文注释 + 少量中文说明皆可,但函数名/变量名英文。

---

## 4. 目录与输出契约

```
matlab-mcp/
├── PLAN.md                  ← 本文档
├── README.md                ← Codex 编写:安装与用法
├── src/
│   ├── mcp_init.m           ← 初始化输出目录、重置计数器、关闭figure弹窗
│   ├── mcp_capture.m        ← 抓 figure → PNG + manifest
│   ├── mcp_describe_fig.m   ← figure → 结构化 JSON
│   ├── mcp_describe_var.m   ← 变量 → 结构化 JSON
│   ├── mcp_json.m           ← struct → JSON 字符串(2016a fallback 编码器)
│   └── mcp_run.m            ← 便捷入口:跑用户脚本并初始化(可选糖)
├── test/
│   ├── test_mcp.m           ← 自测:构造已知真值,断言各函数输出正确
│   └── demo.m               ← 一个最小演示(与雷达无关的通用示例即可)
└── mcp_out/                 ← 运行时生成(git 忽略)
    ├── manifest.json        ← 累积:每次 capture 的图清单
    ├── 001_<tag>.png
    ├── 002_<tag>.png
    ├── fig_<n>.json         ← describe_fig 输出
    └── var_<name>.json      ← describe_var 输出
```

**输出目录默认 = 当前工作目录下的 `mcp_out/`,可由 `mcp_init(outdir)` 覆盖。**

---

## 5. 函数详细规格(Codex 按此实现,不得自行改契约)

### 5.1 `mcp_init(outdir)`
- **入参:** `outdir`(可选 char):输出目录。缺省 `fullfile(pwd,'mcp_out')`。
- **行为:**
  - 若目录不存在则 `mkdir`。
  - 重置全局图片计数器为 0(用 persistent 变量或写一个 `.counter` 文件均可;推荐 persistent,更干净)。
  - `set(0, 'DefaultFigureVisible', 'off')`。
  - 把 `outdir` 记到一个模块级状态(persistent),供后续函数默认使用。
- **返回:** `outdir`(char,绝对路径)。

### 5.2 `mcp_capture(tag, figs)`
- **入参:**
  - `tag`(char):这批图的标签,用于文件名。
  - `figs`(可选):figure 句柄数组。缺省 = 当前所有打开的 figure(`findobj(0, 'Type', 'figure')`,注意排序,按 Number 升序)。
- **行为:** 对每个 figure:
  - 计数器 +1,文件名 `sprintf('%03d_%s.png', n, tag)`。
  - `print(fig, path, '-dpng', '-r150')`。
  - 追加一条记录到 `manifest.json`:`{index, tag, figNumber, file, timestamp}`(timestamp 用 `datestr(now,'yyyy-mm-dd HH:MM:SS')`)。
- **返回:** struct 数组,每元素含 `file`(绝对路径)、`tag`、`figNumber`。
- **健壮性:** 没有打开的 figure 时,返回空 struct 且不报错(写一条 warning 到 stdout)。

### 5.3 `mcp_describe_fig(fig)`
- **入参:** `fig`(可选):figure 句柄或编号。缺省 `gcf`。
- **行为:** 遍历该 figure 下所有 axes,对每个 axes 收集**通用**属性:
  - `xlim`, `ylim`, `xscale`, `yscale`('linear'/'log')
  - `xlabel`, `ylabel`, `title`(取 String,char)
  - 对每条 line 子对象:`peakValue`(=max(abs(YData)))、`peakX`(对应 XData)、`ymin`, `ymax`, `numPoints`、`hasNaN`(YData 中 NaN 数)、`hasInf`。
  - 对 image/surface(有 CData)对象:`cdataSize`、`cmin`、`cmax`、`dynamicRangeLinear`(cmax-cmin)、`numNaN`、`numInf`。**不做 dB 换算**(那属于领域判断,交给 Claude)。
- **输出:** 写 `mcp_out/fig_<n>.json`,同时返回等价 struct。
- **注意:** 只读 figure 对象的通用属性(`XLim`/`Children`/`CData`/`XData`/`YData`),不假设图里画的是什么物理量。

### 5.4 `mcp_describe_var(x, name)`
- **入参:** `x`(任意变量);`name`(char)。
- **行为:** 报告**通用数组属性**:
  - `size`(向量)、`class`(char)、`isreal`(logical)
  - `numel`、`numNaN`、`numInf`、`numZero`
  - 若为数值实数:`min`, `max`, `mean`(用 `nanmax`? 不——2016a 可用 `max(x(:))`,先 `x(~isnan)` 过滤;为兼容直接 `min/max/mean` 对去 NaN 后的数据)
  - 若为复数:额外报 `magMin`, `magMax`, `magMean`(基于 `abs(x)`),并报幅度最大值的线性下标 `peakIndexLinear`。
  - 若为 1D/2D 数值:报幅度峰值的下标(1D 给 index,2D 给 [row,col])。
- **输出:** 写 `mcp_out/var_<name>.json`,返回等价 struct。
- **意义:** 覆盖雷达代码最高频的通用 bug——维度转置、复数被当实数、出现 NaN、归一化把峰削平——**全是通用数组属性,不需要知道是雷达。**

### 5.5 `mcp_json(s)`  —— 2016a JSON fallback 编码器
- **入参:** `s`(struct / 数值 / char / cell / logical)。
- **行为:** 递归把 MATLAB 值编码成 JSON 字符串(char)。支持:标量、向量(→数组)、struct(→object)、struct 数组(→object 数组)、char(→字符串,转义 `"` `\` 换行)、logical(→true/false)、NaN/Inf(→ `null`,因为 JSON 无 NaN)。
- **理由:** `jsonencode` 从 R2016b 才有,为覆盖 2016a 必须自带。**所有写 JSON 的地方统一走它**(即使高版本有 jsonencode 也用自己的,保证行为一致、可控)。
- **健壮性:** 输出必须是合法 JSON(Claude 要能 Read 后解析)。test 里要验证往返基本正确。

### 5.6 `mcp_run(scriptPath, outdir)` —— 可选便捷入口
- 行为:`mcp_init(outdir)` → `run(scriptPath)`(在 base/caller 工作区执行,变量可被后续 describe 访问)→ 返回。
- 只是糖,让 Claude 一行命令跑完。非必须,但推荐实现。

---

## 6. Claude 的典型调用流程(用法示例,写进 README)

冷启动、一条命令跑完用户脚本并取结论:

```bash
matlab -nosplash -nodesktop -r "\
  addpath('<repo-root>/src'); \
  mcp_init('<repo-root>/mcp_out'); \
  run('user_fmcw_script.m'); \
  mcp_capture('rd_map'); \
  mcp_describe_var(rd_map, 'rd_map'); \
  exit"
```
> R2019a+ 可用 `matlab -batch "..."`(无需手动 exit)。README 需同时给出 2016a 的 `-r "...; exit"` 写法和新版 `-batch` 写法。

然后 Claude:
- Read `mcp_out/manifest.json` → 知道有哪些图
- Read `mcp_out/001_rd_map.png` → 看图形态(异常侦察)
- Read `mcp_out/var_rd_map.json` → 拿维度/峰值/NaN 等结论化数字

---

## 7. 验收标准(Claude 按此逐条验,Codex 需保证全过)

Codex 交付后,Claude 会:

### 7.1 兼容性静态检查
- [ ] grep 全部 `src/` 代码,确认**无** §3.1 禁用函数(`exportgraphics`/`jsonencode`/`string(`/`contains(`/`isfile(`/`xline`/`yline`/双引号字符串)。
- [ ] 确认无 toolbox 依赖(无 Signal/Phased/Image toolbox 函数)。

### 7.2 功能自测(`test/test_mcp.m`,须在真实 MATLAB 里跑通、全 assert 通过)
- [ ] **describe_fig 峰值定位:** 构造 `plot(x, y)`,y 在 `x=87` 处有唯一最大值 → 断言输出 `peakX ≈ 87`。
- [ ] **describe_var 复数识别:** 构造复数矩阵 → 断言 `isreal=false`,且 `magMax` 正确。
- [ ] **describe_var NaN 计数:** 数组里塞 3 个 NaN → 断言 `numNaN=3`。
- [ ] **describe_var 维度:** `[16 x 1000]` 和 `[2048 x 500]` 各测一次 → 断言 `size` 正确(验证波形无关:不同 CPI/PRT 结构都能报)。
- [ ] **capture 出图:** 建 2 个 figure → `mcp_capture('t')` → 断言 `mcp_out/` 下生成 2 个 PNG 且 manifest 有 2 条。
- [ ] **json 合法性:** `mcp_json` 编码一个含 char/数值/NaN/嵌套 struct 的对象 → 断言产物能被标准 JSON 解析(Claude 侧 Read 验证)。

### 7.3 端到端
- [ ] Claude 亲自用 Bash 起一次 MATLAB,跑 `demo.m`,Read 出的 PNG 能正常渲染、JSON 能正常解析。

### 7.4 交付物清单
- [ ] `src/` 六个 `.m` 文件齐全且符合 §5 契约。
- [ ] `test/test_mcp.m`、`test/demo.m`。
- [ ] `README.md`:2016a 与新版两种启动写法、目录契约、每个函数一句话说明。
- [ ] `.gitignore` 忽略 `mcp_out/`。

---

## 8. 明确不做的(守住通用性这条线)

以下更省事,但会绑死波形/数据契约,**本工具一律不做**,需要时由 Claude 用上面的通用工具取数后自行推理:
- `analyze_range_doppler` / 距离-多普勒图专用分析
- `verify_point_target` / 合成点目标真值断言(假设点目标、距离速度轴)
- 任何出现 range/doppler/PRT/CPI/SNR/CFAR 字样的"领域判读"函数
- 任何 GUI / dashboard / 实时交互界面
- 任何 dB 换算、坐标轴物理含义推断

理由:通用性与省事程度在这里是对立的。用户选了通用,就守住通用——换波形不改工具,才是长期价值所在。
