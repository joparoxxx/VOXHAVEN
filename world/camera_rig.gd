extends RefCounted
## Stateless orbital camera math used by the Android and desktop camera inputs.
const MIN_PITCH := 0.24
const MAX_PITCH := 1.48
const ORBIT_SENSITIVITY := 0.007

static func orbit_angles(yaw: float,pitch: float,drag: Vector2) -> Vector2:
	return Vector2(wrapf(yaw-drag.x*ORBIT_SENSITIVITY,-PI,PI),clampf(pitch+drag.y*ORBIT_SENSITIVITY,MIN_PITCH,MAX_PITCH))

static func position_for(target: Vector3,yaw: float,pitch: float,radius: float) -> Vector3:
	var horizontal := cos(pitch)*radius
	return target+Vector3(sin(yaw)*horizontal,sin(pitch)*radius,cos(yaw)*horizontal)

static func pan_delta(drag: Vector2,yaw: float,zoom: float,height: float) -> Vector3:
	return Vector3(-drag.x,0.0,-drag.y).rotated(Vector3.UP,yaw)*zoom/maxf(height,1.0)

## Absolute gesture reference prevents zoom drift from two-finger translation.
static func pinch_zoom(reference_zoom: float, reference_distance: float, current_distance: float, minimum: float, maximum: float) -> float:
	if reference_distance <= 12.0 or current_distance <= 12.0:
		return clampf(reference_zoom,minimum,maximum)
	return clampf(reference_zoom*reference_distance/current_distance,minimum,maximum)
