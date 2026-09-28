# Solmere · 五日旅程

Godot 4.7.2 · 海边小镇探索、双主角的五日生活与彼此留下的痕迹。

最新主体机制按用户确认的《主体机制-系统设计》接入：[日程与生活机制说明](docs/DAILY_LIFE_SYSTEM.md)。A 的专属随身物品是录音机，B 的专属随身物品是本子，两者入口互不混用。B 打开本子先看「今日日程」：实际时间、地点、事项、状态及下一项安排；顶部「今天的计划」仍可管理生活状态、已知活动、交通、班次及人物认识。计划不会自动执行；厨房工资在真实出餐后结算。现有美术、背景与五日故事保留。

此前架构按《架构调整说明(1)》校正，详见[逐项复核与修正](docs/qa/architecture_alignment_20260924.md)。日程粒度、工作结算与人物认可方式以本轮主体机制为准；同栋住处仍共用门口和信箱，旅居申请分别检查本人 12 位居民认可。

五天主流程沿用用户确认的《Solmere_Codex_5Day_Rebuild_CN》。保留现有美术、摄影录音、交易与可用小游戏。旧七日申请制不再控制推进。[五日交付报告](docs/FIVE_DAY_REBUILD_REPORT.md)说明实际挂载、存档和验证范围；其他历史文档中的七日要求不再代表当前流程。

第二阶段按《Solmere_GameplayFlow_Feedback_Guidance_CN》接入持续生活物件、分级引导和第五天真实时段。[第二阶段报告](docs/GAMEPLAY_FLOW_GUIDANCE_REPORT.md)保留当时的实施记录；其中旧时间形状以最新架构复核为准。

## 启动

用 Godot 4.7.2 打开 project.godot 后运行并选择新游戏。新版窗口标题为「Solmere · 五日旅程」。

首次克隆后先运行 `python tools/import_solmere_resources.py`，从四位作者的官方免费入口安装选用的 84 个美术/音频文件，再由 Godot 导入。无需第三方 Python 库。用 `python tools/import_solmere_resources.py --verify-only` 检查安装完整性。受原文件再分发限制的媒体在 `art/licensed/`，不作为公开源码附件上传；完整可玩打包版包含这些游戏内资源，离线运行不需要 Python 或联网。

本轮实际改造、来源与验收见 [资源接入交付](docs/resource_integration_delivery_20260924.md)。这是素材/UI/音频接入，不代表候选文档中所有新增玩法均已完成。

2026-09-26 新增的 CC0 手绘图标和音效随源码提供；需要恢复时运行 `python tools/import_open_ui.py`，会核对固定版本和逐文件 SHA-256。MIT 代码适配、真实素材入口、回归范围和已知限制见 [本轮复查](docs/qa/open_source_polish_20260926.md)。

## 操作

A / D 走动；W 交谈；E 与物件互动；Space 继续对话；C 相机；A 角色按 R 使用录音机，B 角色按 J 打开随身本和今日日程；G 相册；Tab 地图；B / I 随身物品；F 档案。Esc 退出当前对话或逐层收起。第五天见面后，通过日程页面选择角色，切换后随身物品同步更新。其他实际提示读取 Input Map。

Day 1 A 制作音乐；Day 2 B 完成餐厅工作；Day 3 A 制作拼贴信；Day 4 B 下棋并约定见面；Day 5 两人见面后可切换视角。前两天完成主活动即可自主回家休息；第三、四天还需实际查看生活物件及相关交谈。前四天界面不提前揭示 A/B 身份。纸页、居民留字及自由拼贴均为可选记录，不需要提交作品集或集齐认可才能推进。

Day 4 的棋类小游戏可选围棋、五子棋、国际象棋和相遇棋。[四种棋完整流程演示](demo/Solmere_Chess_Minigame_Full_Walkthrough_CN.mp4)展示规则页、实际行棋、结算与返回选择；相遇棋包含选人、布阵和完整对局。

Day 2 的厨房流程是选材、按所选方式备料、下锅、翻拌、尝味、分次调味、装盘、出餐及公共菜谱。菜谱默认收起，操作台上方按当前步骤显示简短提示，需要时点右上角「查看菜谱」。切配可拖动菜刀划过案板上的目标食材，也可点击案板；切、撕、挤、倒和整理有各自的动作与音效。处理方式会延续到锅、盘和菜谱。每样食材各自记录熟度、焦化与下锅顺序，翻拌会改变锅内位置；尝味时可继续加热，也可分次加入至多三次海盐、黑胡椒、芥末、番茄酱或香草。三只分食小碟各有同一锅的三样食材。实际熟度、调味与装盘会影响出餐评价和店主回应。[厨房细化与验收记录](docs/qa/kitchen_feedback_upgrade_20260924.md)说明测试范围；[100饭店优化后的完整做饭视频](demo/100Restaurant_Optimized_Full_Cooking_20260925_CN.mp4)展示当前原型的取材、手动切片切块、敲蛋、加热调味、装盘与出餐评价，含游戏录制音轨。

## 保存与检查

A/B 的钱、物品、关系、笔记和草稿分别保存；公共作品与小镇状态共享。五日存档为 user://solmere_five_day.json 及另外两个槽，schema 7 是格式版本号。旧 solmere_save.json 保留并只读检测，不兼容时需新开五日旅程。实际照片和录音另存文件。测试使用 --isolated-save。请勿同时运行多个窗口写入同一正式存档。

[测试清单](TEST_CHECKLIST.md) · [全游戏细节复查](docs/qa/gameplay_detail_audit_20260924.md) · [机器结果](docs/FINAL_TEST_RESULTS.json) · [内容填写说明](CONTENT_WRITING_GUIDE.md) · [档案结构](RESIDENCY_CONTENT_SCHEMA.md)

旧版说明存于 docs/PRE_FINAL_README.md，仅供历史查询。

## 独立饭店原型（100饭店）

本次厨房原图改造和可运行源码位于 [`prototypes/100-restaurant`](prototypes/100-restaurant/README.md)，用 Godot 4.7.2 打开其中 `project.godot`。它包含连续切片、整批入锅、烹饪状态、装盘/拍照、菜谱和纸面顾客反馈；[本次说明](prototypes/100-restaurant/docs/REFERENCE_KITCHEN_20260925.md)列明验证与近似。独立原型不替换上文 Solmere 五日主流程的现有厨房。

2026-09-26：A 的右侧磁带图标贯穿街区、室内和小游戏，收起后仍可录音；B 无随身录音入口，可在唱片店使用明确标注的店内声音素材制作唱片。各角色的音频收藏独立。录制时显示现场预览和声音动态图，保存后回放声音图，不把当前街景冒充已录视频。录制、收藏与恢复说明见 [全局录音](prototypes/town-sound/GLOBAL_RECORDING.md)。
