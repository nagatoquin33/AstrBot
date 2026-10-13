# AstrBot 便携版（Portable）设计与实现

> 目标：把 AstrBot 做成放在移动存储介质（U 盘 / 移动硬盘）上**即插即用**的版本——免安装、不依赖宿主机 Python、不在宿主机留下任何持久数据，换电脑即换环境。

## 一、为什么可行：AstrBot 的路径机制研究结论

对 AstrBot 源码（v4.27.2 之后的主线，commit 48ba71ad7）的调研结论：

### 1. 路径解析天然支持重定位（关键）

`astrbot/core/utils/astrbot_path.py` 是全项目唯一的路径出口：

- `get_astrbot_root()`：默认取**当前工作目录**，可被 **`ASTRBOT_ROOT` 环境变量**覆盖；所有数据子目录（`data/` 下的 config、plugins、site-packages、logs、temp、knowledge_base 等）均由它派生。
- 程序源码位置 `get_astrbot_path()` 基于 `__file__`，与安装位置无关。

因此**只要启动器把 `ASTRBOT_ROOT` 指向 U 盘上的目录并 `cd` 过去，整个 AstrBot 就完全自包含**，不需要改动上游代码。桌面包（`ASTRBOT_DESKTOP_CLIENT=1`）反而把 root 指到 `~/.astrbot`，恰恰不适合便携场景，故不采用。

### 2. 依赖隔离已经内置

- 核心依赖：装进便携 Python 自己的 `Lib/site-packages`。
- 插件依赖：`pip_installer.py` 全部装入 `data/site-packages`（且通过 `sys.executable` 调 pip，便携运行时天然生效）。

### 3. WebUI 静态资源可预置

`dashboard_assets.py` 的 dist 优先级：`data/dist`（用户）→ `astrbot/dashboard/dist`（bundled）→ 运行时联网下载。打包时用 AstrBot 自己的 `AstrBotUpdater.ensure_dashboard()` 预热 `data/dist`，即可离线首启。

### 4. 更新链路兼容便携

核心更新走 GitHub Release zip 解压覆盖源码树（不依赖 git），更新后 `update_service.py` 用 `sys.executable` 执行 `pip install -r requirements.txt` —— 依赖会正确装入便携运行时。

### 5. 外部写入点排查结果

| 位置 | 行为 | 处理 |
|---|---|---|
| `metrics.py` | 写 `~/.astrbot/.installation_id` | **已修**：改写入 `data/.installation_id`（portable 分支补丁，适合回馈上游） |
| `astrbot_path.get_astrbot_system_tmp_path()` | 系统 temp 下 `.astrbot` | 启动器重定向 `TMP/TEMP` 到 `data/temp/system` |
| faiss `embedding_storage.py` | Windows 上固定用 `%SystemRoot%\Temp` 做纯 ASCII 桥接 | 保留（faiss 无法处理非 ASCII 路径，瞬时文件用后即删，已在文档说明） |
| 其它 | 无注册表、无 APPDATA、无 `~` 写入 | — |

## 二、便携包结构

```
AstrBot-Portable/
├── python/            python-build-standalone 运行时（CPython 3.12）+ requirements.txt 全量依赖
├── astrbot/           AstrBot 源码包（不含 dashboard Vue 源码 / tests / __pycache__）
├── main.py / runtime_bootstrap.py / requirements.txt / LICENSE / EULA.md
├── data/              运行数据（首启自动补齐；dist 已预置）
├── launch.cmd         Windows 启动器（%~dp0 动态盘符 + ASTRBOT_ROOT + TMP 重定向）
├── launch.sh          Linux/macOS 启动器
└── README-PORTABLE.md  end-user 说明
```

启动器核心逻辑（`portable/launch.cmd`）：

```bat
set "PORTABLE_ROOT=%~dp0"          rem 跟随 U 盘盘符变化
set "ASTRBOT_ROOT=%PORTABLE_ROOT%" rem AstrBot 全部数据重定位至此
set "PATH=%PORTABLE_ROOT%\python;..." rem 便携 Python 优先
set "TMP=...\data\temp\system"     rem 零宿主机残留（可关）
python.exe main.py
```

## 三、打包方法

在一台联网的 Windows 机器上（PowerShell 5.1+）：

```powershell
# 标准打包
.\portable\build_portable.ps1

# 国内网络：GitHub 走代理 + pip 走清华镜像
.\portable\build_portable.ps1 -GitHubProxy "https://gh-proxy.org/" `
    -PipIndex "https://pypi.tuna.tsinghua.edu.cn/simple"

# GitHub API 不通时，手动下载 runtime 后离线打包
# (到 python-build-standalone releases 下载 cpython-3.12.*-x86_64-pc-windows-msvc-install_only.tar.gz)
.\portable\build_portable.ps1 -PythonZip C:\downloads\cpython-3.12.xxx-x86_64-pc-windows-msvc-install_only.tar.gz
```

脚本流程：获取 python-build-standalone → `pip install -r requirements.txt` → robocopy 源码（排除缓存）→ `warmup_dashboard.py` 预热 WebUI → 安装启动器与文档 → 清理 `__pycache__` → 输出体积报告。可重复执行（已有 python 目录则跳过下载）。

选型说明：

- **python-build-standalone**（而非官方 embeddable package）：完整 CPython，自带 pip 与完整 `sys.path` 语义，没有 embeddable 的 `._pth` 限制；对 3.12 的二进制 wheel（faiss、silk-python 等）覆盖最好。`pyproject.toml` 要求 `>=3.12`。
- 体积预期 1 GB 上下（faiss-cpu、pandas、cryptography、markitdown、reportlab 等）；介质建议 exFAT/NTFS、16 GB 起。

## 四、验证清单

- [ ] `launch.cmd` 在非固定盘符（模拟 U 盘路径）下启动，WebUI 6185 可访问
- [ ] 全部数据（db、config、logs、site-packages）落在包内 `data/`
- [ ] 宿主机 `~/.astrbot` 不再出现（metrics 修复后）
- [ ] 拷贝到另一盘符目录仍可启动（重定位验证）

## 五、后续可回馈上游的点

1. metrics `installation_id` 移到 data 目录（本分支已做，见 `astrbot/core/utils/metrics.py`）。
2. `get_astrbot_system_tmp_path()` 支持 env 覆盖（便携场景更优雅，当前靠 TMP 重定向实现）。
