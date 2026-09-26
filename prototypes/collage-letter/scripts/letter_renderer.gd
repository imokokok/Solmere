extends Control
## One shaped, Unicode-safe paper renderer for drafts, received letters and replay.
signal finished
signal pages_changed
signal page_requested
enum State { IDLE, WRITING, PAUSED, FINISHING, FINISHED, FOLDING, INSERTING, SEALED, SENT }
enum Event { WRITE_CHARACTER, DELETE_CHARACTER, NEW_LINE, FINISH }
const HAND = preload("res://assets/fonts/xiaolai/Xiaolai-Regular.ttf")
var state: State = State.IDLE
var full_text := ""
var visual_text := ""
var text: String:
	get: return full_text
	set(value):
		if value != full_text: load_text(value)
var pending_characters: Array[Dictionary] = []
var active: Dictionary = {}
var paragraph := TextParagraph.new()
var ts := TextServerManager.get_primary_interface()
var lines: Array[Dictionary] = []
var page := 0
var page_count := 1
var minimum_pages := 1
var waiting_page := -1
var font_size := 19
var ink := Color("49594f")
var writing_speed := "Normal"
var reduce_motion := false
var pen_volume := 0.55
var pen_visible := false
var pen_position := Vector2(0,19)
var pen_target := Vector2(0,19)
var pen_from := Vector2.ZERO
var pen_clock := 1.0
var pen_duration := 0.05
var pen_lift := false
var pen_alpha := 1.0
var idle_time := 0.0
var caret_offset := 0
var composition := ""
var selection_from := -1
var selection_to := -1
var audio
var replaying := false
var skip_remaining := 0.0
var last_sound := -1.0
var sound_clock := 0.0
var last_sound_kind := ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	rng.randomize();resized.connect(reflow);reflow()

static func graphemes(value: String) -> Array[String]:
	var result: Array[String]=[];var start:=0
	for boundary in TextServerManager.get_primary_interface().string_get_character_breaks(value):
		result.append(value.substr(start,boundary-start));start=boundary
	return result

func load_text(value: String) -> void:
	full_text=value;visual_text=value;pending_characters.clear();active.clear();waiting_page=-1
	caret_offset=value.length();state=State.IDLE;pen_alpha=1.0;replaying=false;reflow()
	page=clampi(page,0,page_count-1);pen_target=caret_position(caret_offset);pen_position=pen_target

func submit(value: String) -> void:
	if state>=State.FINISHING or value==full_text:return
	# Diff against the last accepted input, not the lagging visual string. Events
	# remain ordered even when a selection is replaced while an earlier edit animates.
	var old:=graphemes(full_text);var fresh:=graphemes(value);var prefix:=0;var suffix:=0
	while prefix<mini(old.size(),fresh.size()) and old[prefix]==fresh[prefix]:prefix+=1
	while suffix<mini(old.size()-prefix,fresh.size()-prefix) and old[-suffix-1]==fresh[-suffix-1]:suffix+=1
	var offset:=0
	for i in prefix:offset+=old[i].length()
	var removal:=0
	for i in range(prefix,old.size()-suffix):removal+=old[i].length()
	for i in range(old.size()-suffix-1,prefix-1,-1):
		removal-=old[i].length();pending_characters.append({"kind":Event.DELETE_CHARACTER,"at":offset+removal,"value":old[i]})
	for i in range(prefix,fresh.size()-suffix):
		pending_characters.append({"kind":Event.NEW_LINE if fresh[i]=="\n" else Event.WRITE_CHARACTER,"at":offset,"value":fresh[i]});offset+=fresh[i].length()
	full_text=value;idle_time=0;pen_alpha=1.0
	if waiting_page<0:state=State.WRITING

func play_letter_animation(value: String) -> void:
	load_text("");page=0;pen_visible=true;submit(value);replaying=true

func skip() -> void:
	if replaying:skip_remaining=0.15;waiting_page=-1

func request_finish() -> void:
	if state>=State.FINISHING:return
	state=State.FINISHING;pending_characters.append({"kind":Event.FINISH,"at":full_text.length(),"value":""})

func turn_page(direction: int) -> void:
	var highest:=maxi(page_count-1,waiting_page)
	page=clampi(page+direction,0,highest)
	if page==waiting_page:
		waiting_page=-1
		if state==State.PAUSED:state=State.WRITING
	play_sound("paper_move",0.3);pen_position=caret_position(caret_offset);pen_target=pen_position
	pages_changed.emit();queue_redraw()

func reflow() -> void:
	paragraph.clear();paragraph.width=maxf(20,size.x-3)
	paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_GRAPHEME_BOUND
	paragraph.add_string(visual_text if not visual_text.is_empty() else " ",HAND,font_size)
	lines.clear();var y:=0.0;var sheet:=0
	for i in paragraph.get_line_count():
		var rid:=paragraph.get_line_rid(i);var height:=maxf(HAND.get_height(font_size),paragraph.get_line_size(i).y)+5
		if y+height>size.y-3 and y>0:y=0;sheet+=1
		lines.append({"rid":rid,"range":ts.shaped_text_get_range(rid),"y":y,"height":height,"page":sheet,"baseline":y+ts.shaped_text_get_ascent(rid)})
		y+=height
	var old:=page_count;page_count=maxi(sheet+1,minimum_pages)
	if old!=page_count:pages_changed.emit()
	queue_redraw()

func line_for_offset(offset: int) -> Dictionary:
	for i in lines.size():
		var line:=lines[i]
		if offset<int(line.range.y) or i==lines.size()-1:return line
	return {}

func caret_position(offset: int) -> Vector2:
	var line:=line_for_offset(offset)
	if line.is_empty():return Vector2(0,HAND.get_ascent(font_size))
	var carets: Dictionary=ts.shaped_text_get_carets(line.rid,clampi(offset,int(line.range.x),int(line.range.y)))
	var rect: Rect2=carets.get("leading_rect",Rect2())
	return Vector2(clampf(rect.position.x,0,size.x-4),line.baseline)

func hit_offset(point: Vector2) -> int:
	for line in lines:
		if line.page==page and point.y<line.y+line.height:
			return ts.shaped_text_hit_test_position(line.rid,point.x)
	for i in range(lines.size()-1,-1,-1):
		if lines[i].page==page:return mini(visual_text.length(),int(lines[i].range.y))
	return 0

func follow_caret(offset: int) -> void:
	if not pending_characters.is_empty() or not active.is_empty():return
	caret_offset=offset;var line:=line_for_offset(offset)
	if not line.is_empty() and page!=line.page:page=line.page;pages_changed.emit()
	move_pen(offset)

func move_pen(offset: int) -> void:
	pen_from=pen_position;pen_target=caret_position(offset);pen_clock=0
	pen_lift=absf(pen_target.y-pen_from.y)>font_size*0.7
	pen_duration=rng.randf_range(0.15,0.25) if pen_lift else rng.randf_range(0.03,0.07)
	if reduce_motion:pen_position=pen_target

func rhythm(value: String) -> float:
	var interval:=rng.randf_range(0.035,0.075)
	if value=="\n":interval=rng.randf_range(0.20,0.35)
	elif value.strip_edges().is_empty():interval=rng.randf_range(0.015,0.035)
	elif value in [",","，","、",";","；",":","："]:interval=rng.randf_range(0.10,0.16)
	elif value in [".","。","?","？","!","！"]:interval=rng.randf_range(0.16,0.24)
	var acceleration:=1.8 if pending_characters.size()>=9 else (1.3 if pending_characters.size()>=4 else 1.0)
	return interval/acceleration/(2.0 if writing_speed=="Fast" else 1.0)

func begin_event() -> void:
	if pending_characters.is_empty() or waiting_page>=0:return
	var event: Dictionary=pending_characters[0]
	if event.kind==Event.FINISH:
		pending_characters.pop_front();active=event;active.time=0.0;active.duration=0.38;return
	var old:=visual_text;var at:int=event.at;var value:String=event.value
	if event.kind!=Event.DELETE_CHARACTER:
		visual_text=old.substr(0,at)+value+old.substr(at);reflow()
		var target_line:=line_for_offset(at+value.length())
		if not target_line.is_empty() and int(target_line.page)>page and skip_remaining<=0:
			waiting_page=int(target_line.page);visual_text=old
			if state!=State.FINISHING:state=State.PAUSED
			reflow();page_requested.emit();pages_changed.emit();return
		if skip_remaining>0 and not target_line.is_empty():page=int(target_line.page)
	else:
		var target_line:=line_for_offset(at)
		if not target_line.is_empty() and int(target_line.page)!=page:page=target_line.page;pages_changed.emit()
	pending_characters.pop_front();active=event;active.time=0.0
	active.duration=rhythm(value) if event.kind!=Event.DELETE_CHARACTER else rng.randf_range(0.06,0.12)/(1.7 if pending_characters.size()>3 else 1.0)
	active.ink_time=minf(active.duration,rng.randf_range(0.04,0.08))
	caret_offset=at+(0 if event.kind==Event.DELETE_CHARACTER else value.length());move_pen(caret_offset)
	if skip_remaining<=0 and writing_speed!="Instant":
		if event.kind==Event.DELETE_CHARACTER:play_sound("erase",0.28)
		elif value=="\n":play_sound("paper_move",0.28)
		elif not value.strip_edges().is_empty():play_sound("pen_tap" if value in [".","。","!","！","?","？"] else "pen_scratch",pen_volume)
	queue_redraw()

func play_sound(kind: String, volume: float) -> void:
	if not is_instance_valid(audio) or pen_volume<=0:return
	if sound_clock-last_sound<0.095:return
	last_sound=sound_clock;last_sound_kind=kind;audio.play_pen(kind,volume*pen_volume if kind!="pen_scratch" else volume)

func end_event() -> void:
	if active.kind==Event.DELETE_CHARACTER:
		visual_text=visual_text.substr(0,active.at)+visual_text.substr(active.at+str(active.value).length());reflow()
	if active.kind==Event.FINISH:
		state=State.FINISHED;pen_alpha=0;active.clear();finished.emit();return
	active.clear()
	if pending_characters.is_empty() and state<State.FINISHING:state=State.PAUSED

func _process(delta: float) -> void:
	if pending_characters.is_empty() and active.is_empty() and not pen_visible and composition.is_empty():return
	sound_clock+=delta;idle_time+=delta;pen_clock+=delta
	if not reduce_motion:
		var f:=clampf(pen_clock/pen_duration,0,1);pen_position=pen_from.lerp(pen_target,smoothstep(0,1,f))
	var budget:=delta
	if skip_remaining>0:
		# Skipping is a bounded settle, not hundreds of per-glyph reflows in one
		# frame. Long letters must remain responsive on a busy rendering device.
		skip_remaining=maxf(0,skip_remaining-delta);pen_alpha=skip_remaining/.15
		if skip_remaining<=0:
			visual_text=full_text;pending_characters.clear();active.clear();waiting_page=-1;replaying=false;state=State.PAUSED
			reflow();page=0;caret_offset=visual_text.length();pages_changed.emit()
		queue_redraw();return
	if writing_speed=="Instant":budget=10000
	for _step in 4096:
		if active.is_empty():begin_event()
		if active.is_empty():break
		var remaining:float=active.duration-active.time
		# Finish always keeps its quiet pause, even in Instant mode.
		var used:=minf(remaining,delta if active.kind==Event.FINISH else budget)
		active.time+=used;budget-=used
		if active.kind==Event.FINISH:pen_alpha=1.0-clampf((active.time-0.2)/0.18,0,1)
		if active.time+0.0001>=active.duration:end_event()
		else:break
		if budget<=0:break
	if idle_time>1.5 and pending_characters.is_empty() and active.is_empty() and state==State.WRITING:state=State.PAUSED
	queue_redraw()

func _draw() -> void:
	for line in lines:
		if line.page!=page:continue
		var x:=0.0
		for glyph in ts.shaped_text_get_glyphs(line.rid):
			var alpha:=1.0
			if not active.is_empty() and active.kind!=Event.FINISH and int(glyph.start)<int(active.at)+str(active.value).length() and int(glyph.end)>int(active.at):
				alpha=1.0-clampf(active.time/active.duration,0,1) if active.kind==Event.DELETE_CHARACTER else clampf(active.time/active.ink_time,0,1)
			# Stable ink density variation; shaped advances/kerning stay untouched.
			alpha*=0.96+float(posmod(int(glyph.start)*31,5))*0.01
			if selection_from>=0 and int(glyph.start)<selection_to and int(glyph.end)>selection_from:
				draw_rect(Rect2(x,line.y,glyph.advance*glyph.repeat,line.height),Color(0.6,0.65,0.5,0.18))
			for _repeat in int(glyph.repeat):
				if glyph.font_rid.is_valid() and glyph.index!=0:ts.font_draw_glyph(glyph.font_rid,get_canvas_item(),glyph.font_size,Vector2(x,line.baseline)+glyph.offset,glyph.index,Color(ink,alpha))
				x+=glyph.advance
	if not composition.is_empty():
		draw_string(HAND,pen_position,composition,HORIZONTAL_ALIGNMENT_LEFT,maxf(20,size.x-pen_position.x),font_size,Color(ink,0.55))
		draw_line(pen_position+Vector2(0,3),pen_position+Vector2(minf(80,size.x-pen_position.x),3),Color(ink,0.4),1)

func set_ink(color: Color) -> void:
	ink=color;queue_redraw()

func ink_color() -> Color:return ink
func get_line_count() -> int:return lines.size()
