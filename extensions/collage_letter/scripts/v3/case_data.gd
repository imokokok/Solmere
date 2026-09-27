extends RefCounted
## Authored, finite clues. Player writing is never parsed or scored.
const CASES = {
 "Mara": {"recipient":"Elena Moreau", "ids":["mara_left","mara_right","receipt","train"], "required":{"SHARED_MEMORY":2}, "avoided":{"RETURN":3}, "matter":"June 17，那天我们一起坐过的桌子。", "boundary":"别让她以为我要回 Solmere。", "brief":[0,1], "reply":"她回信了。\n没有问我什么时候回来。\n她说，六号桌换了一盏灯。\n\n这个词，是她从信上剪下来的。", "reward":"STILL"},
 "Theo": {"recipient":"Nico Alvarez", "ids":["theo","mic","record"], "required":{"PERFORMED":2}, "avoided":{"APOLOGY":3}, "matter":"我终于在台上唱了 Summer Static。", "boundary":"别写成一封正式的道歉信。", "brief":[1,2], "reply":"Nico 来买了一张唱片。\n他没提从前那次争吵。\n只问我，下周还唱不唱。", "reward":"AGAIN"},
 "June": {"recipient":"Ms. Bell", "ids":["june_left","june_right","literature"], "required":{"GRATITUDE":2}, "avoided":{"FAREWELL":3}, "matter":"谢谢她在旧课本页边留下的那句话。", "boundary":"这不是悲伤的告别。", "brief":[2,0], "reply":"Bell 老师说，她也留下了我的作文。\n夹在一本封皮掉了的书里。\n她约我星期四去喝茶。", "reward":"ROOM"}
}
static func item(id:String,title:String,body:String,kind:String="note",back:String="",style:int=1) -> Dictionary:
 return {"id":id,"title":title,"body":body,"kind":kind,"back":back,"style":style,"tags":{},"cuts":[]}
static func region(word:String,tags:Dictionary={}) -> Dictionary:
 return {"word":word,"tags":tags}
static func objects() -> Array:
 var a = [
 item("mara_left","HELP ME SAY IT","FROM  Mara\nTO  Elena Moreau\n\nJune 17.\nShe will remember.","tear_left","奶油色信纸，蓝色圆珠笔。\n我怕自己写着写着，又答应了做不到的事。",1),
 item("theo","HELP ME SAY IT","FROM THEO\nTO  Nico Alvarez\n\nI finally did it.\nDon't turn it into\nan apology.","note","他的字总是方方正正的。\n这次我想借你们的纸片，说一句没说出口的话。",4),
 item("june_left","HELP ME SAY IT","FROM  June\nTO  Ms. Bell\n\nFifteen years old.","tear_left","淡黄纸，红铅笔。\n她讨厌夸张的致辞。我想她会喜欢你们贴出来的小信。",3),
 item("receipt","LEMON CAFÉ","JUNE 17\nTABLE 6\nLEMON SODA × TWO\n\n2 drinks · 6.00","receipt","same table next year?\n\n（蓝色笔迹，与 Mara 的便笺相同。）",1),
 item("train","SOLMERE RAIL","SOLMERE → MARSEILLE\nJUNE 18\nONE WAY\n\n07:42    SEAT 18","ticket","蓝色的墨迹透过薄纸。\n票背没有返程日期。",2),
 item("mic","SOLMERE RECORDS","OPEN MIC\nJULY 14\n\nN. said I never would.","ticket","黑色打字墨水。\n演出单背面留着揭下胶带的浅印。",4),
 item("record","SIDE B","Summer Static  ◯\nAfter 11\nFirst Light","record","Summer Static 被黑笔圈了两次。",2),
 item("literature","LITERATURE · 1998","Don't make yourself\nsmaller just because\nthe room is.\n\n— B.","literature","红色铅笔写在课本页边。\n贝尔老师留在课本旁边的一句话。",3),
 item("mara_right","…","Please don't make it\nsound like I'm\ncoming home.","tear_right","右边的撕口，和一张奶油色便笺吻合。",1),
 item("june_right","…","You wrote something\nin the margin\nwhen I was fifteen.\nI kept it.","tear_right","红色铅笔轻轻划过纸背。",3),
 item("address","ADDRESS","14 HARBOR LANE\nE. M______","label","邮政标签，被雨水浸开的蓝墨水。",1),
 item("index","SOLMERE DIRECTORY","Elena Moreau\nSolmere Records\n14 Harbor Lane","label","名录索引 · 去书里确认收件人。",2)]
 for d in a:
  match d.id:
   "mara_left": d.cuts=[region("PLEASE"),region("REMEMBER",{"SHARED_MEMORY":2,"CONTINUITY":1})]
   "mara_right": d.cuts=[region("HOME",{"HOME":2,"RETURN":1}),region("SOUND LIKE"),region("not HOME",{"HOME":2,"RETURN":-2})]
   "receipt": d.cuts=[region("JUNE 17",{"SHARED_MEMORY":3}),region("TWO"),region("LEMON")]
   "train": d.cuts=[region("ONE WAY",{"SEPARATION":2,"RETURN":-2}),region("SOLMERE"),region("MARSEILLE")]
   "theo": d.cuts=[region("I FINALLY DID IT",{"PERFORMED":3}),region("SORRY",{"APOLOGY":3})]
   "mic": d.cuts=[region("ON STAGE",{"PERFORMED":2}),region("JULY 14")]
   "record": d.cuts=[region("SUMMER STATIC",{"PERFORMED":2}),region("SIDE B")]
   "june_left": d.cuts=[region("FIFTEEN"),region("THANK YOU",{"GRATITUDE":3})]
   "june_right": d.cuts=[region("I KEPT IT",{"GRATITUDE":2}),region("THE MARGIN",{"GRATITUDE":2})]
   "literature": d.cuts=[region("DON'T MAKE YOURSELF SMALLER",{"GRATITUDE":3}),region("ROOM"),region("GOODBYE",{"FAREWELL":3})]
 return a
static func library() -> Array:
 # Original modern town ephemera, not quotations or invented attributed literature.
 var entries=[
 ["daily","索尔米尔日报 · 日常","本周的海港，晴天多了一点。",2,["QUIETER","ANOTHER JUNE","REMEMBERED","今天","慢一点","明天","有人","生活","每一步","有答案","来不及","总担心"]],
 ["novel","玛雅书店 · 留言卡","读者留下的日常便条。",1,["I REMEMBER","HERE","still","你","我","没说完的","话","留给","可以","不必","也可以换一种模样","只是"]],
 ["flyer","唱片店 · 周末演出单","演出结束以后，我们还在这里。",4,["STILL","RETURN","HERE","一起","听见","再一次","不完美","也没关系","这一刻","唱完","我的歌","声音"]],
 ["menu","柠檬咖啡馆 · 桌边小卡","六号桌，靠窗的位置。",1,["some places stay","LEMON","TWO","六号桌","给你","留了位置","喝一杯","柠檬汽水","我们","先","再","。"]],
 ["coast","海岸站 · 天气便条","往海边的公交，今天照常发车。",6,["看海","下雨的时候","太阳","还会","出来","海风","把","带走","等一等","出发","停下来","呼吸"]],
 ["neighbor","居民公告栏 · 小事","来自街坊的留言。",21,["给","那个","的","你","不用","一个人","撑着","我在","身边","有空","坐一会儿","吧"]],
 ["thanks","邮局 · 心意小条","不擅长开口，也可以慢慢拼。",3,["谢谢你","记得","那一天","一点点","勇气","已经","很好了","还有","新的","可能","想念","。"]],
 ["common","连接词与标点","剪字、换顺序，用现成的纸片表达。",1,["我","你","我们","是","的","也","和","但","因为","所以","只是","可以","不必","了","在","再","把","给","。","，","？","！","……","一起","都"]]
 ]
 var result=[]
 for entry in entries:
  var d=item(entry[0],entry[1],entry[2],"printed","来自索尔米尔居民的日常印刷品。",entry[3])
  for i in entry[4].size():
   var word=entry[4][i];var tags={}
   if word in ["ANOTHER JUNE","REMEMBERED","I REMEMBER","那一天"]:tags={"SHARED_MEMORY":2}
   if word=="RETURN":tags={"RETURN":3}
   if word=="谢谢你":tags={"GRATITUDE":3}
   var cut=region(word,tags);cut.print_variant=(result.size()+i/3)%7;d.cuts.append(cut)
  result.append(d)
 return result
static func example() -> Array:
 var rows=[
  ["给","那个","总担心","来不及","的","你"],
  ["今天","可以","慢一点"],
  ["把","没说完的","话","留给","明天"],
  ["有人","在","六号桌","给你","留了位置"],
  ["生活","不必","每一步","都","有答案"],
  ["我们","先","喝一杯","柠檬汽水"],
  ["再","一起","看海","。"]]
 var output=[];var index=0
 for y in rows.size():
  var x=514.0+[0,13,0,7,0,14,30][y]
  var lengths=0
  for word in rows[y]:lengths+=word.length()
  var zoom=minf(0.75,315.0/(lengths*27+rows[y].size()*20))
  for word in rows[y]:
   var v=posmod(index*3+y,7);var data={"id":"example_"+str(index),"word":word,"fragment":true,"print_variant":v,"tags":{}}
   output.append({"data":data,"at":[x,286+y*61+sin(index*2.1)*2],"zoom":zoom,"angle":sin(index*1.7)*2.8})
   x+=(preload("res://extensions/collage_letter/scripts/v3/cutout_style.gd").font_for(data).get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,27).x+20)*zoom;index+=1
 return output
static func validate(fragments:Array,required:Dictionary,avoided:Dictionary) -> Dictionary:
 var totals = {}; var seen = {};var phrases={}
 for fragment in fragments:
  if not fragment.has("phrase_id"):continue
  var id=str(fragment.phrase_id)
  if not phrases.has(id):phrases[id]={"indices":[],"count":int(fragment.segment_count),"tags":fragment.original_tags}
  if not phrases[id].indices.has(fragment.segment_index):phrases[id].indices.append(fragment.segment_index)
 var counted=fragments.duplicate()
 for id in phrases:
  if phrases[id].indices.size()==phrases[id].count:counted.append({"id":id,"tags":phrases[id].tags})
 for fragment in counted:
  if fragment.get("typed",false): continue
  var id = str(fragment.get("instance_id",fragment.get("id","")))
  if seen.has(id):continue
  seen[id]=true
  for key in fragment.get("tags",{}): totals[key]=float(totals.get(key,0))+float(fragment.tags[key])
 var missing=[];var violations=[]
 for key in required:
  if totals.get(key,0)<required[key]:missing.append(key)
 for key in avoided:
  if totals.get(key,0)>=avoided[key]:violations.append(key)
 return {"passed":missing.is_empty() and violations.is_empty(),"missing":missing,"violations":violations,"totals":totals}
