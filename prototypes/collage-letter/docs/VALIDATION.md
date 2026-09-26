# 最终验证 · 2026-09-27

本次针对拼贴优先的演示、实物书桌、材料阅读、纸片操作、封信／漂流瓶流程及旧存档迁移进行实际 Godot 验证。下面仅列本次可核对的结果，不将旧版日志当成新版全量测试。

## 运行结果

独立项目使用 Godot 4.5.1 Compatibility / NVIDIA GPU；主游戏使用 Godot 4.7.2。工作区 outputs/flat-depth-qa 保留以下日志，13 项独立游戏检查均 PASS，未出现 SCRIPT ERROR、ERROR 或退出资源泄漏警告。

| 日志 | 覆盖内容 |
| --- | --- |
| direct_workbench_test-polish.log | 打字机真实按键、剪字纸、替换与撤回；四角／边缘／旋转命中；3 种窗口；纯拼贴可寄 |
| ui_layout_test-polish.log | 中英文 × 3 窗口 × 8 工具，48 组控件尺寸及重叠检查 |
| office_book_test-polish.log | 素材本展开、前后翻页和纸声、百叶窗状态保存恢复 |
| writing_system_test-polish.log | 原生编辑器提交、Unicode 字素队列、快速编辑、分页、重播、跳过与 Finish |
| library_test-polish.log | 678 条目逐项渲染／裁剪，图像哈希全部不同；中文印刷素材比例 0.80049875 |
| letter_paper_test-polish.log | 24 款 A4 底纸、边界及存档 |
| paper_depth_test-polish.log | 层叠支撑高度、移出与放回、旋转／镜像后的光向、拿起落下和透明边缘 |
| paint_dialogue_test-polish.log | 对话、追问、记录和附件；水粉的素材裁剪／纸面范围；胶水不锁定纸片 |
| incoming_bottle_test-polish.log | 4 种窗口高度；拿瓶、拔塞、抛放／再拾起、左右倾倒、自动展平与拔塞录音 |
| bottle_ritual_test-polish.log | 卷纸、拔塞、从瓶口插入、塞回、入海、保存和失败重试 |
| sea_example_test-polish.log | 原信阅读、同布局回信预览、独立可编辑示例、完整装瓶与海浪、恢复原草稿 |
| desk_lighting_test-polish.log | 昼夜／黄昏／雨天，百叶条纹与开窗光斑、动画变化；原有时间不被改写 |
| demo_transition_test-polish.log | 示例只填一次；下一任务及重启保持空白；旧素材版本、旧纸面位置只迁移一次；先翻开再放大 |

server-polish.log：9 项服务端测试 PASS，包括真实 HTTP 双玩家、完整 Unicode 正文与资料往返、发一回一、重复请求／并发及重启保存。

host-current.log：主游戏实际 GPU 子视口 PASS，抽样 24 张材料、宿主布局、声音和独立存档；观景台及玩家相片追加项的 ID 与来源可读性检查。基础库 678 张全量验证来自独立项目，上述主游戏复验不声称重新全量裁剪 678 张。

tour-final-rehearsal.log：完整交互预演 PASS。正式录制 outputs/Solmere-Demo-20260927/recording-final.log 也为 DEMO_TOUR: PASS failures=0，包含折信、部分入封后自动落位、合翻盖、划火柴、点烛、勺内融蜡、倒蜡、压章、信箱，及收瓶／回信／放流和空白下一任务。

## 视频与可见画面

最终视频为引擎 Movie Maker 实际运行画面和游戏音轨，不是预渲染 UI 模型。1440×900、30 fps、7028 帧、3 分 54.27 秒；H.264 + AAC 双声道 48 kHz。解码检查通过；音轨平均 -41.8 dB、峰值 -5.0 dB，保留安静停顿而非全程背景音乐。录制使用测试专属下午光照，不改变玩家或主世界的时间。

已检查视频抽帧九宫格、最终桌面、回信、封信及下一任务画面。Windows 新版可玩窗口已实际打开、查看，点击进入取瓶并返回；其他精确鼠标行为由上述真实 Godot InputEvent 回归覆盖。系统显示缩放与多个并行游戏窗口限制了更多原生 UI 注入检查，因此不将程序化测试描述成人工全流程试玩。

桌面视频：Solmere_完整试玩演示_20260927.mp4。SHA-256：98de5f5e07f8765d90f2ae5400c8a933518fb42fe2aed3a157ba8087cc87b2e1，与录制目录中的 MP4 一致。

## 便携包与边界

outputs/portable-final-qa 的资源重新导入及素材本 GPU 检查均 PASS。发行包仅包含源码、运行时、许可证及发行元数据，不含私人草稿、身份、测试数据库或引擎缓存；VERSION.txt 与 source-manifest.json 记录实际提交和逐文件 SHA-256。

普通入口保持空白／恢复个人作品；新示例使用独立的 Solmere-Showcase-20260927 存档，旧示例存档不被覆盖。旧作品中的文字纸片继续使用旧素材版本，不因经典摘抄库更新而改变。

没有公网部署或独立第三方联机测试；未人工验证 Windows 中文候选窗的完整交互、所有声卡的听感。字形为完整 Unicode 字素渐显加正常比例的悬笔跟随，不是每个汉字的真实笔顺描摹。未完整试玩 Kind Words / Paper Sky，未提取其资产。场景生成插画、原生 2D 对象及公共领域／开放许可材料的边界见各自来源记录。
