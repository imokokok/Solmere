# 本地公共菜谱与海报数据

这是**离线公共菜谱原型**：同一个本地存档后续游玩时可以看到以前发布的作品；不同电脑通过导出、导入 JSON 手动交换。当前没有服务器、账号、跨机器实时同步或可信排行榜。

## 使用

```gdscript
const RecipeRepository = preload("res://modules/restaurant/storage/recipe_repository.gd")
var repository = RecipeRepository.new()
var recipes = repository.load_recipes() # 首次为空
repository.save_recipe({
    "title": "什么时候下班", "author": "今晚的主厨", "notes": "随手写下做法",
    "dish": {"ingredients": ["tomato"]},
    "thumbnail": "", "poster": {}
})
# FileDialog 确认的文件路径可以传入；菜谱内容中的文件路径不会被执行或读取。
repository.export_to("user://my_cookbook.json")
var result = repository.import_from("user://friend_cookbook.json")
```

正式调用应检查 bool / Error 返回值，失败原因用 `get_last_error()`。`import_from()` 返回 `{added: int, error: String}`；重名 ID 跳过，不覆盖本地作品。`like_recipe(id)` 在本地存档中只允许每道菜喜欢一次，`has_liked(id)` 查询状态。导入作品的喜欢数归零；这不是在线排名。

纯纸面 DIY 菜谱可以不绑定已完成料理。规范写法为 `dish: {"ingredients": []}` 与 `poster: canvas.export_data()`，不要伪造 `quality`、熟度或出餐数据。只有纸面经过严格验证，且至少有一个实际素材图层或带点的笔画时才允许保存；空白纸、空笔画对象、只有旧 `caption`、只有标题/备注都不算纸面内容。空料理保存时统一规范为仅 `ingredients: []`，不会保留误带的料理评分字段。

编辑已有作品时，把原记录的 `id` 一起传给 `save_recipe()`，仓库替换这一条记录，保留原 `created_at`、点赞数和本地已点赞状态。要另存副本，先深拷贝记录，再删除 `id`、`created_at`、`likes` 后保存；这样会生成新 ID 和创建时间，副本点赞从零开始。编辑失败时原记录保持不变。文件导入仍按 ID 去重，不会把朋友的同 ID 记录覆盖到本地作品。

默认存档：`user://after_hours_kitchen/cookbook.json`。可给构造器传入其他路径用于测试：`RecipeRepository.new(test_path, catalog_path)`。食材白名单从 `res://modules/restaurant/data/ingredients.json` 加载。

## 交换格式，版本 1

顶层是 `{"schema_version": 1, "recipes": [...]}`；本地文件额外含 `liked_ids`。每条菜谱包含 `id / title / author / notes / created_at / dish / thumbnail / poster / likes`。保存时缺失的 ID 与 UTC 时间自动生成。标题 60 字、署名 40 字、备注 2000 字；食材数组最多 48 个物理切块，每项可以是食材 ID 或含 `id` / `ingredient_id` 的 JSON 对象。这个上限与厨房的 48 块实体容量一致；同一次切出的实体通过 `batch_uid` 仍按一份来源食材计算，最多使用 6 份来源食材。

`thumbnail` 为不带 `data:` 前缀的 PNG base64 字符串，最大 1 MiB，图片最大 1024×1024，因此 JSON 单文件可携带照片；可用 `Marshalls.raw_to_base64(image.save_png_to_buffer())` 创建。`photo` 只作为旧调用别名读入，仍必须是 PNG base64，输出统一为 `thumbnail`。不接受照片文件路径或 URL。

海报/菜谱纸面 `poster` 由 `PosterCanvas.export_data()` 返回：`version: 1, caption: String, strokes: [{points: [[x,y], ...], color: RGBA十六进制, width: 归一化画笔宽}], stickers: [...]`。自由拼贴纸面初始完全空白，不显示默认标题、照片、食材或装饰；`caption` 只兼容旧记录，不自动绘制，文字必须显式加入图层。`dish_texture` 也不自动显示，照片使用 `add_photo()` 显式加入。

所有素材层共有 `kind / position:[0..1,0..1] / scale / rotation`，旋转可省略，存在时在 `-PI..PI`。`kind` 可为 `star / heart / leaf / tape` 装饰；`ingredient` 额外保存白名单 `id`、布尔 `cut`、可选 `heat:0..60`；`text` 保存最长 120 字的 `text` 与十六进制 `color`；`photo` 保存 `png` 字段（内嵌 PNG base64，单层最大 512 KiB、512×512）。新增食材/文字/照片层尺寸范围 `0.04–0.28`。最多 32 层共用同一上限，所有纸面及照片计入总文件 16 MiB 上限。

照片与食材还可包含 `mask:[[x,y],...]`，坐标为素材局部 `-1..1`，3–32 个顶点，不允许自交或退化多边形。裁剪仅遮住素材，不破坏原始图片；保存后可恢复。数组顺序就是素材层序。最多 128 条笔画、每条 512 点；笔画当前统一显示在素材上方，便于在照片和贴纸上涂写。

胶带 `kind: "tape"` 可保存 `color`（HTML 十六进制字符串，默认 `baa977`）、`length`（0.5–6，默认 1）、`width`（0.4–3，默认 1）。长宽独立作用于 80×32 本地轮廓，整层 `scale` 与 `rotation` 不变；命中区域和选框一起更新。这三个字段可省略，旧版本 1 胶带无需迁移。新的菜谱/海报 JSON 导入导出保留字段并严格验证类型、有限数及范围。

编辑 API：`add_ingredient(definition)`、`add_text(text,color)`、`add_photo(texture)`、`add_sticker(kind)`；`mode` 为 `select`（默认）、`draw` 或 `cut`。选择后可拖移，滚轮缩放，Delete 删除；`rotate_selected(radians)`、`resize_selected(factor)`、`duplicate_selected()`、`send_selected_back()`、`delete_selected()` 提供工具栏操作。裁剪模式逐点添加顶点，Enter/双击闭合，Esc 取消草稿；`restore_selected_cut()` 恢复原图。以上变更可 `undo()`；`clear_canvas()` 连文字与旧照片字段一起清空。新增素材后自动回选择模式。

独立墙上海报由 `ui/poster_store.gd` 保存，API 为 `new(path)`、`load_poster()`、`save_poster(data)`、`get_last_error()`；与菜谱复用图层验证。海报额外允许最多 16 个招徕标签 `tags`，每个最多 40 字。两个存储均以完整浮点精度写入 JSON，避免反复保存导致布局、旋转或裁剪顶点漂移。

胶带编辑 API：`selected_tape_settings()` 返回 `{color: HTML字符串, length: float, width: float}`，未选胶带返回 `{}`；`set_tape_color(Color)`、`set_tape_length(float)`、`set_tape_width(float)` 更新选中胶带。工具输入有限越界值会限制到允许范围，无效浮点数忽略。用 `begin_property_edit()` / `end_property_edit()` 包住一次滑块或调色操作，可合并为一次撤销；没有实际变化不新增撤销记录。选中和修改发出 `changed`。选择模式下拖动胶带两端圆点可直接改变长度，松手结束。

运行 `godot --headless --path . --script modules/restaurant/ui/collage_test.gd` 可验证空白纸、拖移/绘画模式、旋转、缩放、复制/层序、裁剪/恢复、图层上限、照片限制及海报/菜谱重载。使用图形后端运行同一测试还会检查实际裁剪像素与笔画覆盖照片的像素。

保存先写入同目录临时文件、flush，再备份旧文件为 `.bak` 并更名。主文件损坏时尝试读取备份；主文件和备份都无法读取时保留文件并禁止覆盖。导入严格验证，任何一条无效都会取消整次导入；文件最大 16 MiB，本地最多 200 道。所有导入均使用 JSON，不执行脚本，不加载对象或外部资源。

把菜谱数据接入线上时，应另加服务端认证、内容管理、审核、图片托管、冲突与离线合并规则，并维持这个 JSON 版本边界。不要直接把本地喜欢数当成线上排名。

非空实作料理可选 `dish.water_ml`（有限数值 0–1500）。缺省为 0，版本1旧文件继续兼容；JSON交换保留水量。纯纸面作品不带实际料理指标。

## 图解菜谱纸面（2026-09-27）

`poster` 可另含 `recipe_sheet: {version: 1, materials: String, steps: [String, String, String, String], source: String}`，保存预写或用户改写的材料与四步说明。材料最多 200 字、每步最多 120 字、来源说明最多 60 字；拒绝未知键和错误结构。涂鸦数据仍为独立 `strokes`，容量最多 512 条、每条最多 512 个点，32 素材层和 16 MiB 文件上限保留。

图解菜谱的画布是 560×760 的竖版整页，标题笔画也在其中；不能用旧横版拼贴比例显示。保存时要求标题区域有玩家笔画，至少一个配图区有笔画，只有预写文字的页不能保存为作品。纸面名称来自手写笔画，`record.title` 为“手绘菜谱 N”索引，不做文字识别。没有实际料理时，`dish` 仍仅保存 `ingredients: []`，说明文字中的示例食材不能注入实际用料或评分。可选字段缺失时完全保留旧拼贴格式。
