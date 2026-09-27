extends "res://tests/capture_player_tutorial.gd"
## Native paper chapter slate for joining recorded gameplay takes.
func run() -> void:
 output=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 setup_overlay(); caption.text=""; chapter_label.text=""; pointer.hide()
 var backing:=ColorRect.new(); backing.size=Vector2(1600,1008); backing.color=Color("f4e7c9"); overlay.add_child(backing)
 var sheet:=preload("res://modules/restaurant/ui/paper_surface.gd").new(); sheet.size=Vector2(1600,946); overlay.add_child(sheet)
 var box:=VBoxContainer.new(); box.position=Vector2(180,340); box.size=Vector2(1240,280); box.add_theme_constant_override("separation",24); sheet.add_child(box)
 for pair in [["100 RESTAURANT",20],["17  收班与结算",58],["回到刚才的营业，查看这一餐的实际收入",27]]:
  var label:=Label.new(); label.text=pair[0]; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_override("font",preload("res://modules/restaurant/ui/paper_ink.gd").font()); label.add_theme_font_size_override("font_size",pair[1]); label.add_theme_color_override("font_color",Color("554b3a")); box.add_child(label)
 await frames(60)
 var report:=FileAccess.open(output.path_join("card.json"),FileAccess.WRITE)
 report.store_string(JSON.stringify({"fps":FPS,"frames":frame,"skip_native_startup_frames":0,"startup_frames":0,"title":"17  收班与结算"},"  ")); report.close()
 print("PASS: native paper settlement slate, ",frame," frames"); quit(0)
