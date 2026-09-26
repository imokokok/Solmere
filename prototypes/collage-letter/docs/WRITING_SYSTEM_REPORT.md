# 写信系统交付报告 · 2026-09-27

实现以拼贴为主，输入少量文字为辅。默认信空白，默认工具移动，准备好的示例单独保存；正常作品不被演示内容覆盖。

## 代码与替换

新增 `letter_input.gd`（原生输入与 IME 提交）、`letter_renderer.gd`（TextServer 字形排版、Unicode grapheme 事件队列、渲染与笔尖）、`letter_data.gd`（记录字段）、`letter_document.gd`（现有封装用动态纸面子视口）、`writing_controls.gd`（分页、偏好、回信原文）、`showcase_draft.gd`（独立拼贴示例）和 `writing_system_test.gd`、`demo_tour.gd`。

主场景仍是现有 Main。`main.gd` 连接输入、纸片分页、Finish、存取与封装；`desk_drawers.gd` 提供辅助入口；`bottle_dock.gd` / `sea_example.gd` 共用阅读渲染；`audio_manager.gd` 提供限频录音池；`server/app.py` 保存完整正文与允许的元数据。宿主扩展镜像使用同一代码和既有 host_adapter，不覆盖宿主其他系统。

删除旧 `writing_pen.gd` 和旧写字测试；正文静态 Label 替换为字形渲染，移除旧行数上限、背胶完成门槛、侧栏重复缩放按钮与预览重复工具。写实素材本的闭合／打开贴图均移除，使用连续的原生 2D 本子形体。

## 输入、渲染和 Finish

TextEdit 负责完整输入 String、撤销、选区和原生提交，隐藏原生外观；LetterRenderer 根据最后已接受输入生成有序插入、删除和换行事件。组合附加符、家庭 emoji、旗帜使用 grapheme 边界；字体排版和光标来自 TextParagraph / TextServer 的真实 advance 与 caret rect，不使用固定字宽。

字母、空格、标点、换行的时长不同，积压时加速。删除淡出，落墨轻微渐显；约 118 像素长的原生 2D 钢笔平滑跟随、换行抬起，空闲减弱。减少动态效果不改变文本。六段真实铅笔录音随机选择、音调／音量轻变且限频，空格静音；擦写、翻纸和轻敲分离。

满页停止视觉队列并提示手动下一页，原始输入已保存，不会因等待而丢字。后页有纸片时，即使删空全文也保留该页。Finish 锁住编辑、排空队列、停顿并抬笔，随后进入既有折叠／装瓶流程。折叠与入封用包含文本和拼贴的 live viewport；保存的原作是 String 和独立对象，PNG 仅供缩略图／分享预览。

## 数据与接口

保留 letter_id、sender、recipient、full_text、created_time、letter_type、reply_to、completed、sealed、sent，以及 author_id、reply_chain_id、required_keywords、forbidden_keywords、tone。`current_letter_data()` 与 `letter_puzzle_payload()` 供剧情／谜题读取；`play_letter_animation(String)`、renderer.skip() 提供阅读重播。它们是数据接口，未虚构一个已经上线的剧情判定器。

草稿保存页码、文字、每页拼贴和偏好。版本 4 兼容旧版存档；纸面尺寸迁移只执行一次。旧文字纸片保留旧素材版本，更新经典库不会改写旧作品。示例完成标记独立保存，下一任务重启后不会重新填入示例。END 归档完整寄出记录；当前已完成信件重新打开时直接恢复文字与作品。服务端保存原始正文（含空白和 Unicode），最多12000字符；超过时明确拒绝而非截短。网络作品继续兼容既有预览协议，当前不会把可编辑素材文件传给其他玩家。

## 资产和实际边界

Xiaolai 手写字体及 OFL 已附；六段 pen_write、pen_erase、ocean-waves 录音及 CC0 来源已附。paper_move 与 pen_tap 复用已有纸声／轻敲录音；若需要每个细小动作独立录制、更多纸质擦写或角色专属书写声，仍需后续资产。字形以完整 grapheme 渐显，没有可靠笔顺数据，因此不是每个汉字真实笔画轨迹。文本仍可编辑、保存、重播。

未人工验证 Windows 中文候选窗的完整交互、所有声卡听感或公网部署；已测试提交后的中英文、粘贴、组合字符、快速增删、手动分页、保存恢复、完成与实体封装。录屏为真实引擎输入事件驱动，含实际游戏音轨，详情与错误情况见 VALIDATION.md。
