shader_type spatial;

// Parameters to be passed in GDscript:
uniform sampler2D heightmap;
uniform sampler2D tex : hint_albedo;
uniform sampler2D splat;

uniform sampler2D vegetation_tex1 : hint_albedo;
uniform sampler2D vegetation_normal1 : hint_normal;
uniform int vegetation_id1;
uniform sampler2D vegetation_tex2 : hint_albedo;
uniform sampler2D vegetation_normal2 : hint_normal;
uniform int vegetation_id2;
uniform sampler2D vegetation_tex3 : hint_albedo;
uniform sampler2D vegetation_normal3 : hint_normal;
uniform int vegetation_id3;
uniform sampler2D vegetation_tex4 : hint_albedo;
uniform sampler2D vegetation_normal4 : hint_normal;
uniform int vegetation_id4;

uniform vec3 curv_middle = vec3(0.0, 0.0, 0.0);

// Global parameters - will need to be the same in all shaders:
uniform float height_range = 1500;

uniform float subdiv;
uniform float size;
uniform float size_without_skirt;
uniform float tex_factor = 0.25; // 0.5 means one Godot meter will have half the texture

uniform float RADIUS = 6371000; // average earth radius in meters

varying vec3 normal;

// Get the value by which vertex at given point must be lowered to simulate the earth's curvature 
float get_curve_offset(float distance_squared) {
	return sqrt(RADIUS * RADIUS + distance_squared) - RADIUS;
}

// Shrinks and centers UV coordinates to compensate for the skirt around the edges
vec2 get_relative_pos(vec2 raw_pos) {
	float offset_for_subdiv = ((size_without_skirt/(subdiv+1.0))/size_without_skirt);
	float factor = (size / size_without_skirt);
	
	vec2 pos = raw_pos * factor;

	pos.x -= offset_for_subdiv;
	pos.y -= offset_for_subdiv;
	
	pos.x = clamp(pos.x, 0.005, 0.995);
	pos.y = clamp(pos.y, 0.005, 0.995);
	
	return pos;
}

// Gets the absolute height at a given pos without taking the skirt into account
float get_height_no_falloff(vec2 pos) {
	return texture(heightmap, get_relative_pos(pos)).g * height_range;
}

// Gets the required height of the vertex, including the skirt around the edges (the outermost vertices are set to y=0 to allow seamless transitions between tiles)
float get_height(vec2 pos) {
	float falloff = 1.0/(10000.0);
	
	if (pos.x > 1.0 - falloff || pos.y > 1.0 - falloff || pos.x < falloff || pos.y < falloff) {
		return 0.0;
	}
	
	return get_height_no_falloff(pos);
}

void vertex() {
	// Apply the height of the heightmap at this pixel
	VERTEX.y = get_height(UV);
	
	// Apply the curvature based on the position of the current camera
	vec3 world_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	float dist_to_middle = pow(world_pos.x, 2.0) + pow(world_pos.y, 2.0) + pow(world_pos.z, 2.0);
	
	VERTEX.y -= get_curve_offset(dist_to_middle);
	
	// To calculate the normal vector, height values on the left/right/top/bottom of the current pixel are compared.
	// e is the offset factor. Note: This might be dependent on the picture resolution! The current value works for my test images.
	float e = 1.0/20.0;

	normal = normalize(vec3(-get_height_no_falloff(UV + vec2(e, 0.0)) + get_height_no_falloff(UV - vec2(e, 0.0)), 10.0 , -get_height_no_falloff(UV + vec2(0.0, e)) + get_height_no_falloff(UV - vec2(0.0, e))));
}

void fragment(){
	vec3 color;
	vec3 current_normal = normal;
	
	if (int(texture(splat, get_relative_pos(UV)).r * 255.0) == vegetation_id1) {
		color = texture(vegetation_tex1, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
		current_normal = texture(vegetation_normal1, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
	} else if (int(texture(splat, get_relative_pos(UV)).r * 255.0) == vegetation_id2) {
		color = texture(vegetation_tex2, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
		current_normal = texture(vegetation_normal2, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
	} else if (int(texture(splat, get_relative_pos(UV)).r * 255.0) == vegetation_id3) {
		color = texture(vegetation_tex3, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
		current_normal = texture(vegetation_normal3, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
	} else if (int(texture(splat, get_relative_pos(UV)).r * 255.0) == vegetation_id4) {
		color = texture(vegetation_tex4, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
		current_normal = texture(vegetation_normal4, UV * size * tex_factor - vec2(floor(UV.x * size * tex_factor), floor(UV.y * size * tex_factor))).rgb;
	} else {
		color = texture(tex, get_relative_pos(UV)).rgb;
	}
	
	// TODO: Still also use the terrain normal, not only the texture, here!
	NORMALMAP = current_normal * vec3(2.0, 2.0, 1.0) - vec3(1.0, 1.0, 0.0);
	ALBEDO = color;
}