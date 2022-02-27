extends Node


var goals = ["FindPlayer", "FindWeapon", "FindAmmo", "Attack", "Wander", "Flee"]
var enemy : CharacterBody3D


func new_behavior(new_enemy : CharacterBody3D) -> Array:
	enemy = new_enemy
	match enemy.behavior:
		"Normal":
			return _normal_behavior()
		"Aggresssive":
			pass
		"Slapper":
			pass
		"Scared":
			pass
			
	return ["Wander", _get_nav_point()]


func _normal_behavior() -> Array:
	var player_seen = enemy.player_seen
	var player_dist : float
	if enemy.player != null:
		player_dist = _player_distance()
	var nearest_weapon = _nearest_weapon()
	var nearest_pistol_ammo = _nearest_ammo(0)
	var nearest_rifle_ammo = _nearest_ammo(1)
	
	# If the enemy has Slapper equipped and is not too close to player, prioritize 
	# finding the closest ammo for whatever weapons that are owned, otherwise
	# find the closest weapon. If there are no weapons available, wander. If the
	# player is too close, attempt to attack
	if enemy.equipped == enemy.slapper:
		if enemy.player == null or player_dist > enemy.slapper_preferred_dist[1]:
			var has_pistol = enemy.pistol != null
			var has_rifle = enemy.rifle != null
			if has_pistol or has_rifle:
				if nearest_pistol_ammo[0] < nearest_rifle_ammo[0]:
					if has_pistol:
						return ["FindAmmo", nearest_pistol_ammo]
				else:
					if has_rifle:
						return ["FindAmmo", nearest_rifle_ammo]
					else:
						return ["FindAmmo", nearest_pistol_ammo]
						
			elif nearest_weapon[0] != null:
				return ["FindWeapon", nearest_weapon]
			else:
				return ["Wander", _get_nav_point()]
		elif player_dist > enemy.slapper_preferred_dist[0]:
			return ["FindPlayer", [player_dist, enemy.player]]
		else:
			return ["Attack", [player_dist, enemy.player]]
			
	# If the enemy has a Pistol equipped wander until the player is seen. If the
	# player is beyond the preferred shooting distance attempt to follow until in
	# range then attack. If the enemy is on it's last mag it attempts to pickup ammo.
	elif enemy.equipped == enemy.pistol:
		if player_seen:
			enemy.find_timer.stop()
			if player_dist < enemy.pistol_preferred_dist[1]:
				return ["Attack", [player_dist, enemy.player]]
			else:
				enemy.find_timer.start(enemy.find_time)
				return ["FindPlayer", [player_dist, enemy.player]]
		elif enemy.equipped.total_ammo < enemy.equipped.mag_size:
			return ["FindAmmo", nearest_pistol_ammo]
		elif enemy.player != null:
			if enemy.goal[0] == "Attack":
				enemy.find_timer.start(enemy.find_time)
				return ["FindPlayer", [player_dist, enemy.player]]
			elif enemy.goal[0] == "FindPlayer":
				return ["Wander", _get_nav_point()]
				
	elif enemy.equipped == enemy.rifle:
		if player_seen:
			enemy.find_timer.stop()
			if player_dist < enemy.rifle_preferred_dist[1]:
				return ["Attack", [player_dist, enemy.player]]
			else:
				enemy.find_timer.start(enemy.find_time)
				return ["FindPlayer", [player_dist, enemy.player]]
		elif enemy.equipped.total_ammo < enemy.equipped.mag_size:
			return ["FindAmmo", nearest_rifle_ammo]
		elif enemy.player != null:
			if enemy.goal[0] == "Attack":
				enemy.find_timer.start(enemy.find_time)
				return ["FindPlayer", [player_dist, enemy.player]]
			elif enemy.goal[0] == "FindPlayer":
				return ["Wander", _get_nav_point()]
		
	return ["Wander", _get_nav_point()]


func _player_distance() -> float:
	enemy.nav_agent.set_target_location(enemy.player.global_transform.origin)
	return enemy.nav_agent.distance_to_target()
	


func _get_nav_point() -> Array:
	var nav_point = enemy.nav_points.get_child(randi() % enemy.nav_points.get_child_count())
	enemy.nav_agent.set_target_location(nav_point.global_transform.origin)
	var nav_dist = enemy.nav_agent.distance_to_target()
	return [nav_dist, nav_point]


func _nearest_ammo(ammo_type : int) -> Array:
	var ammos : Array = _get_ammo_list(ammo_type)
	var closest = ammos.pop_front()
	if ammos.size() == 0:
		return [null, null]
	enemy.nav_agent.set_target_location(closest.global_transform.origin)
	var closest_dist : float = enemy.nav_agent.distance_to_target()
	for ammo in ammos:
		enemy.nav_agent.set_target_location(ammo.global_transform.origin)
		var dist : float = enemy.nav_agent.distance_to_target()
		if dist < closest_dist:
			closest = ammo
			closest_dist = dist
	return [closest_dist, closest]


func _get_ammo_list(ammo_type : int = -1) -> Array:
	var ammos := []
	for pickup in enemy.pickups.get_children():
		if pickup.weapon == ammo_type:
			ammos.append(pickup)
	return ammos


func _nearest_weapon(weapon_type : int = -1) -> Array:
	var weapons : Array = _get_weapon_list(weapon_type)
	if weapons.size() == 0:
		return [null, null]
	var closest = weapons.pop_front()
	enemy.nav_agent.set_target_location(closest.global_transform.origin)
	var closest_dist : float = enemy.nav_agent.distance_to_target()
	for weapon in weapons:
		enemy.nav_agent.set_target_location(weapon.global_transform.origin)
		var dist : float = enemy.nav_agent.distance_to_target()
		if dist < closest_dist and weapon.available:
			closest = weapon
			closest_dist = dist
	return [closest_dist, closest]


func _get_weapon_list(weapon_type : int = -1) -> Array:
	var weapons := []
	for weapon in enemy.pickups.get_children():
		if weapon is WeaponPickup and weapon.available:
			if weapon_type >= 0:
				if weapon.weapon == weapon_type:
					weapons.append(weapon)
			else:
				weapons.append(weapon)
	return weapons
