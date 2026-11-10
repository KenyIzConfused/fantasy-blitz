class_name TileGrid
extends RefCounted

## Shared grid helpers for the hand-built tile maps (maps/TILES/*.tscn).
##
## The levels are built from individual 1x1 tile scenes placed on a 1.0-unit
## grid, and every tile is CENTERED on a half-integer coordinate
## (x = n + 0.5, z = m + 0.5). For example tileGrass118 sits at (0.5, 0, 4.5).
##
## Both the build HUD (UI/Gameplay_UI.gd) and the hover marker
## (maps/camera_3d.gd) use these helpers, so placement and the pointer always
## agree on where a tower can go.

## Distance between adjacent tile centers.
const CELL_SIZE := 1.0

## Name prefix shared by every buildable (grass) tile node and scene.
const GRASS_TILE_PREFIX := "tileGrass"

## Only grass tiles whose name number is at or above this are buildable - e.g.
## 118 means "tileGrass118 and above, up to the highest tileGrass". Set to 0 to
## allow every grass tile. Towers can still reach the path from these tiles
## because their range (5-6 tiles) is larger than the gap to the route.
const MIN_BUILD_TILE_INDEX := 118


## Snap an arbitrary world point onto the center of the tile it is over.
## Keeps the point's Y so the tower sits on the tile surface.
static func snap_to_tile(point: Vector3) -> Vector3:
	var half := CELL_SIZE * 0.5
	return Vector3(
		roundf(point.x - half) + half,
		point.y,
		roundf(point.z - half) + half
	)


## True when the object a ray hit (or one of its ancestors) is a buildable
## grass tile. Path tiles - the spawner, straights, corners and the end tile -
## all fail this test, so towers can never be dropped onto the enemy route.
## Grass tiles numbered below MIN_BUILD_TILE_INDEX are also rejected.
static func is_buildable_tile(collider: Object) -> bool:
	var node := collider as Node
	while node != null:
		if _is_grass_node(node):
			return _tile_index(node.name) >= MIN_BUILD_TILE_INDEX
		node = node.get_parent()
	return false


## True when a node is a grass tile, by its name or its source scene name.
static func _is_grass_node(node: Node) -> bool:
	if node.name.begins_with(GRASS_TILE_PREFIX):
		return true
	return node.scene_file_path.get_file().begins_with(GRASS_TILE_PREFIX)


## Trailing number of a grass node name ("tileGrass118" -> 118). The first,
## unnumbered tile ("tileGrass") counts as 1.
static func _tile_index(node_name: String) -> int:
	if not node_name.begins_with(GRASS_TILE_PREFIX):
		return 0
	var suffix := node_name.substr(GRASS_TILE_PREFIX.length())
	return suffix.to_int() if suffix != "" else 1