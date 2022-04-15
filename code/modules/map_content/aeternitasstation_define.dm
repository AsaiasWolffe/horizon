/datum/map_config/aeternitasstation
	map_name = "Aeternitas Station"
	map_path = "map_files/AeternitasStation"
	map_file = "AeternitasStation.dmm"

	traits = null
	space_ruin_levels = 3

	minetype = "lavaland"

	allow_custom_shuttles = TRUE
	shuttles = list(
		"cargo" = "cargo_box",
		"ferry" = "ferry_fancy",
		"whiteship" = "whiteship_box",
		"emergency" = "emergency_box")

	job_changes = list()

	overmap_object_type = /datum/overmap_object/shuttle/station
