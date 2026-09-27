# 厨房完整操作教学 · 2026-09-27

先依用户补充在本地完成，取代首版仅展示正常流程的教学片，扩展到当前已实现的操作类别和厨房意外。首帧章节采用共用米色纸纹；开场仅写“饭店小游戏演示”。所有章节介绍与字幕底栏统一使用米色纸、深色文字；另生成同名 SRT。

后续用户要求清空 Demo 并把本次修改推送远程 main：Demo 的 7 个文件已全部删除，包括新版影片、字幕、封面、说明和此前短片。下文的影片交付及哈希是删除前的历史验收记录；录制入口、游戏修正、测试和 QA 证据保留。本轮改为提交并推送 main，远程验证须核对对应提交的 Actions。

## 游戏代码修正

`world/sink_faucet.gd` 的满锅水流从锅内开始，经过共享几何的前侧锅沿，再落向水槽；移动锅后路径随同锅的真实变换移动。移除从锅外低处开始的旧线条。地面积水仍由实际水槽满溢产生。

`world/pan_controller.gd` 将在水槽内倾倒和排掉的锅内水，转交 `receive_faucet_runoff`，保存锅→水槽→地面→排走的有限体积记录；原先这两条路径只清空锅内水量。`tests/test_kitchen_flood.gd` 验证锅沿起点、移动锅后的几何一致性，以及 400 ml 倾倒、350 ml 排水的守恒。

## 内容覆盖

1. 准备期、柜格与架子翻层、TAB 分类和搜索、有限库存、未加工食材放回。
2. 拿取、拖放、Q 放下、G 投掷、E 工位操作、手持丢弃与空手清台、暂停/帮助与声音。
3. 刀柄抓取、压切、R 与滚轮旋刀、交叉切块、同批搬运、甩锅、两次敲蛋。
4. 营业、客人纸条和聊天、正常加热、大火/中火/关火、核心熟度和余热。
5. 撒粉、倾倒、挤酱、木铲搅拌、黑铲翻面、木勺承托/舀取/滚轮倾斜、黄油融化和芝士软化。
6. 拖动整盘、抬锅离炉、A/D 与滚轮旋锅、右键重力倾锅装盘、整批/单批装盘、盘中摆放和旋转、有限成品淋酱、切换酱瓶与清酱。
7. 拍摄真实料理、出菜、顾客偏好/焦糊反馈、收入、回信与提前收班结算。
8. DIY 预写材料和做法、玩家手写菜名、玩家涂鸦配图、橡皮擦、保存重开；实拍照片菜谱、点赞与翻页、单页 HTML 分享、JSON 导出/导入及同 ID 去重。
9. 从示范菜谱开始，真实取材、切配、接水、煮面、盛汤完成跟做引导；提示由食材状态推进。
10. 锅与水龙头搬动/开关、锅盖座合/揭盖、煮汤、有限汤量盛入碗、汤倒回锅、原料理回锅。
11. 盖沿预警/颤动、揭盖泄汽、加盖摇锅、积汽顶飞锅盖并自然落地、食物烧焦/翻面露焦色/烟、烧糊料理的实际顾客反馈。
12. 1500 ml 满锅从锅沿溢水、水槽满溢、厨房持续涨水直至淹满、关闭把手、连续排水、单独倒掉锅内保留水；有限调料满锅溢出，海绵擦台面、湿抹布清锅及冲洗。
13. 硬闹钟不可切、软袜子实际切块、香水倾倒和牙膏有限挤出、奇物混合/选择批次装盘/评价。
14. 原生纸艺照片移动/缩放/旋转、剪刀裁切/恢复、复制/层级/删除/撤销/重做、胶带颜色/长宽、图片导入、保持实际料理状态的材料贴纸、文字再次编辑、不同笔宽、发布与重新编辑。

“完整”指当前实现的操作类别；没有把全部 104 种库存逐个做一餐，也不宣称尚未实现的三维流体、城镇等功能。

## 录制方法与边界

入口 `tests/capture_complete_kitchen.gd` 扩展首版真实操作脚本。交付片采用同一条干净录像的正常营业与收班结算，中间插入另一录次的独立准备期实验和原生米色收班章节页；前后的实际营业收入一致。实验的 3 餐不合并到主线账单。菜谱文件是各录次创建的真实示范作品。存档与顾客信件只写随机临时目录，不动日常玩家作品。

所有食物、热史、切面、熟度、焦糊、压力、锅盖飞行、水量、残留、摆盘与照片由生产实现生成；不向它们注入演示数值。主要等待段画面注明 2/4/6 倍速；再次积汽的短等待用 5 倍时间步，同名字幕文件补充注明。控件由自动操作触发，不冒充人工鼠标自由试玩或真实系统中文输入法验收。

macOS 录制宿主切换焦点和原生鼠标漂移会干扰合成手势。`tests/recording_focus_isolation.gd` 仅在录制实例中编译生产脚本的内存副本，把鼠标轮询指向同一合成输入光标，并隔离宿主失焦及临时离开场景树的清理回调；已有状态、原生物理体、输入处理和绘制均保留。普通游戏/回归仍使用原文件，其失焦暂停和退出清理行为不改变。该适配不作为平台真实输入测试。

首录在临时移除厨房时清理了锅盖绘图节点，收尾出现脚本错误；该收尾未纳入交付。修正录制适配器后，验证了原锅盖节点、盖合状态和音频资源的移除/重入，并录得无错误的正常营业及结算。原始错误日志保留于 `capture.log`，采用区段见 `capture-validation.json`。

`tools/record_complete_kitchen.py` 临时设置 Movie Maker 的 1352×852 / 24 fps 尺寸，初始化后恢复普通窗口配置。验收保留全部实际 MJPEG 帧和 PCM；成片剪去开头 15 个启动/淡入帧（0.625 秒），音轨按相同时间裁切，SRT 同步换算。之后用系统 AVFoundation 编为 H.264/AAC；音频仅作统一增益和首尾短淡化，不加入音乐、口播或生成音效。二维流体、压力和材质仍属于游戏近似。

## 验证记录

游戏生产代码最后修改后，完整共享入口 `tools/run_checks.py` 通过：44/44 Godot 回归、工程导入、120 帧启动与录音审计，0 项失败。证据 `qa/20260927-complete-kitchen/checks/summary.json`。成片采用正常营业/结算的 91 项断言和实验区段的 235 项断言，共 326 项；采用的玩法区段均无脚本/引擎错误。拼接边界、原生帧数、成片完整解码及抽帧结果在同目录 README 记录。

## 重录

修正后的全流程入口支持单次录制。本次交付采用剪辑；精确区段保存在 `capture-validation.json`：正常营业/结算来自 `ending` 模式，实验来自首录的无错误区段，收班纸页来自 `tests/capture_settlement_card.gd`。

```sh
python3 prototypes/100-restaurant/tools/record_complete_kitchen.py --godot /opt/homebrew/bin/godot --movie /private/tmp/complete-kitchen.avi --evidence /absolute/qa/video --log /absolute/qa/capture.log
python3 prototypes/100-restaurant/tools/extract_godot_avi.py /private/tmp/complete-kitchen.avi /private/tmp/complete-frames
swift prototypes/100-restaurant/tools/encode_godot_movie.swift /private/tmp/complete-frames /private/tmp/complete-silent.mp4 24 4000000 15
python3 prototypes/100-restaurant/tools/prepare_player_tutorial.py /private/tmp/complete-frames/audio.wav /private/tmp/complete-audio.wav /absolute/qa Demo 15
swift prototypes/100-restaurant/tools/mux_godot_movie.swift /private/tmp/complete-silent.mp4 /private/tmp/complete-audio.wav Demo/厨房游戏全流程演示.mp4
swift prototypes/100-restaurant/tools/verify_player_tutorial.swift Demo/厨房游戏全流程演示.mp4 /absolute/qa /absolute/qa/video/timeline.json 15
```

验收需要原生 GPU 与媒体编码权限。实际音画完整解码不冒充人耳试听或对所有设备/自由组合的人工验收。重录命令可重新生成影片；目前 Demo 已按后续要求清空。
