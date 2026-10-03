// Vertical FOV in degrees for first-person viewmodel meshes; 0 keeps the camera's own.
uniform float viewmodel_fov = 0.0;

void apply_viewmodel_fov(inout mat4 proj) {
	if (viewmodel_fov <= 0.0 || proj[2][3] == 0.0) {
		return;  // off, or an orthographic camera
	}
	float f = 1.0 / tan(radians(viewmodel_fov) * 0.5);
	// Keep the projection's signs: a positive [1][1] drew the viewmodel rotated 180 degrees.
	proj[0][0] = f * proj[0][0] / abs(proj[1][1]);  // keeps the camera's aspect
	proj[1][1] = f * sign(proj[1][1]);  // keeps Godot's Y flip (Vulkan hands a negative [1][1])
}
