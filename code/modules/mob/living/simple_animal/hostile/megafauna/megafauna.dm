/mob/living/simple_animal/hostile/megafauna
	name = "boss of this gym"
	desc = "Attack the weak point for massive damage."
	health = 1000
	maxHealth = 1000
	combat_mode = TRUE
	sentience_type = SENTIENCE_BOSS
	environment_smash = ENVIRONMENT_SMASH_RWALLS
	mob_biotypes = MOB_ORGANIC|MOB_EPIC
	obj_damage = 400
	light_range = 3
	faction = list("mining", "boss")
	weather_immunities = list("lava","ash")
	robust_searching = TRUE
	ranged_ignores_vision = TRUE
	stat_attack = DEAD
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	damage_coeff = list(BRUTE = 1, BURN = 0.5, TOX = 1, CLONE = 1, STAMINA = 0, OXY = 1)
	minbodytemp = 0
	maxbodytemp = INFINITY
	vision_range = 4
	aggro_vision_range = 14
	move_force = MOVE_FORCE_OVERPOWERING
	move_resist = MOVE_FORCE_OVERPOWERING
	pull_force = MOVE_FORCE_OVERPOWERING
	mob_size = MOB_SIZE_HUGE
	layer = LARGE_MOB_LAYER //Looks weird with them slipping under mineral walls and cameras and shit otherwise
	mouse_opacity = MOUSE_OPACITY_OPAQUE // Easier to click on in melee, they're giant targets anyway
	flags_1 = PREVENT_CONTENTS_EXPLOSION_1 | HEAR_1
	/// Crusher loot dropped when the megafauna is killed with a crusher
	var/list/crusher_loot
	/// If the megafauna was actually killed (not just dying, then transforming into another type)
	var/elimination = 0
	/// Modifies attacks when at lower health
	var/anger_modifier = 0
	/// Name for the GPS signal of the megafauna
	var/gps_name = null
	/// Next time the megafauna can use a melee attack
	var/recovery_time = 0
	/// If this is a megafauna that is real (has gps signal)
	var/true_spawn = TRUE
	/// Range the megafauna can move from their nest (if they have one
	var/nest_range = 10
	/// The chosen attack by the megafauna
	var/chosen_attack = 1
	/// Attack actions, sets chosen_attack to the number in the action
	var/list/attack_action_types = list()
	/// If there is a small sprite icon for players controlling the megafauna to use
	var/small_sprite_type

/mob/living/simple_animal/hostile/megafauna/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_flying)
	if(gps_name && true_spawn)
		AddComponent(/datum/component/gps, gps_name)
	ADD_TRAIT(src, TRAIT_NO_TELEPORT, MEGAFAUNA_TRAIT)
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_MARTIAL_ARTS_IMMUNE, MEGAFAUNA_TRAIT)
	for(var/action_type in attack_action_types)
		var/datum/action/innate/megafauna_attack/attack_action = new action_type()
		attack_action.Grant(src)
	if(small_sprite_type)
		var/datum/action/small_sprite/small_action = new small_sprite_type()
		small_action.Grant(src)

/mob/living/simple_animal/hostile/megafauna/Moved()
	//Safety check
	if(!loc)
		return ..()
	if(nest && nest.parent && get_dist(nest.parent, src) > nest_range)
		var/turf/closest = get_turf(nest.parent)
		for(var/i = 1 to nest_range)
			closest = get_step(closest, get_dir(closest, src))
		forceMove(closest) // someone teleported out probably and the megafauna kept chasing them
		LoseTarget()
		return
	return ..()

/mob/living/simple_animal/hostile/megafauna/death(gibbed, list/force_grant)
	if(health > 0)
		return
	var/datum/status_effect/crusher_damage/crusher_dmg = has_status_effect(STATUS_EFFECT_CRUSHERDAMAGETRACKING)
	if(crusher_dmg && crusher_loot && crusher_dmg.total_damage >= maxHealth * 0.6)
		spawn_crusher_loot()
	return ..()

/// Spawns crusher loot instead of normal loot
/mob/living/simple_animal/hostile/megafauna/proc/spawn_crusher_loot()
	loot = crusher_loot

/mob/living/simple_animal/hostile/megafauna/gib()
	if(health > 0)
		return
	else
		..()

/mob/living/simple_animal/hostile/megafauna/dust(just_ash, drop_items, force)
	if(!force && health > 0)
		return
	else
		..()

/mob/living/simple_animal/hostile/megafauna/AttackingTarget()
	if(recovery_time >= world.time)
		return
	. = ..()
	if(. && isliving(target))
		var/mob/living/L = target
		if(L.stat != DEAD)
			if(!client && ranged && ranged_cooldown <= world.time)
				OpenFire()

			if(L.health <= HEALTH_THRESHOLD_DEAD && HAS_TRAIT(L, TRAIT_NODEATH)) //Nope, it still gibs yall
				devour(L)
		else
			devour(L)

/// Devours a target and restores health to the megafauna
/mob/living/simple_animal/hostile/megafauna/proc/devour(mob/living/L)
	if(!L)
		return FALSE
	visible_message(
		SPAN_DANGER("[src] devours [L]!"),
		SPAN_USERDANGER("You feast on [L], restoring your health!"))
	if(!is_station_level(src) || client) //NPC monsters won't heal while on station
		adjustBruteLoss(-L.maxHealth/2)
	L.gib()
	return TRUE

/mob/living/simple_animal/hostile/megafauna/ex_act(severity, target)
	switch (severity)
		if (EXPLODE_DEVASTATE)
			adjustBruteLoss(250)

		if (EXPLODE_HEAVY)
			adjustBruteLoss(100)

		if (EXPLODE_LIGHT)
			adjustBruteLoss(50)

/// Sets the next time the megafauna can use a melee or ranged attack, in deciseconds
/mob/living/simple_animal/hostile/megafauna/proc/SetRecoveryTime(buffer_time, ranged_buffer_time)
	recovery_time = world.time + buffer_time
	ranged_cooldown = world.time + buffer_time
	if(isnum(ranged_buffer_time))
		ranged_cooldown = world.time + ranged_buffer_time

/datum/action/innate/megafauna_attack
	name = "Megafauna Attack"
	icon_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = ""
	var/chosen_message
	var/chosen_attack_num = 0

/datum/action/innate/megafauna_attack/Grant(mob/living/L)
	if(!ismegafauna(L))
		return FALSE
	return ..()

/datum/action/innate/megafauna_attack/Activate()
	var/mob/living/simple_animal/hostile/megafauna/fauna = owner
	fauna.chosen_attack = chosen_attack_num
	to_chat(fauna, chosen_message)
