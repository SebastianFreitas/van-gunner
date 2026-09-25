shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Building skin: seven wall styles, a procedural window grid with lit/dark/boarded/
// broken panes, ground-floor storefronts, and grime/soot/overgrowth/damage overlays.
// UV is facade space in METRES (UV.x along the wall from its left end, UV.y above the
// building base) — never scale it by a tile count.

uniform int style = 0;                 // 0 brick, 1 concrete panel, 2 plaster, 3 glass curtain, 4 corrugated, 5 stone, 6 bare frame
uniform vec3 base_color : source_color = vec3(0.30, 0.16, 0.12);
uniform vec3 accent_color : source_color = vec3(0.22, 0.20, 0.18);   // frames, sills, piers, string courses, spandrels
uniform vec3 mortar_color : source_color = vec3(0.16, 0.15, 0.13);
uniform vec3 glass_color : source_color = vec3(0.03, 0.045, 0.05);
uniform vec3 lit_color : source_color = vec3(1.0, 0.72, 0.42);
uniform float seed = 0.0;
uniform float facade_width = 20.0;     // metres
uniform float facade_height = 24.0;    // metres above base
uniform float floor_height = 3.2;
uniform float ground_height = 4.6;     // ground-floor zone top
uniform float window_pitch = 2.6;      // horizontal spacing of window cells
uniform float window_w = 1.3;
uniform float window_h = 1.7;
uniform float window_sill = 0.9;       // window bottom above its floor line
uniform float windows_on = 1.0;
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.3;
uniform float boarded_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float broken_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float band_every = 0.0;        // string course every N floors, 0 = none
uniform float grime : hint_range(0.0, 1.0) = 0.5;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float soot : hint_range(0.0, 1.0) = 0.0;
uniform float overgrowth : hint_range(0.0, 1.0) = 0.0;
uniform float collapse_y = 0.0;        // 0 = intact; else discard above a noisy edge at this height
uniform float flicker = 0.0;           // 1 = lit windows flicker with TIME (fire)
uniform int ground_kind = 0;           // 0 blank, 1 storefront, 2 boarded, 3 roll-up, 4 loading dock, 5 arcade
uniform float ground_units = 2.0;      // storefront / door bays across the facade
uniform float emission_energy = 2.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return fract(sin(vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	)) * 43758.5453);
}

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise21(p);
		p = p * 2.07 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

float crack_field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float min_d = 1.0;
	float second = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(cell + g);
			vec2 r = g + o - f;
			float d = length(r);
			if (d < min_d) {
				second = min_d;
				min_d = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - min_d;
}

// True on the 0.25 m band at the bottom of every band_every-th floor.
bool string_course(vec2 p) {
	if (band_every <= 0.0 || p.y < ground_height) {
		return false;
	}
	float wy = p.y - ground_height;
	float row = floor(wy / floor_height);
	float fy = wy - row * floor_height;
	return fy < 0.25 && mod(row, band_every) < 0.5;
}

// Regular window_pitch grid position, shared by window_cell and the sill/soot overlays.
void window_grid(vec2 p, out float row, out float fy, out float col, out float fx, out bool valid) {
	float wy = p.y - ground_height;
	row = floor(wy / floor_height);
	fy = wy - row * floor_height;
	col = floor(p.x / window_pitch);
	fx = p.x - col * window_pitch;
	valid = col * window_pitch + window_pitch <= facade_width - 0.3
		&& ground_height + (row + 1.0) * floor_height <= facade_height - 0.6;
}

// Brick coursing: 0.065 m courses, 0.22 m bricks, odd courses offset 0.11 m.
void brick_grid(vec2 p, out vec2 id, out float bx, out float by) {
	float row = floor(p.y / 0.065);
	float offset = mod(row, 2.0) < 1.0 ? 0.0 : 0.11;
	bx = mod(p.x + offset, 0.22);
	by = mod(p.y, 0.065);
	id = vec2(floor((p.x + offset) / 0.22), row);
}

// Stone coursing: 1.0 x 0.5 m blocks, odd rows offset 0.5 m.
void stone_grid(vec2 p, out vec2 id, out float bx, out float by) {
	float row = floor(p.y / 0.5);
	float offset = mod(row, 2.0) < 1.0 ? 0.0 : 0.5;
	bx = mod(p.x + offset, 1.0);
	by = mod(p.y, 0.5);
	id = vec2(floor((p.x + offset) / 1.0), row);
}

// Window grid shared by relief and shade. Style 3 (glass curtain) ignores the pitch
// and uses a fixed 1.5 m x floor_height mullion grid with a spandrel at each floor base.
void window_cell(vec2 p, out vec2 id, out vec2 local, out float pane, out float frame) {
	id = vec2(-1.0);
	local = vec2(0.0);
	pane = 0.0;
	frame = 0.0;
	if (windows_on < 0.5 || style == 6 || p.y < ground_height) {
		return;
	}
	if (style == 3) {
		float wy = p.y - ground_height;
		float row = floor(wy / floor_height);
		float fy = wy - row * floor_height;
		float col = floor(p.x / 1.5);
		float fx = p.x - col * 1.5;
		id = vec2(col, row);
		float mull = 0.06;
		bool mullion = fx < mull || fx > 1.5 - mull || fy > floor_height - mull;
		if (fy < 0.9 || mullion) {
			frame = 1.0;
			return;
		}
		pane = 1.0;
		local = vec2((fx - mull) / (1.5 - 2.0 * mull), (fy - 0.9) / (floor_height - 0.9 - mull));
		return;
	}
	float row;
	float fy;
	float col;
	float fx;
	bool valid;
	window_grid(p, row, fy, col, fx, valid);
	if (!valid) {
		return;
	}
	id = vec2(col, row);
	float pane_x0 = (window_pitch - window_w) * 0.5;
	float pane_x1 = (window_pitch + window_w) * 0.5;
	float pad = 0.08;
	bool in_pane = fx >= pane_x0 && fx <= pane_x1 && fy >= window_sill && fy <= window_sill + window_h;
	bool in_frame = fx >= pane_x0 - pad && fx <= pane_x1 + pad
		&& fy >= window_sill - pad && fy <= window_sill + window_h + pad;
	if (in_pane) {
		pane = 1.0;
		local = vec2((fx - pane_x0) / window_w, (fy - window_sill) / window_h);
	} else if (in_frame) {
		frame = 1.0;
	}
}

// Shared boarded-plank look: 0.2 m stripes with wood grain and darker gaps.
vec3 plank_color(vec2 p) {
	vec3 wood = accent_color * vec3(1.35, 1.1, 0.8) * (0.85 + 0.3 * noise21(p * 18.0));
	wood *= 0.8 + 0.4 * hash21(vec2(floor(p.y / 0.2), floor(p.x / 2.4)));
	if (fract(p.y / 0.2) < 0.1) {
		wood *= 0.45;
	}
	return wood;
}

// Height in metres, grid math only — cheap enough to tap three times for the normal.
float facade_relief(vec2 p) {
	float h = 0.0;
	vec2 w_id;
	vec2 w_local;
	float w_pane;
	float w_frame;
	window_cell(p, w_id, w_local, w_pane, w_frame);
	if (w_pane > 0.5) {
		h -= 0.15;
	} else if (w_frame > 0.5) {
		h += 0.03;
	} else if (style == 0) {
		vec2 id;
		float bx;
		float by;
		brick_grid(p, id, bx, by);
		h += (bx < 0.012 || by < 0.012) ? -0.01 : 0.01;
	} else if (style == 1) {
		vec2 pm = mod(p, vec2(2.4, 1.2));
		if (pm.x < 0.02 || pm.y < 0.02) {
			h -= 0.02;
		}
	} else if (style == 4) {
		h += 0.02 * sin(p.x / 0.1 * TAU);
	} else if (style == 5) {
		vec2 id;
		float bx;
		float by;
		stone_grid(p, id, bx, by);
		float d = min(min(bx, 1.0 - bx), min(by, 0.5 - by));
		h -= 0.03 * (1.0 - smoothstep(0.0, 0.04, d));
	}
	if (string_course(p)) {
		h += 0.06;
	}
	if (p.y < ground_height) {
		float unit_w = facade_width / ground_units;
		float ux = p.x - floor(p.x / unit_w) * unit_w;
		if (ground_kind == 1 && (ux < 0.5 || ux > unit_w - 0.5)) {
			h += 0.05;
		} else if (ground_kind == 3 && ux >= 0.5 && ux <= unit_w - 0.5 && p.y <= 3.8) {
			h += 0.02 * sin(p.y / 0.15 * TAU);
		} else if (ground_kind == 5) {
			if (ux < 0.6 || ux > unit_w - 0.6) {
				h += 0.08;
			} else {
				float rx = (ux - unit_w * 0.5) / (unit_w * 0.5 - 0.6);
				float ry = (p.y - 3.4) / 1.2;
				if (length(vec2(rx, ry)) < 1.0 || p.y < 3.4) {
					h -= 0.10;
				}
			}
		}
	}
	return h;
}

// Wall texture by style, used both above the ground zone and as a fallback inside it.
void shade_skin(vec2 p, float sk, out vec3 albedo, out vec3 emission, out float rough, out float metal) {
	albedo = base_color;
	emission = vec3(0.0);
	rough = roughness_value;
	metal = 0.0;
	if (style == 0) {
		vec2 brick_id;
		float bx;
		float by;
		brick_grid(p, brick_id, bx, by);
		if (bx < 0.012 || by < 0.012) {
			albedo = mortar_color;
		} else {
			vec3 brick = base_color * (0.85 + 0.3 * hash21(brick_id));
			float variant = hash21(brick_id + 5.0);
			brick *= variant < 0.08 ? 0.65 : (variant > 0.94 ? 1.25 : 1.0);
			albedo = brick;
		}
	} else if (style == 1) {
		vec2 pm = mod(p, vec2(2.4, 1.2));
		albedo = base_color * mix(1.0, 0.75, smoothstep(0.5, 0.8, fbm(p * 0.9 + seed)));
		if (pm.x < 0.02 || pm.y < 0.02) {
			albedo = mortar_color;
		} else if (length(mod(p, 0.6) - 0.3) < 0.02 && hash21(floor(p / 0.6)) < 0.4) {
			albedo = mortar_color * 0.5;
		}
	} else if (style == 2) {
		albedo = mix(base_color, base_color * 0.8, smoothstep(0.45, 0.7, sk));
		float crack_cover = smoothstep(0.52, 0.62, fbm(p * 0.22 + seed + 31.0));
		float crack_line = 1.0 - smoothstep(0.008, 0.02, crack_field(p * 0.5 + seed));
		albedo = mix(albedo, mortar_color, crack_line * crack_cover);
		if (fbm(p * 1.3 + seed + 5.0) > 0.66) {
			albedo = base_color * 0.55;
		}
	} else if (style == 4) {
		albedo = base_color * (0.85 + 0.15 * sin(p.x / 0.1 * TAU));
		if (mod(p.y, 1.0) < 0.015) {
			albedo = mortar_color;
		}
		float rust = 0.6 * smoothstep(0.6, 0.95, fbm(vec2(p.x * 3.0, p.y * 0.4) + seed));
		albedo = mix(albedo, vec3(0.30, 0.11, 0.05), rust);
	} else if (style == 5) {
		vec2 block_id;
		float bx;
		float by;
		stone_grid(p, block_id, bx, by);
		albedo = (bx < 0.02 || by < 0.02) ? mortar_color : base_color * (0.9 + 0.2 * hash21(block_id));
	} else if (style == 6) {
		bool is_col = mod(p.x, 4.0) < 0.5;
		bool is_slab = mod(p.y - ground_height, floor_height) < 0.35;
		albedo = (is_col || is_slab) ? base_color : vec3(0.01);
	}
}

// Per-window pane state: lit, boarded, broken or dark, from a hash on the window id.
void shade_window(vec2 p, vec2 id, vec2 local, out vec3 albedo, out vec3 emission, out float rough, out float metal) {
	float h = hash21(id + vec2(seed, seed * 0.37));
	emission = vec3(0.0);
	if (h < lit_ratio) {
		float curtain = 1.0 - 0.5 * smoothstep(0.55, 1.0, local.y);
		vec3 tint = hash11(h * 233.0) < 0.3 ? mix(lit_color, vec3(0.85, 0.9, 1.0), 0.6) : lit_color;
		float flick = flicker > 0.5
			? clamp(0.55 + 0.45 * sin(TIME * 23.0 + h * 40.0) * sin(TIME * 7.0 + h * 13.0), 0.2, 1.0)
			: 1.0;
		albedo = glass_color;
		emission = tint * emission_energy * (0.55 + 0.45 * hash11(h * 91.0)) * curtain * flick;
		if (style == 3) {
			emission *= 0.7;
		}
		rough = 0.25;
		metal = 0.1;
	} else if (h < lit_ratio + boarded_ratio) {
		albedo = plank_color(p);
		rough = 0.95;
		metal = 0.0;
	} else if (h < lit_ratio + boarded_ratio + broken_ratio) {
		float shard = 1.0 - smoothstep(0.0, 0.05, crack_field(local * 3.0 + h));
		albedo = glass_color * 0.3 + vec3(0.25 * shard);
		rough = 0.4;
		metal = 0.0;
	} else {
		float diag = fract(local.x * 0.7 + local.y * 0.4 + h);
		albedo = glass_color + vec3(0.03 * smoothstep(0.4, 0.6, diag));
		rough = 0.2;
		metal = 0.15;
	}
}

// Ground-floor zone by ground_kind; unit_w/u/ux split the facade into door/shop bays.
void shade_ground(vec2 p, float sk, out vec3 albedo, out vec3 emission, out float rough, out float metal) {
	float unit_w = facade_width / ground_units;
	float u = floor(p.x / unit_w);
	float ux = p.x - u * unit_w;
	shade_skin(p, sk, albedo, emission, rough, metal);
	if (ground_kind == 0) {
		if (p.y < 0.4) {
			albedo = accent_color * 0.8;
		}
	} else if (ground_kind == 1) {
		if (ux < 0.5 || ux > unit_w - 0.5) {
			albedo = accent_color;
		} else if (p.y < 0.5) {
			albedo = accent_color * 0.6;
		} else if (p.y < 3.4) {
			albedo = glass_color;
			if (hash21(vec2(u, seed)) < 0.6) {
				emission = lit_color * emission_energy * 0.5 * (1.0 - 0.6 * smoothstep(1.2, 3.4, p.y));
				if (fract(p.y * 1.6) < 0.12) {
					emission += vec3(0.3);
				}
				rough = 0.25;
				metal = 0.1;
			} else {
				rough = 0.2;
				metal = 0.15;
			}
		} else if (p.y < 4.2) {
			albedo = accent_color;
		} else {
			albedo = glass_color;
			rough = 0.2;
			metal = 0.15;
		}
	} else if (ground_kind == 2) {
		if (p.y < 0.5) {
			albedo = accent_color * 0.6;
		} else if (hash21(vec2(floor(p.y / 0.2), u)) < 0.12) {
			albedo = vec3(0.01);
		} else {
			albedo = plank_color(p);
		}
		rough = 0.95;
	} else if (ground_kind == 3 && p.y < 3.8 && ux >= 0.5 && ux <= unit_w - 0.5) {
		if (ux < 0.8 || ux > unit_w - 0.8 || p.y < 0.3 || p.y > 3.5) {
			albedo = mortar_color;
		} else {
			vec3 col = accent_color * (0.9 + 0.1 * sin(p.y / 0.15 * TAU));
			float rust = 0.6 * smoothstep(0.6, 0.95, fbm(vec2(p.x * 3.0, p.y * 0.4) + seed));
			albedo = mix(col, vec3(0.30, 0.11, 0.05), rust);
		}
	} else if (ground_kind == 4) {
		if (p.y < 1.2) {
			albedo = mortar_color * 0.8;
			vec2 bumper = vec2(mod(p.x, 2.0) - 1.0, p.y - 0.6);
			if (abs(bumper.x) < 0.15 && abs(bumper.y) < 0.15) {
				albedo = vec3(0.01);
			}
		} else if (p.y < 4.0 && ux >= 0.75 && ux <= unit_w - 0.75) {
			albedo = vec3(0.012, 0.014, 0.014);
			if (p.y > 3.9 && hash21(vec2(u, seed + 3.0)) < 0.5) {
				emission = lit_color * 0.8 * emission_energy;
			}
		}
	} else if (ground_kind == 5) {
		if (ux < 0.6 || ux > unit_w - 0.6) {
			albedo = accent_color;
		} else {
			float rx = (ux - unit_w * 0.5) / (unit_w * 0.5 - 0.6);
			float ry = (p.y - 3.4) / 1.2;
			if (length(vec2(rx, ry)) < 1.0 || p.y < 3.4) {
				albedo = base_color * 0.6;
			}
		}
	}
}

// Grime, soot, overgrowth and damage overlays; never applied to a lit/dark window pane.
void apply_overlays(vec2 p, inout vec3 albedo, inout vec3 emission, inout float rough, inout float metal) {
	if (string_course(p)) {
		albedo = accent_color;
	}
	float base_grime = grime * 0.6 * (0.5 * smoothstep(3.0, 0.0, p.y) + 0.5 * fbm(p * 0.35 + seed + 11.0));
	albedo *= clamp(1.0 - base_grime, 0.0, 1.0);
	if (windows_on > 0.5 && style != 6 && p.y >= ground_height) {
		float row;
		float fy;
		float col;
		float fx;
		bool valid;
		window_grid(p, row, fy, col, fx, valid);
		float pane_x0 = (window_pitch - window_w) * 0.5;
		float pane_x1 = (window_pitch + window_w) * 0.5;
		if (valid && fx >= pane_x0 && fx <= pane_x1) {
			if (fy >= window_sill - 0.6 && fy < window_sill) {
				float sill = grime * 0.5 * noise21(vec2(p.x * 9.0, p.y * 2.0));
				albedo *= clamp(1.0 - sill, 0.0, 1.0);
			}
			float pane_top = window_sill + window_h;
			if (fy >= pane_top) {
				float soot_amt = soot * smoothstep(1.6, 0.0, fy - pane_top) * (0.6 + 0.4 * noise21(p * 5.0));
				albedo = mix(albedo, vec3(0.02), soot_amt);
			}
		}
	}
	if (fbm(p * 0.6 + seed + 23.0) > 1.0 - overgrowth * 0.5 && p.y < facade_height * 0.7) {
		albedo = vec3(0.08, 0.12, 0.05) * (0.7 + 0.6 * noise21(p * 12.0));
		rough = 0.95;
	}
	if (fbm(p * 1.3 + seed + 41.0) > 1.0 - damage * 0.45) {
		albedo = mix(base_color * 0.5, mortar_color, 0.5);
	}
}

// Full look: ground zone or wall skin, then the window grid, then the overlays.
void facade_shade(vec2 p, out vec3 albedo, out vec3 emission, out float rough, out float metal) {
	float sk = fbm(p * 0.35 + seed);
	if (p.y < ground_height) {
		shade_ground(p, sk, albedo, emission, rough, metal);
	} else {
		shade_skin(p, sk, albedo, emission, rough, metal);
	}
	vec2 w_id;
	vec2 w_local;
	float w_pane;
	float w_frame;
	window_cell(p, w_id, w_local, w_pane, w_frame);
	if (w_frame > 0.5) {
		albedo = accent_color;
		emission = vec3(0.0);
		rough = style == 3 ? 0.6 : 0.7;
		metal = style == 3 ? 0.4 : 0.0;
	} else if (w_pane > 0.5) {
		shade_window(p, w_id, w_local, albedo, emission, rough, metal);
	}
	if (w_pane < 0.5) {
		apply_overlays(p, albedo, emission, rough, metal);
	}
}

void fragment() {
	vec2 p = UV;
	float edge = 0.0;
	bool collapsing = collapse_y > 0.0;
	if (collapsing) {
		edge = collapse_y + (fbm(vec2(p.x * 0.35, seed)) - 0.5) * 6.0;
		if (p.y > edge) {
			discard;
		}
	}
	vec3 albedo;
	vec3 emission;
	float rough;
	float metal;
	facade_shade(p, albedo, emission, rough, metal);
	if (collapsing && p.y > edge - 1.5) {
		albedo = vec3(0.16, 0.15, 0.14) * (0.6 + 0.5 * noise21(p * 4.0));
		emission = vec3(0.0);
		if (mod(p.y - ground_height, floor_height) < 0.3) {
			albedo = vec3(0.32, 0.31, 0.29);
		}
	}
	float e = 0.008;
	float h = facade_relief(p);
	float hx = facade_relief(p + vec2(e, 0.0));
	float hy = facade_relief(p + vec2(0.0, e));
	vec3 n = normalize(vec3(-(hx - h) / e, -(hy - h) / e, 1.0));
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
