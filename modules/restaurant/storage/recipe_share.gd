extends RefCounted
## Portable, offline reading copy with one editable recipe attached. No network or script.
static func document(record: Dictionary, page_png: String, catalog: Array) -> String:
	var sequence := preload("res://modules/restaurant/domain/recipe_method.gd").steps(record, catalog)
	var steps := ""
	for step in sequence:
		steps += "<li><h3>%s</h3><p>%s</p></li>" % [str(step.title).xml_escape(), str(step.detail).xml_escape()]
	var photo := ""
	if not str(record.get("thumbnail", "")).is_empty():
		photo = '<figure><img alt="作者这次做好的料理" src="data:image/png;base64,%s"><figcaption>这次做好的样子</figcaption></figure>' % record.thumbnail
	var payload := Marshalls.utf8_to_base64(JSON.stringify({"schema_version":1, "recipes":[record]}, "\t"))
	return """<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>%s · 一页厨房</title><style>
*{box-sizing:border-box}body{margin:0;background:#e5d6b8;color:#533d2d;font:18px/1.8 Georgia,'Songti SC',serif}main{max-width:1140px;margin:40px auto;padding:30px;display:grid;grid-template-columns:1fr 1fr;gap:42px;background:#faf0d9;border-radius:3px;box-shadow:0 6px 32px #694e2922}img{width:100%%;height:auto}h1{font-size:30px;line-height:1.4}h2{font-size:23px}h3{font-size:19px;margin:0}p{margin:5px 0 18px}ol{padding-left:28px}li{padding:10px 0 18px;border-bottom:1px solid #dacaaa}small,figcaption{color:#7a6856;font-size:14px}figure{margin:24px 0}blockquote{margin:24px 0;padding:18px;background:#eee1be;white-space:pre-wrap}a{display:inline-block;padding:8px 20px;color:#68482f;border:1px solid #ae8c64;text-decoration:none;border-radius:3px}footer{grid-column:1/-1;border-top:1px solid #dacaaa;padding-top:18px}@media(max-width:720px){main{margin:12px;padding:20px;grid-template-columns:1fr;gap:20px}}
</style><main><section><img alt="作者亲手排画的菜谱" src="data:image/png;base64,%s"></section>
<section><small>100 饭店 / 一页厨房</small><h1>%s</h1><p>主厨 · %s</p>%s<h2>跟着做</h2><small>按成品状态整理的做法；作者的具体顺序请看叮嘱。</small><ol>%s</ol><h2>主厨的叮嘱</h2><blockquote>%s</blockquote></section>
<footer><a download="%s.json" href="data:application/json;base64,%s">把这一页带回我的厨房</a><p><small>这是一份离线分享页，没有上传到公共服务器。下载菜谱文件后，在游戏「我的菜谱」中导入，即可继续画、改写和跟做。仅包含本页作品。</small></p></footer></main></html>""" % [str(record.title).xml_escape(), page_png, str(record.title).xml_escape(), str(record.author).xml_escape(), photo, steps, str(record.get("notes", "")).xml_escape(), str(record.id).xml_escape(), payload]
