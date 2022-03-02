extends Decal

func project_to(surf_norm : Vector3):
	var tangent : Vector3
	if surf_norm.abs().is_equal_approx(Vector3.UP):
		tangent = Vector3.FORWARD
	else:
		tangent = Vector3.UP
	
	var bitangent : Vector3 = surf_norm.cross(tangent)
	tangent = surf_norm.cross(bitangent)
	global_transform.basis.y = surf_norm
	global_transform.basis.z = bitangent
	global_transform.basis.x = tangent
