# 玩家厨房全流程教学视频 · 2026-09-27（历史首版）

最新本地完整操作版本见 [COMPLETE_KITCHEN_VIDEO_20260927.md](COMPLETE_KITCHEN_VIDEO_20260927.md)。本页保留首版的验证与存档修复记录。

面向第一次游玩的玩家，目标为约 5–6 分钟。录制脚本 `tests/capture_player_tutorial.gd` 使用当前厨房生产实现、原有美术、真实物理对象和游戏录音。章节卡片暂停场景，字幕和可见指针只属于视频编排；画面按 1352×852 / 24 fps 录制，字幕保留在独立底栏。第一份料理按正常速度加热，后面的煮汤等待明确标为 4 倍速。自动操作录制不冒充人工自由试玩、真实系统输入法验收或人耳听感验收。

主线：准备期认识厨房与库存 → 刀切和切块整批入锅 → 两次敲蛋 → 开始营业与客人纸条 → 大火转中火、核心熟度和余热 → 挤酱、木铲翻拌 → 真实摆盘和淋酱 → 拍照交菜、顾客反馈与回信 → 按真实成品写材料步骤、手写菜名和配图 → 保存、重开、分享、跟做和示范菜谱 → 成品照片海报 → 湿抹布清锅、海绵入口 → 接水、锅盖、煮汤和盛入汤碗 → 收班结算。

## 试录发现的阻断与修复

敲开的鸡蛋实际形状快照包含 **89 个几何顶点**；`recipe_repository._safe_json` 原来对所有数组统一限制为 64 个，所以正常做菜、摆盘和拍照之后，菜谱保存报“菜品数据过长或含有不支持的字段”。之前的小份保存测试未覆盖这个真实轮廓。

现在只对 `geometry` 数组允许最多 128 点，并在共享 `FoodSnapshot.valid` 中逐点验证两个有限坐标（范围 ±2000）。其余数组、JSON 深度、禁止的路径/脚本字段及整体体积限制保持原界限。没有简化或截断实际鸡蛋轮廓，没有移除温度、附着酱汁、几何、质量或照片来绕过验证。

`modules/restaurant/storage/fixtures/opened_egg_recipe.json` 是试录中的真实料理快照，仅剔除瞬时 `physics_id` / `off_heat`，保留盘中形状、质量、热史、表面酱汁和摆盘数据。原有 `storage/smoke_test.gd` 增加磁盘保存/重开、全部 89 点相等、坏坐标、超限轮廓和无关数组原限制检查。

海报原生文字结束编辑后，旧 `TextEdit` 可能在延迟失焦回调执行前被销毁，导致类型转换错误。现在回调只保存实例 ID，执行时重新查询并确认还是当前编辑器；旧事件不能结束后续的文字编辑。`ui/collage_test.gd` 新增真实控件销毁及立即打开下一段文字的回归，保留两段内容并检查新输入仍活动。修复后重新运行完整入口，并重录正式片。

## 录制隔离

正式录制实例继承生产 `restaurant.gd`。只有顾客反馈存储被定向到本次独立随机临时目录，避免录制继续写入日常反馈文件；菜谱和海报也使用独立存档。顾客使用原有数据文件顺序（老板先登场），仅固定出场顺序，没有替换锅温、熟度、压力、食材、摆盘或顾客评分。正式片中中文文本由自动操作填入原生纸面编辑器，不声称手工 IME 输入。

## 已执行检查

- 完整共享入口：44/44 Godot 脚本，导入、120 帧启动与外部录音审计，0 项失败。见 `qa/20260927-player-tutorial/checks/summary.json`。
- 定向存档测试：实际 89 点敲蛋样本保存及重开成功，异常数据仍拒绝。
- 正式 GPU 全流程录制：87 项操作/状态断言通过，日志无引擎/脚本错误，实际 8140 帧 / 339.167 秒（5 分 39 秒），包括实拍、真实料理菜谱、笔迹重开、分享文件、海报、抹布湿度与残留减少、水龙头供水、锅盖蒸汽和实际锅到碗的汤量转移。
- 正式片的媒体信息、全帧解码、音轨非静音/峰值、抽帧视觉检查和最终时长在成片后记录于同目录 README。

## 重录

Movie Maker 在启动脚本执行前确定录像尺寸，因此录制期间将工程的 `window_width_override` / `window_height_override` 临时改为 1352 / 852，启动后立即恢复原有 1440 / 851；没有提交普通游戏窗口设置的修改。驱动显式绘制后等待当前帧末尾计时器，避免 macOS 遮挡窗口不绘制，以及嵌套协程在同一信号内跳过录像帧。正式录制前用 `probe` 参数验证字幕完整、帧号递增以及 205 个脚本帧对应 206 个 AVI 帧（含启动帧）。强制绘制时终端末尾的渲染统计不代表实际 AVI 帧数：原生 [MovieWriter 源码](https://github.com/godotengine/godot/blob/master/servers/movie_writer/movie_writer.cpp) 在结尾打印 `frames_drawn`。本轮按实际 JPEG chunk 数、PCM 长度以及完整解码验收音画同步，不用该统计猜测成片时长。

可用下面的 Python 包装恢复窗口设置（先确保没有同时编辑工程配置）：

```python
from pathlib import Path
import subprocess
project = Path("prototypes/100-restaurant/project.godot")
original = project.read_bytes()
recording = original.replace(b"window_width_override=1440", b"window_width_override=1352").replace(b"window_height_override=851", b"window_height_override=852")
try:
    project.write_bytes(recording)
    subprocess.run(["godot", "--path", str(project.parent), "--write-movie", "/private/tmp/kitchen-tutorial.avi", "--fixed-fps", "24", "--disable-vsync", "--script", "tests/capture_player_tutorial.gd", "--", "/absolute/evidence/qa-directory/video"], check=True)
finally:
    if project.read_bytes() == recording:
        project.write_bytes(original)
```

```sh
python3 prototypes/100-restaurant/tools/extract_godot_avi.py /private/tmp/kitchen-tutorial.avi /private/tmp/tutorial-frames
swift prototypes/100-restaurant/tools/encode_godot_movie.swift /private/tmp/tutorial-frames /private/tmp/tutorial-silent.mp4 24 2000000
python3 prototypes/100-restaurant/tools/prepare_player_tutorial.py /private/tmp/tutorial-frames/audio.wav /private/tmp/tutorial-audio.wav /absolute/evidence/qa-directory Demo
swift prototypes/100-restaurant/tools/mux_godot_movie.swift /private/tmp/tutorial-silent.mp4 /private/tmp/tutorial-audio.wav Demo/厨房游戏全流程演示.mp4
swift prototypes/100-restaurant/tools/verify_player_tutorial.swift Demo/厨房游戏全流程演示.mp4 /absolute/evidence/qa-directory
```

成片音轨只对原有游戏录音施加统一增益与首尾 0.12 秒淡化，不增加合成拟音、音乐或口播。同名 SRT 的起止时间包含实际的一个启动帧。原有 DIY 演示视频保持保留。

macOS 需要原生 GPU 窗口及 AVFoundation 编码权限。视频和检查日志不是对所有自由组合、所有设备或最终音色的全面人工验收。
