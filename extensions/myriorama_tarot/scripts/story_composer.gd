extends RefCounted

# New narrative metadata extends the existing 18 cards; it never replaces art,
# identities, interpretation data, or the existing authored case/truth engine.
const MOMENTS := {
	"01": ["balance", "港口的两个水杯", "她试着在两个愿望之间分配自己的时间", "留一点余地给彼此"],
	"02": ["order", "旧镇公所的石阶", "守门人坚持先把事情排出先后", "规则究竟保护了谁"],
	"03": ["change", "海风转动的旧轮盘", "原本熟悉的位置悄悄换了主人", "变化中还有什么没有变"],
	"04": ["change", "被风暴损坏的高塔", "一件意外让原定计划无法继续", "失去的路是否留下了另一扇门"],
	"05": ["clarity", "放着天平的小铺", "她把听来的判断和亲眼见到的东西分开放好", "判断之前还需要什么证据"],
	"06": ["action", "摆满工具的木桌", "她终于拿起一直没有使用的工具", "先做哪一件小事"],
	"07": ["journey", "驶向海岸的车", "她带着一个问题离开了熟悉的街道", "前进是否也可以意味着回来"],
	"08": ["hope", "第一颗星升起的岸边", "远处的一点亮光让她愿意再等一会儿", "希望需要怎样的照料"],
	"09": ["bond", "摆着两只杯子的窗边", "两个很久没有交谈的人重新坐到了一起", "怎样开口才能真正听见对方"],
	"10": ["ending", "打翻了杯子的石桥", "她一直看着失去的东西，差点忽略身后仍在的人", "剩下的是否也值得珍惜"],
	"11": ["bond", "通向两边的岔路", "她发现选择一条路也在改变与别人的关系", "选择是谁的愿望"],
	"12": ["restraint", "系着旧锁链的码头", "熟悉的牵挂渐渐成了不敢离开的理由", "哪些束缚其实可以放下"],
	"13": ["conflict", "传来争执的广场", "几个人同时说话，每个人都觉得自己没有被听见", "分歧后面有没有相同的愿望"],
	"14": ["ending", "送别过客的渡口", "一段旅程到了终点，她必须把旧票交还", "结束之后想带走什么"],
	"15": ["uncertainty", "月光照不到尽头的路", "影子看起来像答案，却随着她的脚步改变", "眼前的是事实还是猜测"],
	"16": ["pause", "能倒映天空的桥下", "她停下来，从倒影里重新看了一次熟悉的地方", "换个角度会发现什么"],
	"17": ["clarity", "响起号角的清晨", "一封迟到的消息让她重新理解了昨天", "知道之后愿意怎样回应"],
	"18": ["uncertainty", "垂着帘子的书屋", "她读到一页尚未说完的记录，决定不急着下结论", "哪些事情还需要耐心等待"]
}

static func tags(id: String) -> Array:
	return [MOMENTS[id][0], "seaside", "human"]

static func relationship(a: String, b: String) -> String:
	var left: String = MOMENTS[a][0]
	var right: String = MOMENTS[b][0]
	if left == right: return "这一次，先前的主题换了一个面孔，再次来到她面前。"
	if left in ["ending", "conflict", "restraint"] and right in ["hope", "bond", "balance"]:
		return "她以为故事已经走到尽头，但这里仍有人为她留了一点位置。"
	if left in ["uncertainty", "pause"] and right in ["clarity", "action", "journey"]:
		return "先前没能说清的迟疑，在下一步行动里慢慢有了形状。"
	if left == "order" and right == "change": return "刚刚建立的秩序，遇上了不肯照计划发生的海风。"
	if left == "bond" and right == "ending": return "关系没有让告别变得容易，却让告别有了值得记住的重量。"
	return "带着在%s留下的疑问，她走向了%s。" % [MOMENTS[a][1], MOMENTS[b][1]]

static func compose(order: Array) -> Array[String]:
	var result: Array[String] = []
	if order.size() != 4: return result
	for id in order:
		if not MOMENTS.has(id): return []
	result.append("那我们就从%s说起。那一天，%s。" % [MOMENTS[order[0]][1], MOMENTS[order[0]][2]])
	for i in range(1, 4):
		result.append(relationship(order[i - 1], order[i]) + "\n" + str(MOMENTS[order[i]][2]) + "。")
	result.append("故事停在这里，没有替她决定明天。留下的问题是：%s？\n\n这是我们按牌序编织的故事，不是预言，也不是海龟汤案件的标准答案。" % MOMENTS[order[3]][3])
	return result
