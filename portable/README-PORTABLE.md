# AstrBot Portable — 使用说明

这是一个**免安装、即插即用**的 AstrBot 便携版：整个文件夹拷入 U 盘 / 移动硬盘即可在任意 Windows 电脑上运行，不在宿主机留下任何持久文件。

## 快速开始

1. 将整个文件夹放入任意可写存储介质（U 盘、移动硬盘、本地任意目录均可）。
2. 双击 **`launch.cmd`**。
3. 看到启动横幅后，用浏览器打开 **http://127.0.0.1:6185** 进入 WebUI 管理界面。

> Linux / macOS 上运行 `./launch.sh`（需同架构的便携运行时，本包默认内含 Windows 运行时）。

## 目录结构

```
AstrBot-Portable/
├── python/            内置 Python 运行时 + 全部核心依赖（无需本机安装 Python）
├── astrbot/           AstrBot 程序本体
├── main.py            入口
├── data/              ★ 全部运行数据都在这里
│   ├── cmd_config.json      主配置（含 WebUI 账号、Provider key 等）
│   ├── data_v4.db           SQLite 数据库（会话、消息记录等）
│   ├── dist/                WebUI 前端资源（已预置，离线可用）
│   ├── plugins/             已安装插件
│   ├── site-packages/       插件依赖（pip 自动装到这里）
│   ├── logs/                日志
│   └── temp/system/         临时文件（重定向，见下）
├── launch.cmd         Windows 启动器
├── launch.sh          Linux/macOS 启动器
└── README-PORTABLE.md 本文件
```

## 便携性说明

- **动态盘符**：启动器按自身位置解析路径，换盘符、换电脑、换挂载点都不需要任何修改。
- **零宿主机残留**：所有配置、数据库、日志、插件、临时文件都写入本文件夹内的 `data/`。拔下 U 盘后宿主机不留任何 AstrBot 数据。
- **拔插须知**：先在控制台按 `Ctrl+C` 停止，再拔出 U 盘，避免 SQLite 数据库写入中断。

## 可选开关（环境变量）

在运行 `launch.cmd` 之前 `set` 即可：

| 变量 | 效果 |
|---|---|
| `ASTRBOT_PORTABLE_USE_SYSTEM_TMP=1` | 临时文件改用宿主机系统 temp（插件安装依赖更快，但会在宿主机留下临时文件） |
| `ASTRBOT_DISABLE_METRICS=1` | 关闭匿名指标上报 |

## 更新

直接在 WebUI「关于」页执行在线更新即可：程序文件会更新到本文件夹，新增核心依赖会自动安装进内置的 `python/`，插件照常安装到 `data/`。

## 已知限制

- 内置 Python 运行时约 1 GB+（含 faiss、pandas 等依赖），建议 U 盘 16 GB 起步，格式化为 **exFAT** 或 **NTFS**（FAT32 有 4 GB 单文件限制且性能差）。
- U 盘读写慢于本地磁盘，数据库与知识库操作会相应变慢；向量检索的临时文件因 faiss 兼容性限制固定写入系统盘 `C:\Windows\Temp`（瞬时文件，用后即删）。
- 首次启动若杀毒软件拦截便携 Python，属误报，添加信任即可。
