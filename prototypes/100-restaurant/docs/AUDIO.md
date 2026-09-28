# 厨房实录音效库（更新至 2026-09-29）

现用 41 条外部 CC0 录音，剪辑为 58 个 WAV 片段，组织成 40 个素材分组。新增独立开壳声，改善油、水、撒粉及慢速翻炒的可听反馈，仍使用实际动作触发、限声和淡出。逐文件许可、作者、原始链接及哈希在 manifest.json 中保留。旧的生成脚本及 22 个生成 WAV 已移除。没有提取商业参考游戏音轨。

本轮录制直接采集 Godot 总线，48 kHz 双声道约 36.36 秒。16 个事件区段均检查非零输出，另检查静音段和 0 削波；录音夹具隔离切换桌面窗口引起的失焦静音，生产静音/恢复逻辑另有回归。见 [混音、审计和验收边界](../qa/20260929-precision/README.md)。客观音频检查不等同于人耳逐项听感已验收。

## 2026-09-26 锅盖爆锅声音更新

锅盖轻颤、放盖、顶飞和撞到支架分别使用独立片段；轻颤的接触相位、顶飞冲量和支架碰撞触发相应声音，轻回弹比首次碰撞更轻，使用独立声道叠加，保留第一声的金属余响；轻颤片段尚未结束时不反复重启。揭开热盖增加较低音量的泄压声，冷盖不凭空响汽。删除爆锅事件里与该动作无关的热锅下料声和重复开盖碰撞声；锅内真正的食材落锅事件仍由原有物理接触发声。

新增实录来源：[bowlingballout 的金属锅盖](https://freesound.org/people/bowlingballout/sounds/210100/)、[greenlinker 的合盖](https://freesound.org/people/greenlinker/sounds/757514/)、[wubitog 的空气泄压](https://freesound.org/people/wubitog/sounds/234782/)，页面均核验 CC0；空气泄压用作蒸汽音色近似，不宣称平底锅爆锅现场实录。短音按实际瞬态裁切、淡入淡出与增益匹配，保留来源和哈希。混音采用克制音量与 ±0.8% 音高差异，保持厨房温和的动作反馈。

实际声画预览及本次验证见 [爆锅动作与声音记录](LID_POLISH_20260926.md)。已验证事件、素材和非削波混音，未把自动测试当成人耳满意度验收。

## 许可和交接

每条源录音页面已核对为 **CC0 1.0**，允许商用、修改和再分发，无强制署名要求。[Creative Commons 官方许可说明](https://creativecommons.org/publicdomain/zero/1.0/)。这里仍保留作者和链接，便于合作方追踪资产；不要求玩家在游戏画面中署名，也不暗示作者为项目背书。

逐文件清单：`modules/restaurant/assets/audio/recorded/manifest.json`，含作者、页面、许可 URL、查询日期、下载 URL、原文件/页面/输出 SHA-256、剪辑区间、增益和格式。`audio_bank.json` 是运行时映射。

使用 Freesound 页面公开提供的 Ogg 预听文件，未下载需要登录的无损原件。这些是已有录音的有损版本，转成 WAV 不会恢复丢失的细节。处理仅为剪辑、单声道合并、去直流偏移、克制的增益调整、短音淡入淡出与循环接缝交叉渐变；没有合成噪声或程序生成音色。

## 操作与声音

| 实际状态 / 操作 | 录音与触发 |
| --- | --- |
| 热锅煎蛋 / 蔬菜 / 肉 | 根据在锅内且未装盘的实体和主料质量，分别选择煎蛋、黄油炒蔬菜、香肠煎炒录音；实际表面温度与含水量共同驱动强度，关火后余热仍可发声 |
| 油 | 倾倒时播放真实倒油录音；油附着食物影响干炒选择。干净油独自在锅中不凭空制造大声滋响 |
| 浓酱 | 读取实际液体与食物表面 composition_ml，按表面温度与实际酱量连续增加冒泡强度，与清水煮沸分开 |
| 水煮 | 与烹饪模型共用 80 ml 水量界线；在 92–100 的温度区间平滑增加细泡与沸腾录音强度（游戏压缩模型），冷水不会冒泡响，也不会同时播放干煎声 |
| 撒盐 / 撒胡椒粉 | 分别使用盐瓶摇撒和干调料瓶录音；持续按压且瓶中有余量才响 |
| 挤酱 / 倒液体 | 番茄酱瓶、普通液体、油分别取录音，音量跟随现有挤压力；松手、倒空、暂停、失焦即停 |
| 翻炒 / 搅拌 | 只由实际工具扫到食物触发；水中搅拌、沾酱、软面条、湿软料、干粒料分别选组；木勺/木铲和黑色铲分别叠加木/金属接触层 |
| 切菜 | 只在几何切割成功时播放，区分柔软/普通/硬蔬菜组；普通组有三条独立刀切变体 |
| 碰撞 / 落盘 | 实际落物碰撞区分容器、干粒料、普通食物；锅落台、盘子交付有对应录音 |
| 其他 | 水龙头出水、炉火、点火、服务铃、翻纸与擦拭都改为录音 |
| 翻锅 | 只有锅中食材被真实抛起时才叠加锅具移动声，锅落台仍用原锅具碰撞声 |
| 热锅下料 | 只有锅温达到 115°C、锅里没有大量水且食材有水分时，落锅短暂叠加蔬菜遇热油的录音；冷锅不响 |

同组多变体避免紧邻重复，音高变化限制在 ±1.5%。一次扫过大量切块按 180 ms 的共享接触窗口聚合，单组短音未结束不反复重启。每个播放器最多一条回放；最多八条循环通道，煎/浓酱/水煮互斥。不会一块食物就额外创建一个音源。暂停和静音保留现有界面行为；摆盘淋酱仅在实际发生时例外发声。

## 已验证与限制

- 已实现并验证：源页面 CC0 检查、37 条录音下载、52 个 WAV 解码/非静音/峰值/哈希/循环接缝审计，以及实际状态到音效的定向自动测试。测试日志与实际混音捕获见 `VALIDATION.md`。
- 已实现但未逐项人耳验收：所有录音已接入播放器，已生成真实 Godot 混音试听文件；环境底噪、音色自然程度、混音舒适度及每个循环的听感仍需人工确认。不能把无削波或测试通过称作“和现实完全一致”。
- 近似实现：食材分组与声音强度；新模型的表面/水温与含水量共同驱动反馈，参数未经实验标定。薄酱与浓酱尚未按黏度完整分档。软肉接触借用湿混合物录音，硬奇物借用锅具碰撞，擦台借用布擦玻璃，锅内金属接触借用金属厨具刮擦；保留来源真实名称，不冒充对应食材逐个实录。
- 具体缺口：牛肉/鸡肉分别在不同含水量下的翻炒近录；木勺与金属铲在不同浓度酱汁内的独立慢/快搅拌；不同硬奇物落钢锅的近录；湿海绵擦木桌；完整刀切软肉/番茄/叶菜录音；无损原始文件与最终人耳混音验收。对应操作使用上述明确列出的录音近似，没有回退到生成声音。

## 维护与验证方式

- 实施前读取完整规格第 19 章；只接许可明确可商用的源录音，首选 CC0，排除 NC/仅个人使用/条件相互矛盾的素材。
- 重建：安装 numpy、soundfile，运行 `python tools/import_recorded_audio.py --cache <工程外缓存目录>`。已有完整素材库时可加 `--append-only` 只导入 manifest 中尚无的来源。脚本逐条检查页面 CC0，再取公开预听；缓存保留原文件及页面。`python tools/audit_recorded_audio.py` 可离线验全部打包 WAV。
- 引擎测试：`Godot --headless --path . --script tests/test_recorded_audio.gd`，已纳入 `tools/test.ps1`。还需回归 seasoning、spatula、kitchen_interactions、recipe_diy、comfort_release、integration。
- 实际混音：不加 headless，运行 `Godot --path . --script tests/capture_recorded_audio.gd -- <输出绝对路径.wav>`。这是引擎混音输出，不是静态拼贴演示；状态由脚本设定，不冒充完整系统鼠标试玩。

## 逐条来源

以下每行均在下载当天由源页面核对 CC0；剪辑后所有文件都能反查 manifest。

| 源录音 | 作者 | 录音内容 |
| --- | --- | --- |
| [170416](https://freesound.org/people/ciccarelli/sounds/170416/) | ciccarelli | Eggs frying in oil |
| [464301](https://freesound.org/people/neilraouf/sounds/464301/) | neilraouf | Vegetables cooking in butter |
| [547519](https://freesound.org/people/colorsCrimsonTears/sounds/547519/) | colorsCrimsonTears | Sausage frying in an oil-filled skillet |
| [137229](https://freesound.org/people/xenognosis/sounds/137229/) | xenognosis | Water boiling in a small pot |
| [568112](https://freesound.org/people/andatha/sounds/568112/) | andatha | Boiling water recorded with Zoom H1n |
| [560564](https://freesound.org/people/bittermelonheart/sounds/560564/) | bittermelonheart | Sauce simmering and stirring on stove |
| [610255](https://freesound.org/people/leftovertunacasserole/sounds/610255/) | leftovertunacasserole | Tomato sauce bubbling |
| [137245](https://freesound.org/people/xenognosis/sounds/137245/) | xenognosis | Salt shaken inside plastic container |
| [95740](https://freesound.org/people/makemebad/sounds/95740/) | makemebad | Dry seasoning shaken in plastic bottle |
| [676371](https://freesound.org/people/gmsmith1918/sounds/676371/) | gmsmith1918 | Ketchup squeezed from a bottle |
| [636150](https://freesound.org/people/nataliegonzalez19/sounds/636150/) | nataliegonzalez19 | Oil poured onto a pan |
| [699231](https://freesound.org/people/clement.bernardeau/sounds/699231/) | clement.bernardeau | Oil poured into a bottle |
| [740116](https://freesound.org/people/FOSSarts/sounds/740116/) | FOSSarts | Hot water poured into a ceramic cup |
| [391478](https://freesound.org/people/coltures/sounds/391478/) | coltures | Wooden spatula moving inside frying pan |
| [166338](https://freesound.org/people/spawklz/sounds/166338/) | spawklz | Metal spatula and knife sliding on kitchen metal |
| [486999](https://freesound.org/people/OlyveBone/sounds/486999/) | OlyveBone | Water stirred in a pot |
| [336697](https://freesound.org/people/fordps3/sounds/336697/) | fordps3 | Wet mixture stirred with wooden spoon |
| [464005](https://freesound.org/people/juanforeromusic/sounds/464005/) | juanforeromusic | Small quantity of rice poured into bowl |
| [740092](https://freesound.org/people/FOSSarts/sounds/740092/) | FOSSarts | Gas stove igniting then burning |
| [406066](https://freesound.org/people/Anthousai/sounds/406066/) | Anthousai | Tap water running into kitchen sink |
| [839155](https://freesound.org/people/BenParamoreAudio/sounds/839155/) | BenParamoreAudio | Quick potato chop with Santoku knife |
| [839149](https://freesound.org/people/BenParamoreAudio/sounds/839149/) | BenParamoreAudio | Quick potato chop with Santoku knife |
| [839145](https://freesound.org/people/BenParamoreAudio/sounds/839145/) | BenParamoreAudio | Quick potato chop with Santoku knife |
| [839163](https://freesound.org/people/BenParamoreAudio/sounds/839163/) | BenParamoreAudio | Soft potato slice with Santoku knife |
| [839123](https://freesound.org/people/BenParamoreAudio/sounds/839123/) | BenParamoreAudio | Hard potato chop with Santoku knife |
| [221515](https://freesound.org/people/AlaskaRobotics/sounds/221515/) | AlaskaRobotics | Single metal service-bell ring |
| [209002](https://freesound.org/people/OwlStorm/sounds/209002/) | OwlStorm | Pots and pans clatter |
| [181260](https://freesound.org/people/CapsLok/sounds/181260/) | CapsLok | Plate set down on hard kitchen surface |
| [353105](https://freesound.org/people/milpower/sounds/353105/) | milpower | Glass bottle placed on glass plate |
| [151220](https://freesound.org/people/OwlStorm/sounds/151220/) | OwlStorm | Book page turn |
| [151221](https://freesound.org/people/OwlStorm/sounds/151221/) | OwlStorm | Book page turn variant |
| [505171](https://freesound.org/people/mitchanary/sounds/505171/) | mitchanary | Cloth wiping a window |
| [388744](https://freesound.org/people/jopimblett/sounds/388744/) | jopimblett | Grapes dropped into a bowl |
| [627655](https://freesound.org/people/KaleidacousticsAudio/sounds/627655/) | KaleidacousticsAudio | Pasta stirred in sauce in a saucepan |
| [627656](https://freesound.org/people/KaleidacousticsAudio/sounds/627656/) | KaleidacousticsAudio | Dry pasta dropped in ceramic bowl |
| [210100](https://freesound.org/people/bowlingballout/sounds/210100/) | bowlingballout | Domed metal pot lid lifted from platter |
| [757514](https://freesound.org/people/greenlinker/sounds/757514/) | greenlinker | Pot lid placed on a cooking pot |
| [218339](https://freesound.org/people/SpliceSound/sounds/218339/) | SpliceSound | Metal pot rattling while moved on stove |
| [360648](https://freesound.org/people/postworkflow/sounds/360648/) | postworkflow | Vegetables dropped into hot oil on stovetop |
