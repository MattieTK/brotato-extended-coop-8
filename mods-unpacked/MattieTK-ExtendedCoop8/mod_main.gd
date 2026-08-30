extends Node

# ExtendedCoop8 — extends Brotato local coop from 4 to 8 players.
# Works over Steam Remote Play Together (remote controllers appear as local ones).

const MOD_DIR := "MattieTK-ExtendedCoop8"
const LOG_NAME := "MattieTK-ExtendedCoop8:Main"

const EXTENSIONS := [
	"singletons/coop_service.gd",
	"singletons/input_service.gd",
	"singletons/utils.gd",
	"singletons/run_data.gd",
	"singletons/temp_stats.gd",
	"singletons/linked_stats.gd",
	"singletons/debug_service.gd",
	"singletons/zone_service.gd",
	"singletons/progress_data.gd",
	"global/entity_spawner.gd",
	"global/stats_manager.gd",
	"main.gd",
	"ui/menus/global/popup_manager.gd",
	"ui/menus/run/base_selection.gd",
	"ui/menus/run/character_selection.gd",
	"ui/menus/run/weapon_selection.gd",
	"ui/menus/run/coop_end_run.gd",
	"ui/menus/shop/base_shop.gd",
	"ui/menus/shop/coop_shop.gd",
	"ui/menus/shop/player_gear_container.gd",
	"ui/menus/ingame/upgrades_ui.gd",
	"ui/menus/ingame/coop_player_selector.gd",
]

var mod_dir_path := ""


func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	var extensions_dir_path = mod_dir_path.plus_file("extensions")
	for ext in EXTENSIONS:
		ModLoaderMod.install_script_extension(extensions_dir_path.plus_file(ext))


func _ready() -> void:
	ModLoaderLog.info("Ready — up to 8 players enabled", LOG_NAME)
	# Test harness activation: CLI arg, or a flag file (survives Steam's DRM
	# relaunch, which drops custom command-line arguments).
	var args = OS.get_cmdline_args()
	var flag_file: = File.new()
	if "--c8-autotest" in args or "--c8-resume-test" in args or flag_file.file_exists("user://c8_autotest.flag"):
		var tester = load(mod_dir_path.plus_file("c8_autotest.gd")).new()
		tester.name = "C8AutoTest"
		add_child(tester)
	if "--c8-dev" in args or flag_file.file_exists("user://c8_dev.flag"):
		var devtools = load(mod_dir_path.plus_file("c8_devtools.gd")).new()
		devtools.name = "C8DevTools"
		add_child(devtools)
