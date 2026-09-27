# 100饭店工程约束

2026-09-28 物理重构：以 `docs/PHYSICS_RECONSTRUCTION_20260927.md` 为当前动力学说明。锅、锅盖、食材和翻拌工具使用原生力/接触，不恢复逐帧瞬移、冻结整批搬运或预定锅盖飞行轨迹。固定菜板继续生效，切片按独立刚体取放；旧“整批入锅”约束由实体锅铲收拢替代。水量归 `water_runoff.gd` 管理；不允许旁路直接改地面水量。当前共享清单 45 个入口，最终整套检查、可运行包及系统鼠标检查仍需完成后再推送。

2026-09-26 CI 验证：本地与 GitHub Actions 共用 `tools/run_checks.py` 和 `tools/regression_suite.json`（当前 43 个 Godot 回归入口）；`tools/test.ps1` 仅转发到同一入口。厨房修改推送前必须运行完整入口，定向检查不能代替完整通过。入口会导入工程、检查 120 帧启动、执行所有回归及音频审计，并保留每步日志与 summary.json。新增回归须登记到清单；布局目标改变时同步审查旧布局断言，不能为了旧断言恢复已被用户指出的遮挡。推送后核对本次提交对应的 Actions 运行；仅本地通过不能称为远程 CI 已通过。命令与失败取证见 `docs/CI_CHECKS.md`。

2026-09-25 最新食材素材状态：此前待处理的 13 张黑底团队 JPEG 已按原字节保留、通过运行时透明适配进入共用食材入口；另有 4 张独立标记的原创补画。目录现为 106 个定义、104 个可用。来源和实际验证见 `docs/TEAM_ART_INTEGRATION_20260925.md`；此前“等待透明图或去底授权”是历史状态。洋葱/西葫芦身份与彩椒分组仍可按用户答复调整，不能把暂定识别冒充已确认。

2026-09-25 空间复查：锅口/前沿/抓取共用 pan_geometry；固体入锅不得关闭彼此接触。绘制深度与透明轮廓选取同步，搬运代理必须逐帧同步热/挂酱状态。台面十件调料尺寸使用 SpriteLibrary.physical_art_scale；盘面装饰酱位于食材下，照片与编辑器同源。内部余量和物体快照禁止逐步舍入或用一毫克保底创造质量。改动前读 docs/VISUAL_SPATIAL_AUDIT_20260925.md，运行 tests/test_visual_spatial_consistency.gd 与受影响回归，GPU 检查真实遮挡，实际鼠标验证取物/落锅/切配/摆盘。

2026-09-25 锅内反应由 `cooking_reactions.gd` 在固定物理步唯一更新，实际有 thermal 的食材不能再用 session 秒数加热。修改前读 `docs/THERMAL_REACTIONS_20260925.md`。酱汁/木勺/锅残留/切割必须转移质量及组成，不增加无限覆盖层；两面温度、核心、含水量和相变历史需传到摆盘、菜谱与 DIY。跑 thermal/reaction kitchen、存档、录音及完整回归；旧测试推进真实锅温，不直接补 heat 数。JSON 数字导入会变 float，StringName 键序列化为 string，验证按实际 JSON 值而非内部 Variant 类型。自动化不能冒称人耳听感、CFD 或完整三维仿真。

2026-09-25 订单与 DIY 使用真实纸纹及 OFL WenKai 手写字体；编辑/静态文字共用原生 TextEdit 排版，不能退回独立表单或按钮堆。改动前读 `docs/PAPER_CRAFT_20260925.md`，运行 `tests/test_craft_workbench.gd` 及相关存档/GUI 回归。草稿按作品 ID 隔离、仅当次进程保留；永久保存保留可编辑图层；仅写做法也能存 DIY，不伪造烹饪记录。IME 候选窗属于系统，合成输入测试不能冒充真实 IME 验收。字体许可随源码和 Windows 包保留，生成纸纹的完整提示词与哈希不得遗失。

2026-09-25 材质物理：97 个定义显式映射到 `data/material_response.json`，由 Godot 原生刚体 + MIT GodotSpringDamper 响应，不再使用统一回弹截断。改动前读 `docs/MATERIAL_PHYSICS_20260925.md`，跑 `tests/test_material_physics.gd` 及受影响回归。保留第三方 LICENSE/NOTICE 与固定来源提交；不能将弹簧称作流体引擎。瓶重必须等于包装自重加实际余量，出料、极小剂量、空瓶及溢出守恒；软瓶局部形变和喷口变换同源。所有参数为游戏近似，不宣称实验常数或绝对仿真。

2026-09-25 用户补充的素材适配要求：如采用 Little Chef 或其他第三方食材美术，必须先以团队现有手绘食材为标准改造，再接入游戏。统一轮廓、笔触、色板、明暗、视角与比例，不能只换颜色就宣称画风统一。整件、切片、切块、受热、摆盘和菜谱里的同一食材须保持一致；在真实厨房中与团队原画并排检查。保留原图及派生版本的来源、许可和修改记录，不覆盖团队手绘原件。具体验收见 `docs/ART_DIRECTION.md` 的“外部素材改造与接入”节。

2026-09-25 切配/清锅/分享更新：用户已明确授权以团队原画生成切片和切块派生素材。`assets/cut_states/` 的生成图必须与 untouched 手绘原图区分；来源、提示词、哈希见 `docs/CUT_ART_GENERATION_20260925.md`，42 个有效切面 + 6 个备用甜椒，不能宣称覆盖全部食物或原画替换已经完成。真实多边形与质量决定部分切割，图只补充外观。改动前读 `docs/CUT_CLEAN_SHARE_20260925.md`，定向跑 `tests/test_cut_clean_share.gd`。抹布是有限残味质量传递链的一部分，清理台面不能偷偷洗净锅。单页分享不得导出其他私人菜谱，HTML 必须转义文字。Little Chef 作者包禁止原素材再分发，未纳入公开仓库；其他候选见 `docs/ASSET_RESEARCH_20260925.md`。

追加番茄原图状态见 `docs/TOMATO_SOURCE_20260925.md`：白底 RGB JPG 原样归档；用户于 2026-09-26 明确允许程序仅去白底，现以 RGB 完全保留的透明派生 PNG 接入。imagegen 去底候选因改变笔触而未采用；派生图不能冒充未修改原图。

第二批素材见 `docs/HANDDRAWN_BATCH2_20260925.md`。当前已接入 19 张原生透明手绘 PNG；后 6 张均为奇物，牙膏是有限余量软管。第二批前 13 张黑底 JPEG 仅原样归档于 `docs/supplied_assets/20260925-batch2/`，等待透明原图或用户允许程序去黑底，不能声称它们已完成替换。冰箱/奇物架支持翻层，共享有限库存；验证追加 `tests/test_shelf_pages.gd`。下面 13 张记录指第一批历史范围。

2026-09-25 用户手绘素材为必须使用的原作。修改素材或物品映射前读 `docs/HANDDRAWN_ASSETS_20260925.md`；13 张 PNG 与 `modules/restaurant/assets/handdrawn_manifest.json` 保持来源及 SHA-256 可核验，不用旧图集覆盖、重绘或清除原生透明边缘。世界、切片、摆盘与菜谱共用入口；专架物品必须能取用并扣除库存。验证使用 `tests/test_handdrawn_assets.gd`（可带 GPU 输出前缀）、`tests/test_seasoning.gd` 和完整流程回归。

**2026-09-25 当前三大主参考：Little Chef、Venba、Cooking Simulator（烹饪模拟器）。** 分工：Little Chef 负责整体游玩、物件交互与 UI；Venba 负责烹饪过程、菜谱与逐步引导；Cooking Simulator 负责仿真操作、物理反馈、食物状态与声音逻辑。具体实施前先读 `docs/CORE_EXPERIENCE_REFERENCE.md` 顶部的当前生效指导；旧文档里 Good Pizza 为最高参考的排序已失效。沿用当前第一人称 2D 工程和用户确认的厨房图，不因参考确认更换引擎或转成 3D。

菜谱与引导改动前读 `docs/RECIPE_GUIDE_20260925.md`。书架和展开页保持同源；步骤从真实切配、熟度和装盘推进，不能由计时或确认按钮伪造。历史顺序缺失时明示状态推断。验证使用 `tests/test_recipe_guide.gd`、`tests/test_recipe_diy.gd` 和 GPU `tests/capture_recipe_guide.gd`。

2026-09-25 最新确认：以 `docs/kitchen_layout_20260925.jpg` 为最终布局参考（此前图为 `docs/kitchen_reference_20260925.jpg`）替换场景，见 `docs/REFERENCE_KITCHEN_20260925.md`。Letter 工作台文件是误发，不适用于本工程。新图的可移动道具必须与静态环境分层，切片、加热和摆盘状态不能因美术更换而重置。验证新增 `tests/test_slice_cooking_continuity.gd`，GPU 使用 `tests/capture_cooking_states.gd`。

保留现有 Godot 4.7.2 工程和 `modules/restaurant` 可接入结构。最高层体验与视觉指导保存在 [`docs/CORE_EXPERIENCE_REFERENCE.md`](docs/CORE_EXPERIENCE_REFERENCE.md)；完整原始规格保存在 [`docs/COOKING_FULL_SPEC.md`](docs/COOKING_FULL_SPEC.md)，原件保存在 `docs/COOKING_FULL_SPEC.docx`。实施任何厨房空间、食材、工具、液体、摆盘、菜谱、顾客、菜单、音频或存档改动前，必须先读取最高层指导及完整规格中的对应章节。`docs/HIGH_FIDELITY_INTERACTION_SPEC.md` 仅是执行摘要，不能替代上述文档。

关键约束：统一原创 2D 画风；食材状态连续且质量/液体数量可追踪；不放鱼；不在可交互层放置无效入口；不得以预制成品图替换实际切块、锅内状态、摆盘或照片；二维混色、流体和合成拟音必须标为近似。

验证至少包括：Godot `--headless --path . --quit-after 120` 无脚本错误、受影响模块的定向测试、`tests/test_integration.gd`、实际启动当前工程。逐项状态写入 `docs/COOKING_PROGRESS.md`，运行结果与限制写入 `docs/VALIDATION.md`，并按“已实现并验证 / 已实现但未验证 / 近似实现 / 尚未实现”分类。

本轮补充：柜格取物须扣除可见库存，调料台不放米饭；菜谱外侧与展开页共用渲染源；锅溢出按体积而不是小份数量。实施与验证见 docs/STOCK_RECIPE_PAN_20260925.md。

2026-09-25 最新操作修正：菜板固定在右侧备菜区，取消拖动，覆盖旧文档中可拖动菜板的要求；保留刀切及切块整批入锅。验证使用 tests/test_cut_batch_stability.gd 和 tests/test_knife_drag.gd，结果记录在 docs/VALIDATION.md。

音频最新要求：禁止程序生成拟音；仅使用许可核验可商用的外部录音，优先 CC0。当前音频来源、加工、缺口和验证入口在 docs/AUDIO.md；assets/audio/recorded/manifest.json 必须逐文件记录来源与哈希。新素材不得仅因写着“免费”就纳入。使用 tests/test_recorded_audio.gd 验证事件、tools/audit_recorded_audio.py 验证素材；技术测试不能冒充人耳试听。
