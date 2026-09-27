# 厨房文字排版 QA · 2026-09-27

使用统一的区块标题、留白和圆点列表落实用户反馈；长说明和反馈内容可滚动，关键操作保留在滚动区外。

| 页面 | 实际截图 |
| --- | --- |
| 欢迎 | [正常窗口](intro.png)、[小窗口](small-intro.png) |
| 操作说明 | [开头](help.png)、[末尾](help-end.png)、[小窗口开头](small-help.png)、[小窗口末尾](small-help-end.png) |
| 展开订单 | [正常窗口](order.png)、[小窗口](small-order.png) |
| 菜谱 | [正常窗口](recipe.png)、[小窗口](small-recipe.png) |
| 顾客反馈 | [开头](feedback.png)、[末尾](feedback-end.png)、[小窗口开头](small-feedback.png)、[小窗口末尾](small-feedback-end.png) |
| 回信 | [列表](letters.png) |
| 收班 | [正常窗口](receipt.png)、[小窗口](small-receipt.png) |

[capture.log](capture.log) 有最终 17 次成功 PNG 保存、每张逻辑面板边界及像素尺寸，含 `TEXT_LAYOUT_CAPTURES_COMPLETE`，无脚本错误。Godot 4.7.2、Apple M4、OpenGL 4.1 Metal Compatibility。逻辑视口为 1600×946；macOS 实际 PNG 为 1440×851 和 1150×680。截图由生产页面直接渲染，未拼接界面；捕获子类隔离了玩家菜谱和反馈存档。

首轮完整入口 [checks/summary.json](checks/summary.json) 为 44/44 Godot 脚本、导入、120 帧启动和录音审计通过。最后的字号、圆点首行对齐和提示文案微调以后，再次运行同一完整入口，最终 [final-checks/summary.json](final-checks/summary.json) 为 **PASS：44/44 Godot 脚本通过，0 失败步骤**；工程导入、120 帧启动与录音审计均通过。最终相关源码哈希见 [source-sha256.json](source-sha256.json)。

本轮没有推送、远程 CI 核验、Windows 重导出或重录教学视频。渲染和引擎回归证据不冒充完整系统鼠标人工试玩。范围与实现见 [排版说明](../../docs/TEXT_LAYOUT_20260927.md)。
