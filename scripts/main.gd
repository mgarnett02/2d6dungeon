extends Control
## Game controller: builds the interface and runs the explore / fight / town loop.

const Dice = preload("res://scripts/dice.gd")
const GameData = preload("res://scripts/game_data.gd")
const Player = preload("res://scripts/player.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const Combat = preload("res://scripts/combat.gd")
const MapView = preload("res://scripts/map_view.gd")
const DiceView = preload("res://scripts/dice_view.gd")
const StatBar = preload("res://scripts/stat_bar.gd")
const MonsterView = preload("res://scripts/monster_view.gd")
const TownView = preload("res://scripts/town_view.gd")

const C_BG := Color("1b1612")
const C_PANEL := Color("2b221b")
const C_EDGE := Color("6b5236")
const C_GOLD := Color("e0b04f")
const C_TEXT := Color("eadcc0")
const C_DIM := Color("9c8a70")
const C_RED := Color("c0392b")
const C_GREEN := Color("6aa84f")
const C_BLUE := Color("4fa3e0")

const DIR_NAMES := {
	Vector2i(0, -1): "north", Vector2i(1, 0): "east",
	Vector2i(0, 1): "south", Vector2i(-1, 0): "west",
}

const REST_COST := 5
const POTION_COST := 8
const TRAIN_COST := 30
const TRAP_AVOID := 7

## "title", "town", "explore", "prompt", "combat" or "dead".
var mode := "title"
var busy := false
var player = null
var dungeon = null
var combat = null
var current_room := 0
var previous_room := 0
var pending_weapon := ""

# Main screen
var map_view
var room_title: Label
var room_text: RichTextLabel
var room_dice: Array = []
var actions_box: VBoxContainer
var log_text: RichTextLabel
var hero_label: Label
var stats_label: Label
var hp_bar
var shift_bar
var xp_bar

# Combat screen
var combat_layer: Control
var combat_title: Label
var monster_view
var enemy_name: Label
var enemy_bar
var enemy_stats: Label
var player_dice: Array = []
var enemy_dice: Array = []
var shift_buttons: Array = []
var dice_hint: Label
var moves_box: VBoxContainer
var roll_button: Button
var potion_button: Button
var flee_button: Button
var combat_log: RichTextLabel

# Other screens
var town_layer: Control
var town_info: RichTextLabel
var town_buttons: GridContainer
var title_layer: Control
var title_dice: Array = []
var over_layer: Control
var over_text: RichTextLabel
var hurt_flash: ColorRect


func _ready() -> void:
	Dice.rng.randomize()
	theme = _make_theme()
	_build_main()
	_build_combat_layer()
	_build_town_layer()
	_build_title_layer()
	_build_over_layer()
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.7, 0.0, 0.0, 0.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hurt_flash)
	title_layer.visible = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if mode == "combat" and key.keycode == KEY_R and not roll_button.disabled:
		_on_roll()


# ---------------------------------------------------------------- UI building

func _make_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "DejaVu Serif", "serif"])
	t.default_font = font
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_EDGE, 2, 6, 10))
	t.set_stylebox("normal", "Button", _box(Color("3a2d22"), C_EDGE, 2, 4, 6))
	t.set_stylebox("hover", "Button", _box(Color("4d3b2b"), C_GOLD, 2, 4, 6))
	t.set_stylebox("pressed", "Button", _box(Color("5e4732"), C_GOLD, 2, 4, 6))
	t.set_stylebox("disabled", "Button", _box(Color("241c16"), Color("3d3125"), 2, 4, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_GOLD)
	t.set_color("font_pressed_color", "Button", C_GOLD)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", Color("6a5a48"))
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", _box(C_PANEL, C_GOLD, 1, 4, 8))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	return t


func _box(bg: Color, edge: Color, border: int, radius: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func _label(text: String, font_size := 16, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _btn(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(callback)
	return b


func _rich(min_height := 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.custom_minimum_size = Vector2(0, min_height)
	r.selection_enabled = false
	return r


func _overlay(bg_color: Color) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	layer.visible = false
	add_child(layer)
	return layer


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _build_main() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Top bar
	var top := PanelContainer.new()
	root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	hero_label = _label("", 18, C_GOLD)
	row.add_child(hero_label)
	row.add_child(_label("HP", 14, C_DIM))
	hp_bar = StatBar.new()
	hp_bar.fill = Color("b03a2e")
	hp_bar.custom_minimum_size = Vector2(170, 26)
	row.add_child(hp_bar)
	row.add_child(_label("Shift", 14, C_DIM))
	shift_bar = StatBar.new()
	shift_bar.pips = true
	shift_bar.fill = C_BLUE
	shift_bar.custom_minimum_size = Vector2(120, 26)
	row.add_child(shift_bar)
	row.add_child(_label("XP", 14, C_DIM))
	xp_bar = StatBar.new()
	xp_bar.fill = C_GREEN
	xp_bar.custom_minimum_size = Vector2(110, 26)
	row.add_child(xp_bar)
	stats_label = _label("", 15)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(stats_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)

	# Map
	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(map_panel)
	map_view = MapView.new()
	map_view.door_clicked.connect(_on_door_clicked)
	map_view.room_clicked.connect(_on_room_clicked)
	map_panel.add_child(map_view)

	# Side panel
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(390, 0)
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)

	var room_panel := PanelContainer.new()
	side.add_child(room_panel)
	var rv := VBoxContainer.new()
	room_panel.add_child(rv)
	var title_row := HBoxContainer.new()
	rv.add_child(title_row)
	room_title = _label("", 21, C_GOLD)
	room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_title.clip_text = true
	title_row.add_child(room_title)
	for i in 2:
		var d = DiceView.new()
		d.custom_minimum_size = Vector2(36, 36)
		title_row.add_child(d)
		room_dice.append(d)
	room_text = _rich()
	room_text.fit_content = true
	rv.add_child(room_text)

	var act_panel := PanelContainer.new()
	side.add_child(act_panel)
	actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 5)
	act_panel.add_child(actions_box)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(log_panel)
	log_text = _rich()
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 14)
	log_text.add_theme_font_size_override("bold_font_size", 14)
	log_panel.add_child(log_text)


func _build_combat_layer() -> void:
	combat_layer = _overlay(Color(0, 0, 0, 0.72))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1020, 620)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	combat_title = _label("", 24, C_GOLD)
	combat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(combat_title)

	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)

	# Enemy column
	var ev := VBoxContainer.new()
	ev.custom_minimum_size = Vector2(300, 0)
	h.add_child(ev)
	monster_view = MonsterView.new()
	monster_view.custom_minimum_size = Vector2(300, 250)
	ev.add_child(monster_view)
	enemy_name = _label("", 20, C_RED)
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(enemy_name)
	enemy_bar = StatBar.new()
	enemy_bar.fill = C_RED
	enemy_bar.custom_minimum_size = Vector2(300, 26)
	ev.add_child(enemy_bar)
	enemy_stats = _label("", 14, C_DIM)
	enemy_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_stats.custom_minimum_size = Vector2(300, 0)
	ev.add_child(enemy_stats)

	# Dice column
	var dv := VBoxContainer.new()
	dv.custom_minimum_size = Vector2(270, 0)
	dv.add_theme_constant_override("separation", 8)
	h.add_child(dv)
	dv.add_child(_label("Your attack dice", 16, C_DIM))
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 26)
	dv.add_child(drow)
	for i in 2:
		var col := VBoxContainer.new()
		drow.add_child(col)
		var up := _btn("Shift +1", _on_shift.bind(i, 1))
		up.alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(up)
		var die = DiceView.new()
		die.custom_minimum_size = Vector2(100, 100)
		col.add_child(die)
		var down := _btn("Shift -1", _on_shift.bind(i, -1))
		down.alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(down)
		player_dice.append(die)
		shift_buttons.append(up)
		shift_buttons.append(down)
	dice_hint = _label("", 15, C_GOLD)
	dice_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_hint.custom_minimum_size = Vector2(270, 60)
	dv.add_child(dice_hint)
	dv.add_child(_label("Enemy dice", 16, C_DIM))
	var erow := HBoxContainer.new()
	erow.alignment = BoxContainer.ALIGNMENT_CENTER
	erow.add_theme_constant_override("separation", 16)
	dv.add_child(erow)
	for i in 2:
		var die = DiceView.new()
		die.custom_minimum_size = Vector2(60, 60)
		die.face_color = Color("d9a3a0")
		erow.add_child(die)
		enemy_dice.append(die)

	# Manoeuvre column
	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.add_theme_constant_override("separation", 5)
	h.add_child(mv)
	mv.add_child(_label("Manoeuvres", 18, C_GOLD))
	moves_box = VBoxContainer.new()
	moves_box.add_theme_constant_override("separation", 4)
	moves_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(moves_box)
	roll_button = _btn("Roll attack dice  [R]", _on_roll)
	mv.add_child(roll_button)
	potion_button = _btn("", _on_combat_potion)
	mv.add_child(potion_button)
	flee_button = _btn("Flee (need %d+ on 2d6)" % Combat.FLEE_TARGET, _on_flee)
	mv.add_child(flee_button)

	combat_log = _rich(110)
	combat_log.scroll_following = true
	combat_log.add_theme_font_size_override("normal_font_size", 14)
	combat_log.add_theme_font_size_override("bold_font_size", 14)
	v.add_child(combat_log)


func _build_town_layer() -> void:
	town_layer = _overlay(C_BG)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	town_layer.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	var view_panel := PanelContainer.new()
	view_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(view_panel)
	var town_view = TownView.new()
	view_panel.add_child(town_view)
	var bottom := PanelContainer.new()
	v.add_child(bottom)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	bottom.add_child(h)
	town_info = _rich(250)
	town_info.custom_minimum_size = Vector2(420, 250)
	h.add_child(town_info)
	town_buttons = GridContainer.new()
	town_buttons.columns = 2
	town_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	town_buttons.add_theme_constant_override("h_separation", 8)
	town_buttons.add_theme_constant_override("v_separation", 6)
	h.add_child(town_buttons)


func _build_title_layer() -> void:
	title_layer = _overlay(Color("120e0b"))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 20)
	v.add_child(dice_row)
	for i in 2:
		var d = DiceView.new()
		d.custom_minimum_size = Vector2(84, 84)
		d.value = 6
		dice_row.add_child(d)
		title_dice.append(d)
	var t := _label("2D6 DUNGEON", 64, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("A solo dungeon crawl decided by two six-sided dice", 18, C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var rules := _rich()
	rules.fit_content = true
	rules.custom_minimum_size = Vector2(700, 0)
	rules.text = (
		"[b]How to play[/b]\n"
		+ "- Open a door to roll 2d6: the dice are the width and height of the next room. A 1 makes a corridor.\n"
		+ "- Each new room rolls on a contents table: creatures, traps, treasure, shrines.\n"
		+ "- In combat roll two attack dice. If they match a manoeuvre's pair it fires. Spend [color=#4fa3e0]shift points[/color] to nudge a die by one pip.\n"
		+ "- Doubles are a critical hit, but double ones are a fumble.\n"
		+ "- Find the stairs to go deeper. Climb out from a stair landing to rest and shop in town."
	)
	v.add_child(rules)
	var start := _btn("Begin a new adventure", _new_game)
	start.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.custom_minimum_size = Vector2(320, 48)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 20)
	v.add_child(start)
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_roll_title_dice)
	title_layer.add_child(timer)


func _roll_title_dice() -> void:
	if not title_layer.visible:
		return
	for d in title_dice:
		d.roll_to(Dice.d6(), 0.6)


func _build_over_layer() -> void:
	over_layer = _overlay(Color(0.07, 0.02, 0.02, 0.94))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var t := _label("YOU HAVE DIED", 56, C_RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	over_text = _rich()
	over_text.fit_content = true
	over_text.custom_minimum_size = Vector2(600, 0)
	v.add_child(over_text)
	var again := _btn("Roll up a new adventurer", _new_game)
	again.alignment = HORIZONTAL_ALIGNMENT_CENTER
	again.custom_minimum_size = Vector2(320, 48)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(again)


# ---------------------------------------------------------------- logging & HUD

func _log(line: String) -> void:
	log_text.append_text(line + "\n")


func _clog(line: String) -> void:
	combat_log.append_text(line + "\n")
	_log(line)


func _refresh_stats() -> void:
	if player == null:
		return
	hero_label.text = "Adventurer  Lv %d" % player.level
	hp_bar.set_values(player.hp, player.max_hp, "%d / %d" % [player.hp, player.max_hp])
	shift_bar.set_values(player.shift, player.max_shift)
	xp_bar.set_values(player.xp, player.xp_to_next(), "%d / %d" % [player.xp, player.xp_to_next()])
	var depth: int = dungeon.depth if dungeon != null else 0
	stats_label.text = "%s    Armour %d    Gold %d    Potions %d    Depth %d" % [
		player.weapon_name, player.armor, player.gold, player.potions, depth]


func _flash_hurt() -> void:
	var tw := create_tween()
	tw.tween_property(hurt_flash, "color", Color(0.7, 0.0, 0.0, 0.35), 0.06)
	tw.tween_property(hurt_flash, "color", Color(0.7, 0.0, 0.0, 0.0), 0.45)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# ---------------------------------------------------------------- game flow

func _new_game() -> void:
	player = Player.new()
	dungeon = null
	combat = null
	busy = false
	log_text.clear()
	title_layer.visible = false
	over_layer.visible = false
	combat_layer.visible = false
	_log("[color=#e0b04f]A new adventurer arrives in town with a rusty sword and big dreams.[/color]")
	_open_town()


func _open_town() -> void:
	mode = "town"
	town_layer.visible = true
	player.deepest = maxi(player.deepest, dungeon.depth if dungeon != null else 1)
	_refresh_town()
	_refresh_stats()


func _refresh_town() -> void:
	var p = player
	town_info.text = (
		"[font_size=22][color=#e0b04f]The Town of Lowgate[/color][/font_size]\n"
		+ "A muddy little town huddled around the dungeon gate.\n\n"
		+ "Health [color=#c0392b]%d / %d[/color]    Shift [color=#4fa3e0]%d / %d[/color]\n" % [p.hp, p.max_hp, p.shift, p.max_shift]
		+ "Gold [color=#e0b04f]%d[/color]    Potions %d    Armour %d\n" % [p.gold, p.potions, p.armor]
		+ "Weapon: [b]%s[/b]\n" % p.weapon_name
		+ "Deepest level reached: %d    Creatures slain: %d" % [p.deepest, p.kills]
	)
	_clear(town_buttons)

	var rest := _btn("Rest at the inn (%d gold): full HP and shift" % REST_COST, _town_rest)
	rest.disabled = p.gold < REST_COST or (p.hp == p.max_hp and p.shift == p.max_shift)
	town_buttons.add_child(rest)

	var potion := _btn("Buy a healing potion (%d gold)" % POTION_COST, _town_potion)
	potion.disabled = p.gold < POTION_COST
	town_buttons.add_child(potion)

	if p.armor < Player.MAX_ARMOR:
		var cost := _armor_cost()
		var armor := _btn("Armourer: +1 armour (%d gold)" % cost, _town_armor)
		armor.disabled = p.gold < cost
		town_buttons.add_child(armor)

	if p.learned.size() < GameData.LEARNABLE.size():
		var train := _btn("Weapon master: learn a manoeuvre (%d gold)" % TRAIN_COST, _town_train)
		train.disabled = p.gold < TRAIN_COST
		town_buttons.add_child(train)

	for w in GameData.WEAPONS:
		var info: Dictionary = GameData.WEAPONS[w]
		if w == p.weapon_name or info.price == 0:
			continue
		var buy := _btn("Buy %s (%d gold)" % [w, info.price], _town_weapon.bind(w))
		buy.disabled = p.gold < info.price
		buy.tooltip_text = GameData.moves_text(info.moves)
		town_buttons.add_child(buy)

	var enter := _btn("Enter the dungeon (level 1)", _enter_dungeon.bind(1))
	enter.add_theme_color_override("font_color", C_GOLD)
	town_buttons.add_child(enter)
	if p.deepest > 1:
		var deep := _btn("Take the old shaft down to level %d" % p.deepest, _enter_dungeon.bind(p.deepest))
		deep.add_theme_color_override("font_color", C_GOLD)
		town_buttons.add_child(deep)
	_refresh_stats()


func _armor_cost() -> int:
	return 20 + 15 * player.armor


func _town_rest() -> void:
	player.gold -= REST_COST
	player.hp = player.max_hp
	player.shift = player.max_shift
	_log("You sleep soundly at the inn. Health and shift restored.")
	_refresh_town()


func _town_potion() -> void:
	player.gold -= POTION_COST
	player.potions += 1
	_log("You buy a healing potion.")
	_refresh_town()


func _town_armor() -> void:
	player.gold -= _armor_cost()
	player.armor += 1
	_log("The armourer fits you with better protection (armour %d)." % player.armor)
	_refresh_town()


func _town_train() -> void:
	var m: Dictionary = player.learn_random()
	if m.is_empty():
		return
	player.gold -= TRAIN_COST
	_log("The weapon master teaches you [b]%s[/b] (%d-%d)." % [m.name, m.pair[0], m.pair[1]])
	_refresh_town()


func _town_weapon(weapon: String) -> void:
	player.gold -= GameData.WEAPONS[weapon].price
	player.weapon_name = weapon
	_log("You buy a %s." % weapon)
	_refresh_town()


func _enter_dungeon(depth: int) -> void:
	town_layer.visible = false
	dungeon = Dungeon.new(depth)
	player.deepest = maxi(player.deepest, depth)
	current_room = 0
	previous_room = 0
	mode = "explore"
	map_view.set_dungeon(dungeon)
	map_view.current_room = 0
	map_view.token_pos = dungeon.rooms[0].center()
	for d in room_dice:
		d.value = 4
	if depth == 1:
		_log("You descend the worn steps into the dungeon.")
	else:
		_log("[color=#e0b04f]You reach dungeon level %d.[/color]" % depth)
	_show_room()


func _show_room() -> void:
	if dungeon == null:
		return
	var room = dungeon.rooms[current_room]
	room_title.text = room.name
	for i in 2:
		if not room_dice[i].is_rolling():
			room_dice[i].value = room.dice[i]
	var kind_text := "Corridor" if room.kind == "corridor" else "Chamber"
	var t: String = "[color=#9c8a70]%s, %d x %d squares (rolled %d and %d)[/color]\n" % [
		kind_text, room.rect.size.x, room.rect.size.y, room.dice[0], room.dice[1]]
	if room.kind == "entrance":
		t += "Daylight filters down the steps from town.\n" if dungeon.depth == 1 else "These stairs climb back towards the surface.\n"
	if not room.resolved:
		match room.content:
			"creature", "hoard":
				t += "[color=#c0392b]A %s lurks here.[/color]\n" % room.enemy.name
			"shrine":
				t += "[color=#4fa3e0]A shrine glows with a soft blue light.[/color]\n"
	elif room.kind != "entrance":
		t += "The room is quiet.\n"
	if room.stairs:
		t += "[color=#e0b04f]Worn stairs spiral down into darkness.[/color]\n"
	var unexplored := 0
	for idx in room.doors:
		var d: Dictionary = dungeon.doors[idx]
		if d.b < 0 and not d.blocked:
			unexplored += 1
	t += "Unexplored doors: %d" % unexplored
	room_text.text = t
	map_view.current_room = current_room
	map_view.interactive = mode == "explore"
	_build_actions()
	_refresh_stats()


func _build_actions() -> void:
	_clear(actions_box)
	if mode == "prompt":
		var w: Dictionary = GameData.WEAPONS[pending_weapon]
		var take := _btn("Take the %s (leave your %s)" % [pending_weapon, player.weapon_name], _take_weapon.bind(true))
		take.tooltip_text = GameData.moves_text(w.moves)
		actions_box.add_child(take)
		actions_box.add_child(_btn("Leave it", _take_weapon.bind(false)))
		return
	if mode != "explore":
		return
	var room = dungeon.rooms[current_room]
	for idx in room.doors:
		var d: Dictionary = dungeon.doors[idx]
		if d.blocked:
			continue
		var dir_name: String = DIR_NAMES[dungeon.door_dir_from(idx, current_room)]
		if d.b < 0:
			var b := _btn("Open the %s door (roll 2d6)" % dir_name, _on_door_clicked.bind(idx))
			b.add_theme_color_override("font_color", C_GOLD)
			actions_box.add_child(b)
		else:
			var other = dungeon.rooms[dungeon.other_side(idx, current_room)]
			actions_box.add_child(_btn("Go %s to the %s" % [dir_name, other.name], _on_room_clicked.bind(other.id)))
	if room.content == "shrine" and not room.resolved:
		actions_box.add_child(_btn("Pray at the shrine", _pray))
	if room.stairs and not room.blocks_passage():
		var down := _btn("Descend to level %d" % (dungeon.depth + 1), _descend)
		down.add_theme_color_override("font_color", C_GOLD)
		actions_box.add_child(down)
	if room.kind == "entrance":
		actions_box.add_child(_btn("Climb back to town", _leave_dungeon))
	if player.potions > 0 and player.hp < player.max_hp:
		actions_box.add_child(_btn("Drink a potion (%d left)" % player.potions, _explore_potion))


func _on_door_clicked(idx: int) -> void:
	if mode != "explore" or busy:
		return
	busy = true
	map_view.interactive = false
	var dir_name: String = DIR_NAMES[dungeon.door_dir_from(idx, current_room)]
	var res: Dictionary = dungeon.explore(idx)
	var roll: Array = res.roll
	for i in 2:
		room_dice[i].roll_to(roll[i], 0.5)
	await _wait(0.6)
	if not res.ok:
		_log("You force the %s door (rolled %d and %d) but the passage beyond has collapsed." % [dir_name, roll[0], roll[1]])
		busy = false
		_show_room()
		return
	var room = dungeon.rooms[res.room]
	var shape := "corridor" if room.kind == "corridor" else "chamber"
	_log("You open the %s door. [color=#e0b04f]%d[/color] and [color=#e0b04f]%d[/color]: a %d x %d %s, the %s." % [
		dir_name, roll[0], roll[1], room.rect.size.x, room.rect.size.y, shape, room.name])
	await _walk([current_room, room.id])
	previous_room = current_room
	current_room = room.id
	busy = false
	_arrive()


func _on_room_clicked(rid: int) -> void:
	if mode != "explore" or busy or rid == current_room:
		return
	var path: Array = dungeon.find_path(current_room, rid)
	if path.is_empty():
		return
	busy = true
	map_view.interactive = false
	await _walk(path)
	previous_room = path[path.size() - 2]
	current_room = rid
	busy = false
	_arrive()


## Moves the map token along a list of room ids, passing through each door.
func _walk(path: Array) -> void:
	if path.size() < 2:
		return
	var tw := create_tween()
	for i in range(1, path.size()):
		var d: int = dungeon.door_between(path[i - 1], path[i])
		if d >= 0:
			tw.tween_property(map_view, "token_pos", dungeon.door_point(d), 0.14)
		tw.tween_property(map_view, "token_pos", dungeon.rooms[path[i]].center(), 0.14)
	await tw.finished


## Resolves whatever waits in the room the player has just entered.
func _arrive() -> void:
	var room = dungeon.rooms[current_room]
	_show_room()
	if room.resolved:
		return
	match room.content:
		"creature", "hoard":
			_start_combat(room)
		"trap":
			await _spring_trap(room)
		"loot":
			_give_loot(room)
		"shrine":
			_log("A small shrine stands here, candles still burning.")
		_:
			room.resolved = true
	if mode == "explore" or mode == "prompt":
		_show_room()


func _spring_trap(room) -> void:
	busy = true
	var trap: String = GameData.pick(GameData.TRAPS)
	var roll: Array = Dice.roll2()
	for i in 2:
		room_dice[i].roll_to(roll[i], 0.5)
	await _wait(0.6)
	var total: int = roll[0] + roll[1]
	room.resolved = true
	if total >= TRAP_AVOID:
		_log("A %s! You roll %d (need %d+) and leap clear." % [trap, total, TRAP_AVOID])
	else:
		var dmg: int = Dice.d6() + dungeon.depth - 1
		player.hp = maxi(0, player.hp - dmg)
		_log("[color=#c0392b]A %s! You roll %d (need %d+) and take %d damage.[/color]" % [trap, total, TRAP_AVOID, dmg])
		_flash_hurt()
	busy = false
	_refresh_stats()
	if player.hp <= 0:
		_die("Killed by a %s on dungeon level %d." % [trap, dungeon.depth])


func _give_loot(room) -> void:
	room.resolved = true
	var depth: int = dungeon.depth
	match Dice.d6():
		1, 2:
			var gold: int = (Dice.d6() + Dice.d6()) * depth
			player.gold += gold
			_log("[color=#e0b04f]You find %d gold coins.[/color]" % gold)
		3:
			player.potions += 1
			_log("[color=#e0b04f]You find a healing potion.[/color]")
		4:
			if player.armor < Player.MAX_ARMOR:
				player.armor += 1
				_log("[color=#e0b04f]You find a piece of sturdy armour (armour %d).[/color]" % player.armor)
			else:
				player.gold += 10 * depth
				_log("[color=#e0b04f]You find armour you don't need and pocket %d gold of trimmings.[/color]" % (10 * depth))
		5:
			player.shift = player.max_shift
			var msgs: Array = player.gain_xp(3)
			_log("[color=#4fa3e0]You find a strange blue elixir. Shift restored, and you feel wiser (+3 XP).[/color]")
			for m in msgs:
				_log(m)
		_:
			var options: Array = []
			for w in GameData.WEAPONS:
				if w != player.weapon_name:
					options.append(w)
			pending_weapon = GameData.pick(options)
			mode = "prompt"
			_log("[color=#e0b04f]You find a %s lying among the bones.[/color]" % pending_weapon)
	_refresh_stats()


func _take_weapon(take: bool) -> void:
	if take:
		_log("You take the %s." % pending_weapon)
		player.weapon_name = pending_weapon
	else:
		_log("You leave the %s behind." % pending_weapon)
	pending_weapon = ""
	mode = "explore"
	_show_room()


func _pray() -> void:
	if busy:
		return
	var room = dungeon.rooms[current_room]
	var healed: int = player.heal(Dice.d6() + 2 * dungeon.depth + 2)
	player.shift = player.max_shift
	room.resolved = true
	_log("[color=#4fa3e0]You kneel at the shrine. Warmth floods you: +%d HP and shift restored.[/color]" % healed)
	_show_room()


func _explore_potion() -> void:
	if busy:
		return
	var healed: int = player.drink_potion()
	_log("You drink a potion and recover %d HP." % healed)
	_show_room()


func _descend() -> void:
	if busy:
		return
	_enter_dungeon(dungeon.depth + 1)


func _leave_dungeon() -> void:
	if busy:
		return
	_log("You climb back up into the daylight.")
	_open_town()


func _die(reason: String) -> void:
	mode = "dead"
	busy = false
	combat_layer.visible = false
	over_text.text = (
		"[center]%s\n\n" % reason
		+ "Level %d adventurer    Deepest level %d\n" % [player.level, player.deepest]
		+ "Creatures slain %d    Gold carried %d[/center]" % [player.kills, player.gold]
	)
	over_layer.visible = true


# ---------------------------------------------------------------- combat

func _start_combat(room) -> void:
	mode = "combat"
	combat = Combat.new(player, room.enemy)
	combat_log.clear()
	monster_view.show_monster(room.enemy.look)
	enemy_name.text = room.enemy.name
	for d in player_dice:
		d.value = 0
		d.highlight = Color(0, 0, 0, 0)
	for d in enemy_dice:
		d.value = 0
	combat_layer.visible = true
	_clog("[color=#c0392b]A %s attacks![/color] %s" % [room.enemy.name, room.enemy.desc])
	_refresh_combat()


func _refresh_combat() -> void:
	if combat == null:
		return
	var e: Dictionary = combat.enemy
	combat_title.text = "Round %d" % combat.round_num
	enemy_bar.set_values(e.hp, e.max_hp, "%d / %d" % [e.hp, e.max_hp])
	var status := ""
	if combat.stunned:
		status += "  [Stunned]"
	if combat.bleed > 0:
		status += "  [Bleeding %d]" % combat.bleed
	enemy_stats.text = "Armour %d    Damage %d    Hits on %d+%s\n%s" % [e.armor, e.dmg, e.hit, status, e.desc]

	_clear(moves_box)
	var valid: Array = []
	for m in player.moves():
		var ok: bool = combat.matches(m)
		var text: String = "%s  (%d-%d)  +%d" % [m.name, m.pair[0], m.pair[1], m.bonus]
		if m.effect != "":
			text += "  %s" % m.effect
		if ok:
			text = "> " + text + "  = %d dmg" % combat.damage_for(m)
			valid.append(m.name)
		var b := _btn(text, _on_attack.bind(m))
		b.disabled = not ok or busy
		b.tooltip_text = GameData.EFFECT_TEXT[m.effect]
		if ok:
			b.add_theme_color_override("font_color", C_GOLD)
		moves_box.add_child(b)

	var basic_text := "Basic strike"
	if combat.rolled:
		if combat.is_fumble():
			basic_text = "Fumble! (double ones)"
		elif combat.is_double():
			basic_text = "Critical hit! (doubles)  = %d dmg" % combat.damage_for({})
		else:
			basic_text = "Basic strike (higher die - armour)  = %d dmg" % combat.damage_for({})
	var basic := _btn(basic_text, _on_attack.bind({}))
	basic.disabled = not combat.rolled or busy
	if combat.rolled and combat.is_double() and not combat.is_fumble():
		basic.add_theme_color_override("font_color", C_GOLD)
	elif combat.is_fumble():
		basic.add_theme_color_override("font_color", C_RED)
	moves_box.add_child(basic)

	for i in 2:
		shift_buttons[i * 2].disabled = busy or not combat.can_shift(i, 1)
		shift_buttons[i * 2 + 1].disabled = busy or not combat.can_shift(i, -1)
		var glow := Color(0, 0, 0, 0)
		if combat.rolled and combat.is_double():
			glow = C_RED if combat.is_fumble() else C_GOLD
		elif combat.rolled and not valid.is_empty():
			glow = C_GOLD
		player_dice[i].highlight = glow

	roll_button.disabled = busy or combat.rolled
	potion_button.text = "Drink a potion (%d left, uses your turn)" % player.potions
	potion_button.disabled = busy or combat.rolled or player.potions <= 0
	flee_button.disabled = busy or combat.rolled

	if not combat.rolled:
		dice_hint.text = "Roll your attack dice."
	elif combat.is_fumble():
		dice_hint.text = "Double ones! Shift a die to avoid the fumble, or take the risk."
	elif combat.is_double():
		dice_hint.text = "Doubles! A critical hit that ignores armour."
	elif not valid.is_empty():
		dice_hint.text = "Your dice match: %s" % ", ".join(valid)
	else:
		dice_hint.text = "No manoeuvre matches. Spend shift points to nudge a die, or make a basic strike."
	_refresh_stats()


func _on_roll() -> void:
	if combat == null or busy or combat.rolled:
		return
	busy = true
	combat.roll()
	_refresh_combat()
	for i in 2:
		player_dice[i].roll_to(combat.dice[i], 0.5)
	await _wait(0.55)
	_clog("You roll %d and %d." % [combat.dice[0], combat.dice[1]])
	busy = false
	_refresh_combat()


func _on_shift(i: int, delta: int) -> void:
	if combat == null or busy:
		return
	if combat.shift_die(i, delta):
		player_dice[i].value = combat.dice[i]
		_refresh_combat()


func _on_attack(move: Dictionary) -> void:
	if combat == null or busy or not combat.rolled:
		return
	busy = true
	var res: Dictionary = combat.player_attack(move)
	for line in res.lines:
		_clog(line)
	if res.dmg > 0:
		monster_view.hit()
	_refresh_combat()
	await _wait(0.6)
	if combat.enemy.hp <= 0:
		await _win_combat()
		return
	await _enemy_turn()


func _on_combat_potion() -> void:
	if combat == null or busy or combat.rolled or player.potions <= 0:
		return
	busy = true
	var healed: int = player.drink_potion()
	_clog("You gulp down a potion and recover %d HP." % healed)
	_refresh_combat()
	await _wait(0.4)
	await _enemy_turn()


func _on_flee() -> void:
	if combat == null or busy or combat.rolled:
		return
	busy = true
	_refresh_combat()
	var roll: Array = Dice.roll2()
	for i in 2:
		player_dice[i].roll_to(roll[i], 0.5)
	await _wait(0.55)
	var total: int = roll[0] + roll[1]
	if total >= Combat.FLEE_TARGET:
		_clog("You roll %d and flee back the way you came!" % total)
		await _wait(0.6)
		combat_layer.visible = false
		combat = null
		mode = "explore"
		await _walk([current_room, previous_room])
		current_room = previous_room
		busy = false
		_show_room()
		return
	_clog("You roll %d (need %d+) and fail to get away!" % [total, Combat.FLEE_TARGET])
	await _wait(0.4)
	await _enemy_turn()


func _enemy_turn() -> void:
	var res: Dictionary = combat.enemy_turn()
	if res.dice.size() == 2:
		for i in 2:
			enemy_dice[i].roll_to(res.dice[i], 0.5)
		await _wait(0.55)
	for line in res.lines:
		_clog(line)
	if res.dmg > 0:
		_flash_hurt()
	if res.enemy_dead:
		await _win_combat()
		return
	combat.end_round()
	busy = false
	_refresh_combat()
	if player.hp <= 0:
		_die("Slain by a %s on dungeon level %d." % [combat.enemy.name, dungeon.depth])


func _win_combat() -> void:
	busy = true
	var e: Dictionary = combat.enemy
	var room = dungeon.rooms[current_room]
	monster_view.defeat()
	player.kills += 1
	player.gold += e.gold
	player.shift = mini(player.max_shift, player.shift + 1)
	_clog("[color=#e0b04f]Victory! +%d XP, +%d gold, +1 shift.[/color]" % [e.xp, e.gold])
	var msgs: Array = player.gain_xp(e.xp)
	for m in msgs:
		_clog(m)
	_refresh_stats()
	await _wait(1.4)
	combat_layer.visible = false
	combat = null
	mode = "explore"
	busy = false
	if room.content == "hoard":
		_log("Behind the creature lies its hoard.")
		_give_loot(room)
	room.resolved = true
	_show_room()
