extends RefCounted


const VOICES: = {
	"charred": {"role": "偏爱焦边的锅巴迷", "burnt": "这圈焦边好！就是这口脆香，我专门为它来的。", "raw": "外面焦了，里面也得熟。我爱锅巴，可不爱夹生。", "dislike": "焦边对了，这个甜味可不对我的路数。", "seasoning": "别把焦边泡软了，我就是来吃它的。", "liked": "材料挑得合意，下回再给它一点焦边。", "good": "这顿够香！来，把锅底的也留给我。", "plain": "做得太温柔了！我那口焦香还没出来呢。", "strange": "这个搭配有点远，我还是惦记锅巴。"},
	"tired": {"role": "下班后来吃饭的人", "burnt": "今天加班已经够火大了，这口也焦了。", "raw": "我能等，真的。再给它一点在锅里的时间吧。", "dislike": "我只是想安安稳稳吃顿饭，这口有点为难我。", "seasoning": "主厨，今天是酱料替食材上班吗？", "strange": "这份创意，我下班后的脑袋暂时接不住。", "liked": "嗯，就是这个味道。今天总算有件顺心的事。", "good": "吃完有力气回家了。谢谢，主厨。", "plain": "能填饱肚子。要是再合口一点，今天就圆满了。"},
	"old_critic": {"role": "慢慢品味的老饕", "burnt": "焦香和焦苦，只差你晚关火的那一会儿。", "raw": "别急着端出来。筷子能夹起，不等于火候到了。", "dislike": "我这张嘴有些固执，这个味道实在不对路。", "seasoning": "调味是托住食材，怎么反倒把主角压下去了？", "strange": "心思是新的，味道还得再琢磨。", "liked": "嗯，这一口鲜味抓住了。坐下来，咱们可以聊聊这道菜。", "good": "火候和搭配都有分寸，这顿饭值得慢慢吃。", "plain": "有想法，但离让人放下筷子还惦记着，差一点。"},
	"excited": {"role": "寻找新奇的冒险食客", "burnt": "哇，这次直接探索到了焦炭星球！下次换个目的地？", "raw": "我想冒险，但不是和没熟的食材比胆量呀！", "dislike": "这个组合我也有点招架不住，今天算你赢。", "seasoning": "等等，这是酱料浴池？食材快出来打个招呼！", "strange": "居然能这样搭！先别告诉我配方，让我再猜一口！", "liked": "对对对，就是这种没见过的主意！给这道菜起个响亮的名字吧！", "good": "好吃是好吃，可我带来的好奇心还没吃饱！", "plain": "这也太守规矩了吧！下次让我见识你的脑洞。"},
	"fresh": {"role": "偏爱清爽的散步客", "burnt": "本来想吃得轻快一点，这股焦味有点重。", "raw": "这口还没准备好出锅吧？我可以再等一会儿。", "dislike": "嗯……这个味道我不太行，我还是喜欢清爽一点的。", "seasoning": "酱有点厚，把食材本来的味道都盖住啦。", "strange": "这口转弯太突然，我还是想走清爽那条路。", "liked": "这一口清清爽爽的，像散步时刚好吹来一阵风。", "good": "不费劲就能吃完的一餐，挺舒服的。", "plain": "还可以，不过离我想吃的那口清爽差了一点。"},
	"chef": {"role": "盯着火候的同行", "burnt": "锅热，手就得跟上。这个焦边已经收不回来了。", "raw": "这份火候还欠着，出锅早了。", "dislike": "这味道把我想吃的鲜味带跑了。", "seasoning": "下调料的时候手收一点，别让酱抢了整口锅。", "strange": "搭配够大胆，得再想想怎么让味道接得上。", "liked": "鲜味出来了。看得出这锅你有照顾到。", "good": "这口可以。做饭的人知道，稳稳做好也不容易。", "plain": "流程走完了，味道还没到位。再试一锅。"},
	"sweet": {"role": "为甜味专程而来", "burnt": "呜，这口的焦味把期待里的甜都挤走了。", "raw": "好吃的东西值得等，要不再煮一会儿？", "dislike": "这个味道有点凶，我想要的明明是软乎乎的那种。", "seasoning": "这么多酱呀，食材都快藏起来了。", "strange": "这份惊喜有点太大啦，我先缓一缓。", "liked": "是我盼着的那一口！今天的小奖励就是它了。", "good": "吃到最后一口还挺舍不得，下次还来。", "plain": "还差一点让我眼睛亮起来的味道。"},
	"deadpan": {"role": "惜字如金的怪味鉴赏家", "burnt": "烧焦。不是我说的那种黑暗料理。", "raw": "没熟。怪，和省略步骤，是两回事。", "dislike": "这口不在我的探索范围内。", "seasoning": "酱很多。悬念很少。", "strange": "有意思。配方留着。下次我还点。", "liked": "这口值得我摘下墨镜。", "good": "正常。过于正常。", "plain": "我绕了半座城，不是为了吃熟悉的东西。"},
	"starry": {"role": "观景台常客", "burnt": "像拍照曝光过头了，焦边把原来的颜色都盖住了。", "raw": "这口还早了些，火候再等一会儿。", "dislike": "这个味道太冲，安静的部分都找不到了。", "seasoning": "酱太密，食材的层次看不清。", "liked": "清楚又轻快，像今晚抬头看见的那片天空。", "good": "这份刚刚好，我想慢慢吃完。", "plain": "能吃，不过还少一点让我记住的细节。", "strange": "这个组合像陌生的星图，我再尝一口。"},
	"playful": {"role": "下棋摊常客", "burnt": "这步火下重啦，棋还能悔，锅里的焦味可退不回去。", "raw": "别急着落子，里面还没熟呢。", "dislike": "这个味道把好棋走歪了。", "seasoning": "调料一下得太满，主角没地方走啦。", "liked": "这一步有想法，我还想再试一口！", "good": "有趣又好吃，这局算我输了。", "plain": "开局稳稳的，下一步再大胆点？", "strange": "没想到能这么搭，这像一步妙手。"},
	"pet": {"role": "带狗散步的邻居", "burnt": "遛完狗闻着香进来，结果焦味比饭香先到了。", "raw": "这份还没熟，先让它在锅里多待一会儿。", "dislike": "有点太刺激，我还是想吃清爽些的。", "seasoning": "酱盖住了食材，我都快分不清它们了。", "liked": "散步回来吃这口，舒服。", "good": "吃好了，等会儿还能再陪狗走一段。", "plain": "能填饱肚子，下次试点更鲜明的味道。", "strange": "这比我上回游戏里见的组合还意外。"},
	"regular": {"role": "街坊食客", "burnt": "这口有些焦苦，下次早一点关火就好了。", "raw": "我不着急，再做熟一点吧。", "dislike": "这里面有我不爱吃的味道。", "seasoning": "调料多了些，我还是想吃到食材自己的味道。", "strange": "这搭配有点超出我的接受范围。", "liked": "刚好有我喜欢的味道，这一餐吃得舒心。", "good": "吃得挺满足，谢谢招待。", "plain": "今天这份没有特别合我口味，下次再试试吧。"}
}

static func compose(snapshot: Dictionary, customer: Dictionary, catalog: Dictionary, score: int) -> Dictionary:
	var kind: = str(customer.get("kind", "regular"))
	var fallback: = "old_critic" if kind == "gourmet" else ("excited" if kind == "adventurous" else "regular")
	var voice: Dictionary = VOICES.get(str(customer.get("review_voice", fallback)), VOICES[fallback])
	var burnt: Array[String] = []
	var raw: Array[String] = []
	var avoided: Array[String] = []
	var liked: Array[String] = []
	var strange: Array[String] = []
	var seasonings: Array[String] = []
	var seasoning_batches: Dictionary = {}
	var seasoning_volume_ml := 0.0
	var food_mass_kg := 0.0
	var entries: Array = snapshot.get("ingredients", [])
	for index in entries.size():
		var item: Dictionary = entries[index]
		var def: Dictionary = catalog.get(str(item.get("id", "")), {})
		if def.is_empty(): continue
		var title: = str(def.get("name", item.id))
		var heat: = float(item.get("heat", 0))
		if heat > 14.0 and not burnt.has(title): burnt.append(title)
		if def.get("needs_cook", false) and heat < 6.0 and not raw.has(title): raw.append(title)
		for tag in def.get("tags", []):
			if customer.get("dislikes", []).has(tag) and not avoided.has(title): avoided.append(title)
			if customer.get("likes", []).has(tag) and not liked.has(title): liked.append(title)
		if float(def.get("weirdness", 0)) >= 0.35 and not strange.has(title): strange.append(title)
		if not str(def.get("dispense_mode", "")).is_empty():
			var batch := str(item.get("batch_uid", ""))
			if batch.is_empty(): batch = "%s_portion_%d" % [str(item.get("id", "")), index]
			seasoning_batches[batch] = true
			seasoning_volume_ml += float(item.get("liquid_state", {}).get("volume_ml", item.get("amount_ml", 0.0)))
			if not seasonings.has(title): seasonings.append(title)
		else:
			food_mass_kg += float(item.get("mass_kg", 0.15))
	var seasoning_count := seasoning_batches.size()
	var excessive_volume := seasoning_volume_ml > maxf(30.0, food_mass_kg * 300.0)
	var reason: = "plain"
	var details: Array[String] = []
	for trace in snapshot.get("pan_carryover", {}).values():
		if float(trace.get("mass_kg", 0)) >= 0.00005:
			details.append("还有上一锅留下的%s味；两道菜之间把空锅擦洗一下会更清爽。" % str(trace.get("title", "调料")))
			for tag in trace.get("tags", []):
				if customer.get("dislikes", []).has(tag) and not avoided.has(str(trace.title)):
					avoided.append(str(trace.title))
	if not burnt.is_empty() and not bool(customer.get("likes_burnt", false)):
		reason = "burnt"
		details.append("%s已经焦了，苦味很明显。" % _names(burnt))
	elif not raw.is_empty():
		reason = "raw"
		details.append("%s还没熟透，再给一点火候会更好。" % _names(raw))
	elif not avoided.is_empty():
		reason = "dislike"
		details.append("%s碰到了我的忌口，这口没法喜欢。" % _names(avoided))
	elif not burnt.is_empty() and bool(customer.get("likes_burnt", false)):
		reason = "burnt"
		details.append("%s的焦边正合我的偏好。" % _names(burnt))
	elif (seasoning_count >= 3 and seasoning_count * 2 >= entries.size()) or excessive_volume:
		reason = "seasoning"
		details.append("%s大约加了%d毫升，盖过了食材本身。" % [_names(seasonings), roundi(seasoning_volume_ml)] if excessive_volume else "%s加了不少，整份里用了%d份调料。" % [_names(seasonings), seasoning_count])
	elif float(snapshot.get("weirdness", 0)) > 0.45:
		reason = "strange"
		details.append("%s这个组合%s。" % [_names(strange if not strange.is_empty() else liked), "够出乎意料，我喜欢" if kind == "adventurous" else "对我来说太奇怪了"])
	elif not liked.is_empty():
		reason = "liked"
		details.append("%s有我喜欢的味道。" % _names(liked))
	elif score >= 65: reason = "good"
	if reason in ["burnt", "raw", "seasoning"] and not avoided.is_empty():
		details.append("另外，%s也不是我喜欢的口味。" % _names(avoided))
	elif reason in ["burnt", "raw"] and not liked.is_empty():
		details.append("不过选了%s，口味方向是对的。" % _names(liked))
	if str(customer.get("cut_preference", "")) == "small" and int(snapshot.get("cut_count", 0)) == 0:
		details.append("我更喜欢切成小块，这份还得自己动刀。")
	var reaction: = "满意地点点头" if score >= 75 else ("放慢了筷子" if score >= 45 else "把筷子轻轻放下")
	if kind == "adventurous": reaction = "眼睛一下亮了" if score >= 75 else ("歪着头又尝了一口" if score >= 45 else "笑容停了一拍")
	elif kind == "gourmet": reaction = "细细咀嚼，点了点头" if score >= 75 else ("皱眉回味了一下" if score >= 45 else "夹起一口，又放回盘里")
	return {"feedback": str(voice.get(reason, voice.plain)), "detail": "\n".join(details), "reaction": reaction, "role": str(customer.get("role", voice.role)), "reason": reason}

static func _names(values: Array[String]) -> String:
	return "、".join(values.slice(0, 2)) if not values.is_empty() else "这道菜"
