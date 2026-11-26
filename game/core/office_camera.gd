extends RefCounted
## Orthographic orbit math. All angles are radians.
const MIN_PITCH := 0.35
const MAX_PITCH := 1.22
const DRAG_SENSITIVITY := 0.006
const MIN_ZOOM := 6.0
const MAX_ZOOM := 40.0

static func angles(offset: Vector3) -> Vector2:
	return Vector2(atan2(offset.x, offset.z), clampf(atan2(offset.y, Vector2(offset.x, offset.z).length()), MIN_PITCH, MAX_PITCH))

static func orbit_angles(current: Vector2, relative: Vector2) -> Vector2:
	return Vector2(wrapf(current.x - relative.x * DRAG_SENSITIVITY, -PI, PI), clampf(current.y + relative.y * DRAG_SENSITIVITY, MIN_PITCH, MAX_PITCH))

static func offset(azimuth: float, elevation: float, distance: float) -> Vector3:
	var horizontal := cos(elevation) * distance
	return Vector3(sin(azimuth) * horizontal, sin(elevation) * distance, cos(azimuth) * horizontal)

static func pinch_size(size_: float, before: float, after: float) -> float:
	if before <= 5.0 or after <= 5.0:
		return size_
	return clampf(size_ * before / after, MIN_ZOOM, MAX_ZOOM)
