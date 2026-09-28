extends Node2D
const Tuning=preload("res://modules/restaurant/domain/physical_tuning.gd")
## Finite-volume surface film + ballistic transport. No decorative water creates mass.
## This is a shallow 2D game model, not CFD. Amounts are ml throughout.
const COLS := 64
const ROWS := 8
const CELL := Vector2(25, 16)
const ORIGIN := Vector2(0, 670)
var world: Node2D
var cells := PackedFloat64Array()
var flights: Array[Dictionary] = []
var floor_cells := PackedFloat64Array()
var drained_ml := 0.0
var floor_ml := 0.0
var wiped_ml := 0.0
var received_ml := 0.0
var recent_rate := 0.0
var clock := 0.0
var sink_overflow_ml := 0.0

func _init() -> void:
	cells.resize(COLS * ROWS)
	cells.fill(0.0)
	floor_cells.resize(COLS)
	floor_cells.fill(0.0)

func emit_water(amount: float, origin: Vector2, velocity := Vector2.ZERO) -> void:
	if amount <= 0.0 or not is_finite(amount): return
	received_ml += amount
	# A parcel remembers its real origin even if the player moves the pan away.
	flights.append({"ml": amount, "p": origin, "v": velocity.limit_length(350) + Vector2(0, 28), "trail": PackedVector2Array([origin]), "age": 0.0, "floor": false})

func _physics_process(dt: float) -> void:
	if world.controls_enabled: advance(dt)
	queue_redraw()

func advance(dt: float) -> void:
	if received_ml <= 0.0: return
	var remaining := dt
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 120.0)
		_step(step)
		remaining -= step

func _step(dt: float) -> void:
	clock += dt
	recent_rate *= exp(-dt * 5.0)
	for i in range(flights.size() - 1, -1, -1):
		var parcel := flights[i]
		parcel.age += dt
		parcel.v.y += 980.0 * dt
		parcel.p += parcel.v * dt
		var trail: PackedVector2Array = parcel.trail
		trail.append(parcel.p)
		if trail.size() > 24: trail.remove_at(0)
		parcel.trail = trail
		var sink: bool = parcel.p.x > 35 and parcel.p.x < 370
		var surface: float = 900.0 if parcel.get("floor",false) else (world.pan.faucet_art.sink_surface_y() if sink else 736.0)
		if parcel.p.y >= surface:
			if parcel.get("floor",false):
				floor_ml += float(parcel.ml)
				floor_cells[clampi(int(parcel.p.x / CELL.x),0,COLS-1)] += float(parcel.ml)
			elif sink: _receive_sink(float(parcel.ml))
			else: _deposit(parcel.p, float(parcel.ml))
			recent_rate += float(parcel.ml) * 5.0
			flights.remove_at(i)
	# Pairwise exchanges use the same source snapshot and a stable diffusion rate.
	# This grows a connected footprint outward from the actual impact cell.
	var change := PackedFloat64Array()
	change.resize(cells.size())
	for y in ROWS:
		for x in COLS:
			var a := y * COLS + x
			for b in [a + 1 if x + 1 < COLS else -1, a + COLS if y + 1 < ROWS else -1]:
				if b < 0: continue
				var flow := (cells[a] - cells[b]) * minf(dt * 4.0, 0.12)
				change[a] -= flow
				change[b] += flow
	for i in cells.size(): cells[i] = maxf(0.0, cells[i] + change[i])
	for y in ROWS:
		for x in COLS:
			var i := y * COLS + x
			var p := ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL
			if p.x > 35 and p.x < 370:
				var drained := cells[i] * (1.0 - exp(-dt * 5.0))
				cells[i] -= drained
				_receive_sink(drained)
			elif y == ROWS - 1 and cells[i] > 8.0:
				var falling := (cells[i] - 8.0) * (1.0 - exp(-dt * 1.8))
				cells[i] -= falling
				if falling > 0.0001:
					flights.append({"ml":falling,"p":Vector2(p.x,ORIGIN.y+ROWS*CELL.y),"v":Vector2(0,25),"age":0.0,"trail":PackedVector2Array([Vector2(p.x,ORIGIN.y+ROWS*CELL.y)]),"floor":true})
				else: cells[i] += falling
	var floor_change := PackedFloat64Array()
	floor_change.resize(COLS)
	for x in COLS-1:
		var transfer := (floor_cells[x]-floor_cells[x+1])*minf(dt*12.0,0.12)
		floor_change[x]-=transfer
		floor_change[x+1]+=transfer
	for x in COLS: floor_cells[x]+=floor_change[x]
	# The sink brim feeds an actual downward parcel from its visible front edge.
	var overflow:=sink_overflow_ml*(1.0-exp(-dt*10.0))
	sink_overflow_ml-=overflow
	if overflow>0.000001:
		var origin:=Vector2(343,744)
		flights.append({"ml":overflow,"p":origin,"v":Vector2(15,25),"age":0.0,"trail":PackedVector2Array([origin]),"floor":true})
	else: sink_overflow_ml+=overflow
	# Turning off the tap lets finite standing water drain; no visual reset.
	if not world.pan.faucet_on:
		var sink_drain:=minf(world.sink_water_ml,dt*Tuning.number("liquid","sink_drain_ml_s"))
		world.sink_water_ml-=sink_drain
		drained_ml+=sink_drain
		var floor_drain:=minf(floor_ml,dt*Tuning.number("liquid","floor_drain_ml_s"))
		if floor_ml>0:
			var retained:=maxf(0.0,1.0-floor_drain/floor_ml)
			for x in COLS: floor_cells[x]*=retained
		floor_ml-=floor_drain
		drained_ml+=floor_drain
	var beyond:=maxf(0.0,floor_ml-world.KITCHEN_FLOOD_ML)
	if beyond>0:
		var retained: float=world.KITCHEN_FLOOD_ML/floor_ml
		for x in COLS: floor_cells[x]*=retained
		floor_ml-=beyond
		drained_ml+=beyond
	world.flood_water_ml=floor_ml
	world.drained_flood_ml=drained_ml
	if is_instance_valid(world.flood_art): world.flood_art.queue_redraw()

func _receive_sink(amount: float) -> void:
	var accepted:=minf(amount,maxf(0.0,world.SINK_HOLD_ML-world.sink_water_ml))
	world.sink_water_ml+=accepted
	sink_overflow_ml+=amount-accepted


func _deposit(p: Vector2, amount: float) -> void:
	var x := clampi(int((p.x - ORIGIN.x) / CELL.x), 0, COLS - 1)
	var y := clampi(int((p.y - ORIGIN.y) / CELL.y), 0, ROWS - 1)
	cells[y * COLS + x] += amount

func inventory() -> Dictionary:
	var surface := 0.0
	var flying := 0.0
	for amount in cells: surface += amount
	for parcel in flights: flying += float(parcel.ml)
	return {"sink_ml":world.sink_water_ml,"sink_overflow_ml":sink_overflow_ml,"received_ml": received_ml, "surface_ml": surface, "flight_ml": flying, "drained_ml": drained_ml, "floor_ml": floor_ml, "wiped_ml": wiped_ml}

func wipe(p: Vector2, capacity: float) -> float:
	var removed := 0.0
	for i in cells.size():
		var center := ORIGIN + Vector2(i % COLS + 0.5, int(i / COLS) + 0.5) * CELL
		if center.distance_to(p) > 48.0: continue
		var take := minf(cells[i], maxf(0.0, capacity - removed))
		cells[i] -= take
		removed += take
	wiped_ml += removed
	return removed

func _draw() -> void:
	# Adjacent cells share vertices so the film has no rectangular seams.
	for y in ROWS - 1:
		for x in COLS - 1:
			var i := y * COLS + x
			var values := [cells[i], cells[i+1], cells[i+COLS+1], cells[i+COLS]]
			if values.max() < 0.02: continue
			var p := ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL
			var colors := PackedColorArray()
			for v in values: colors.append(Color(0.68, 0.82, 0.78, minf(0.48, float(v) / 18.0)))
			draw_polygon(PackedVector2Array([p, p+Vector2(CELL.x,0), p+CELL, p+Vector2(0,CELL.y)]), colors)
	for parcel in flights:
		var trail: PackedVector2Array = parcel.trail
		if trail.size() > 1:
			draw_polyline(trail, Color(0.64,0.83,0.80,0.22), clampf(sqrt(float(parcel.ml))*2.3,0.8,4.0), true)

func clear() -> void:
	world.sink_water_ml=0.0
	world.flood_water_ml=0.0
	world.drained_flood_ml=0.0
	sink_overflow_ml=0.0
	cells.fill(0.0)
	floor_cells.fill(0.0)
	flights.clear()
	drained_ml=0.0
	floor_ml=0.0
	wiped_ml=0.0
	received_ml=0.0
	recent_rate=0.0
