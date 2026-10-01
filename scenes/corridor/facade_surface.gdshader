shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Building skin: seven wall styles, a procedural window grid with lit/dark/boarded/
// broken panes, ground-floor storefronts, and grime/soot/overgrowth/damage overlays.
// UV is facade space in METRES (UV.x along the wall from its left end, UV.y above the
// building base) — never scale it by a tile count.

#include "res://scenes/shaders/grime.gdshaderinc"

uniform int style = 0;                 // 0 brick, 1 concrete panel, 2 plaster, 3 glass curtain, 4 corrugated, 5 stone, 6 bare frame
uniform vec3 base_color : source_color = vec3(0.30, 0.16, 0.12);
uniform vec3 accent_color : source_color = vec3(0.22, 0.20, 0.18);   // frames, sills, piers, string courses, spandrels
uniform vec3 mortar_color : source_color = vec3(0.16, 0.15, 0.13);
uniform vec3 dirt_color : source_color = vec3(0.1, 0.09, 0.07);   // foot-of-wall dirt, the sidewalk's edge dirt
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
uniform float growth_height = 0.5;     // metres the foot growth reaches (plan param)
uniform float ivy : hint_range(0.0, 1.0) = 0.0;   // share of wall columns with ivy curtains
uniform float collapse_y = 0.0;        // 0 = intact; else discard above a noisy edge at this height
uniform float flicker = 0.0;           // 1 = lit windows flicker with TIME (fire)
uniform int ground_kind = 0;           // 0 blank, 1 storefront, 2 boarded, 3 roll-up, 4 loading dock, 5 arcade
uniform float ground_units = 2.0;      // storefront / door bays across the facade
uniform float emission_energy = 2.2;   // fire (flicker) windows only; they may bloom
uniform float window_emission = 0.5;   // peak channel of a lit night window; stays under the glow threshold
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float buff : hint_range(0.0, 1.0) = 0.5;           // rolled-over paint rectangles (graffiti buffed out)
uniform float peel : hint_range(0.0, 1.0) = 0.5;           // top coat peeling off an older colour
uniform float ghost : hint_range(0.0, 1.0) = 0.5;          // pale outline of a torn-down sign
uniform float rust_bleed : hint_range(0.0, 1.0) = 0.5;     // rust streaks under old anchors
uniform vec3 under_color : source_color = vec3(0.24, 0.27, 0.22);   // old paint under the top coat
uniform vec3 rust_color : source_color = vec3(0.20, 0.09, 0.04);

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

// 0 while a pattern of this period spans 8+ pixels along its axis, 1 once it is under ~3.
float pattern_fade(float period, float fw) {
	return smoothstep(0.12, 0.35, fw / period);
}

// 0 while a line of this width is half a pixel or wider, 1 once it is under half a pixel.
float line_fade(float width, float fw) {
	return smoothstep(0.5, 2.0, fw / width);
}

// A line mask (1 on the line, d in [0, width)) that fades to its coverage share
// width / period as the line goes sub-pixel, so a grid of thin lines averages out.
float soft_line(float d, float width, float period, float fw) {
	return mix(d < width ? 1.0 : 0.0, width / period, line_fade(width, fw));
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

// Brick coursing: 0.20 m courses, 0.60 m bricks, odd courses offset 0.30 m.
void brick_grid(vec2 p, out vec2 id, out float bx, out float by) {
	float row = floor(p.y / 0.20);
	float offset = mod(row, 2.0) < 1.0 ? 0.0 : 0.30;
	bx = mod(p.x + offset, 0.60);
	by = mod(p.y, 0.20);
	id = vec2(floor((p.x + offset) / 0.60), row);
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
		float mull = 0.12;
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

// Shared boarded-plank look: 0.35 m stripes with wood grain and darker gaps.
vec3 plank_color(vec2 p, vec2 fw) {
	float grain = mix(noise21(p * 8.0), 0.5, pattern_fade(1.0 / 8.0, max(fw.x, fw.y)));
	vec3 wood = accent_color * vec3(1.35, 1.1, 0.8) * (0.85 + 0.3 * grain);
	float plank_shade = mix(hash21(vec2(floor(p.y / 0.35), floor(p.x / 2.4))), 0.5, pattern_fade(0.35, fw.y));
	wood *= 0.8 + 0.4 * plank_shade;
	wood *= mix(1.0, 0.45, soft_line(mod(p.y, 0.35), 0.04, 0.35, fw.y));
	return wood;
}

// Height in metres, grid math only — cheap enough to tap three times for the normal.
float facade_relief(vec2 p, vec2 fw) {
	float h = 0.0;
	vec2 w_id;
	vec2 w_local;
	float w_pane;
	float w_frame;
	window_cell(p, w_id, w_local, w_pane, w_frame);
	if (w_pane > 0.5) {
		h -= 0.15;
	} else if (w_frame > 0.5) {
		if (style == 3) {
			float fx = mod(p.x, 1.5);
			float fy = mod(p.y - ground_height, floor_height);
			bool mullion = (fx < 0.12 || fx > 1.38) && fy >= 0.9 && fy <= floor_height - 0.12;
			h += mullion ? mix(0.03, -0.15, line_fade(0.24, fw.x)) : 0.03;
		} else {
			h += 0.03;
		}
	} else if (style == 0) {
		vec2 id;
		float bx;
		float by;
		brick_grid(p, id, bx, by);
		float my = soft_line(by, 0.03, 0.20, fw.y);
		float mx = soft_line(bx, 0.03, 0.60, fw.x);
		float mortar = 1.0 - (1.0 - mx) * (1.0 - my);
		h += 0.01 - 0.02 * mortar;
	} else if (style == 1) {
		vec2 pm = mod(p, vec2(2.4, 1.2));
		float seam = 1.0 - (1.0 - soft_line(pm.x, 0.04, 2.4, fw.x)) * (1.0 - soft_line(pm.y, 0.04, 1.2, fw.y));
		h -= 0.02 * seam;
	} else if (style == 4) {
		h += 0.02 * sin(p.x / 0.3 * TAU) * (1.0 - pattern_fade(0.3, fw.x));
	} else if (style == 5) {
		vec2 id;
		float bx;
		float by;
		stone_grid(p, id, bx, by);
		float d = min(min(bx, 1.0 - bx), min(by, 0.5 - by));
		h -= 0.03 * (1.0 - smoothstep(0.0, 0.06, d)) * (1.0 - line_fade(0.06, max(fw.x, fw.y)));
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
			h += 0.02 * sin(p.y / 0.40 * TAU) * (1.0 - pattern_fade(0.40, fw.y));
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
void shade_skin(vec2 p, float sk, out vec3 albedo, out vec3 emission, out float rough, out float metal, vec2 fw) {
	albedo = base_color;
	emission = vec3(0.0);
	rough = clamp(roughness_value, 0.78, 0.95);
	metal = 0.0;
	if (style == 0) {
		vec2 brick_id;
		float bx;
		float by;
		brick_grid(p, brick_id, bx, by);
		float my = soft_line(by, 0.03, 0.20, fw.y);
		float mx = soft_line(bx, 0.03, 0.60, fw.x);
		float mortar = 1.0 - (1.0 - mx) * (1.0 - my);
		float bf = max(pattern_fade(0.60, fw.x), pattern_fade(0.20, fw.y));
		vec3 brick = base_color * (0.85 + 0.3 * mix(hash21(brick_id), 0.5, bf));
		float variant = hash21(brick_id + 5.0);
		float vmul = variant < 0.08 ? 0.65 : (variant > 0.94 ? 1.25 : 1.0);
		brick *= mix(vmul, 1.0, bf);
		albedo = mix(brick, mortar_color, mortar);
	} else if (style == 1) {
		vec2 pm = mod(p, vec2(2.4, 1.2));
		albedo = base_color * mix(1.0, 0.75, smoothstep(0.5, 0.8, fbm(p * 0.9 + seed)));
		float seam = 1.0 - (1.0 - soft_line(pm.x, 0.04, 2.4, fw.x)) * (1.0 - soft_line(pm.y, 0.04, 1.2, fw.y));
		float bolt = (length(mod(p, 1.2) - 0.6) < 0.04 && hash21(floor(p / 1.2)) < 0.4) ? 1.0 : 0.0;
		bolt *= 1.0 - line_fade(0.08, max(fw.x, fw.y));
		albedo = mix(albedo, mortar_color * 0.5, bolt);
		albedo = mix(albedo, mortar_color, seam);
	} else if (style == 2) {
		albedo = mix(base_color, base_color * 0.8, smoothstep(0.45, 0.7, sk));
		float crack_cover = smoothstep(0.52, 0.62, fbm(p * 0.22 + seed + 31.0));
		float crack_line = 1.0 - smoothstep(0.008, 0.02, crack_field(p * 0.5 + seed));
		albedo = mix(albedo, mortar_color, crack_line * crack_cover);
		if (fbm(p * 1.3 + seed + 5.0) > 0.66) {
			albedo = base_color * 0.55;
		}
	} else if (style == 4) {
		albedo = base_color * (0.85 + 0.15 * sin(p.x / 0.3 * TAU) * (1.0 - pattern_fade(0.3, fw.x)));
		albedo = mix(albedo, mortar_color, soft_line(mod(p.y, 1.0), 0.04, 1.0, fw.y));
		float rust = 0.6 * smoothstep(0.6, 0.95, fbm(vec2(p.x * 3.0, p.y * 0.4) + seed));
		albedo = mix(albedo, vec3(0.30, 0.11, 0.05), rust);
	} else if (style == 5) {
		vec2 block_id;
		float bx;
		float by;
		stone_grid(p, block_id, bx, by);
		vec3 block = base_color * (0.9 + 0.2 * hash21(block_id));
		float joint = 1.0 - (1.0 - soft_line(bx, 0.04, 1.0, fw.x)) * (1.0 - soft_line(by, 0.04, 0.5, fw.y));
		albedo = mix(block, mortar_color, joint);
	} else if (style == 6) {
		bool is_col = mod(p.x, 4.0) < 0.5;
		bool is_slab = mod(p.y - ground_height, floor_height) < 0.35;
		albedo = (is_col || is_slab) ? base_color : vec3(0.01);
	}
}

// Night palette for a lit window: warm tungsten or sodium amber, a few dim fluorescent green.
// Max channel is 1.0; callers scale by window_emission so a pane never clips or blooms.
vec3 night_window_tint(float h) {
	float t = hash11(h * 233.0);
	if (t < 0.15) {
		return vec3(0.55, 0.78, 0.42) * 0.7;   // sick fluorescent green, dimmer
	} else if (t < 0.55) {
		return vec3(1.0, 0.62, 0.30);          // tungsten
	} else if (t < 0.85) {
		return vec3(1.0, 0.50, 0.18);          // sodium amber
	}
	return vec3(0.92, 0.70, 0.45);             // warm incandescent, the palest allowed
}

// Per-window pane state: lit, boarded, broken or dark, from a hash on the window id.
void shade_window(vec2 p, vec2 id, vec2 local, out vec3 albedo, out vec3 emission, out float rough, out float metal, vec2 fw) {
	float h = hash21(id + vec2(seed, seed * 0.37));
	emission = vec3(0.0);
	if (h < lit_ratio) {
		float curtain = 1.0 - 0.5 * smoothstep(0.55, 1.0, local.y);
		float flick = flicker > 0.5
			? clamp(0.55 + 0.45 * sin(TIME * 23.0 + h * 40.0) * sin(TIME * 7.0 + h * 13.0), 0.2, 1.0)
			: 1.0;
		albedo = glass_color;
		if (flicker > 0.5) {
			emission = lit_color * emission_energy * (0.55 + 0.45 * hash11(h * 91.0)) * curtain * flick;
		} else {
			emission = night_window_tint(h) * window_emission * (0.45 + 0.55 * hash11(h * 91.0)) * curtain;
		}
		if (style == 3) {
			emission *= 0.7;
		}
		rough = 0.6;
		metal = 0.0;
	} else if (h < lit_ratio + boarded_ratio) {
		albedo = plank_color(p, fw);
		rough = 0.95;
		metal = 0.0;
	} else if (h < lit_ratio + boarded_ratio + broken_ratio) {
		float shard = 1.0 - smoothstep(0.0, 0.05, crack_field(local * 3.0 + h));
		albedo = glass_color * 0.3 + vec3(0.12 * shard);
		rough = 0.6;
		metal = 0.0;
	} else {
		float diag = fract(local.x * 0.7 + local.y * 0.4 + h);
		albedo = glass_color + vec3(0.03 * smoothstep(0.4, 0.6, diag));
		rough = 0.5;
		metal = 0.0;
	}
}

// Ground-floor zone by ground_kind; unit_w/u/ux split the facade into door/shop bays.
void shade_ground(vec2 p, float sk, out vec3 albedo, out vec3 emission, out float rough, out float metal, vec2 fw) {
	float unit_w = facade_width / ground_units;
	float u = floor(p.x / unit_w);
	float ux = p.x - u * unit_w;
	shade_skin(p, sk, albedo, emission, rough, metal, fw);
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
				vec3 shop_tint = night_window_tint(hash21(vec2(u, seed + 7.0)));
				emission = shop_tint * window_emission * 0.9 * (1.0 - 0.6 * smoothstep(1.2, 3.4, p.y));
				if (fract(p.y * 1.6) < 0.12) {
					emission += shop_tint * 0.08;
				}
				rough = 0.6;
				metal = 0.0;
			} else {
				rough = 0.5;
				metal = 0.0;
			}
		} else if (p.y < 4.2) {
			albedo = accent_color;
		} else {
			albedo = glass_color;
			rough = 0.5;
			metal = 0.0;
		}
	} else if (ground_kind == 2) {
		if (p.y < 0.5) {
			albedo = accent_color * 0.6;
		} else {
			float gap = hash21(vec2(floor(p.y / 0.35), u)) < 0.12 ? 1.0 : 0.0;
			gap = mix(gap, 0.12, pattern_fade(0.35, fw.y));
			albedo = mix(plank_color(p, fw), vec3(0.01), gap);
		}
		rough = 0.95;
	} else if (ground_kind == 3 && p.y < 3.8 && ux >= 0.5 && ux <= unit_w - 0.5) {
		if (ux < 0.8 || ux > unit_w - 0.8 || p.y < 0.3 || p.y > 3.5) {
			albedo = mortar_color;
		} else {
			vec3 col = accent_color * (0.9 + 0.1 * sin(p.y / 0.40 * TAU) * (1.0 - pattern_fade(0.40, fw.y)));
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
				emission = vec3(1.0, 0.55, 0.2) * 1.4;
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

// Signed distance (metres) to a rectangle: negative inside.
float rect_sd(vec2 p, vec2 centre, vec2 half_size) {
	vec2 q = abs(p - centre) - half_size;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

// Rust run down from an anchor (a): 1 at the bolt, fading to 0 over len, narrowing from
// top_w to 1 cm and wobbling +-1 cm. Fades to a faint tint as the line goes sub-pixel.
float rust_streak(vec2 p, vec2 a, float len, float top_w, float fwm) {
	float t = (a.y - p.y) / len;
	if (t < 0.0 || t > 1.0) {
		return 0.0;
	}
	float wobble = (noise21(vec2(p.y * 3.0, a.x * 7.1)) - 0.5) * 0.02;
	float half_w = mix(top_w, 0.01, t) * 0.5;
	return soft_line(abs(p.x - a.x - wobble), half_w, 0.9, fwm) * (1.0 - t);
}

// The road's grime recipe over everything but a window pane, in its order: grain, a broad
// wash, rain streaks down from the roof line and sills, soot, the foot dirt band, stains,
// cracks, then overgrowth and damage patches. Fine layers fade with fw like the patterns.
void apply_overlays(vec2 p, inout vec3 albedo, inout vec3 emission, inout float rough, inout float metal, vec2 fw) {
	if (string_course(p)) {
		albedo = accent_color;
	}
	float fwm = max(fw.x, fw.y);
	float grain = mix(noise21(p * 10.0 + seed), 0.5, pattern_fade(1.0 / 10.0, fwm));
	albedo *= 0.9 + 0.2 * grain;
	albedo *= 1.0 - grime * 0.3 * fbm(p * 0.35 + seed + 11.0);

	float streak = smoothstep(0.55, 0.85, noise21(vec2(p.x * 3.0, p.y * 0.08) + seed + 29.0));
	streak = mix(streak, 0.25, pattern_fade(1.0 / 3.0, fw.x));
	float run = 0.2 + 0.8 * (1.0 - smoothstep(0.0, 6.0, max(facade_height - p.y, 0.0)));
	float head_soot = 0.0;
	if (windows_on > 0.5 && style != 6 && style != 3 && p.y >= ground_height) {
		float row; float fy; float col; float fx; bool valid;
		window_grid(p, row, fy, col, fx, valid);
		float pane_x0 = (window_pitch - window_w) * 0.5;
		float pane_x1 = (window_pitch + window_w) * 0.5;
		if (valid && fx >= pane_x0 - 0.1 && fx <= pane_x1 + 0.1) {
			if (fy < window_sill) {
				run = max(run, 1.0 - smoothstep(0.0, 1.8, window_sill - fy));
			}
			float pane_top = window_sill + window_h;
			if (fy >= pane_top) {
				head_soot = (1.0 - smoothstep(0.0, 1.6, fy - pane_top)) * (0.6 + 0.4 * noise21(p * 5.0));
			}
		}
	}
	float rain_k = grime * 0.55 * streak * run;
	albedo *= 1.0 - rain_k;

	float roof_soot = (1.0 - smoothstep(0.0, 2.5, max(facade_height - p.y, 0.0)))
		* (0.5 + 0.5 * fbm(p * 0.8 + seed + 3.0));
	float soot_amt = max(soot * head_soot, max(soot, grime * 0.35) * roof_soot * 0.7);
	albedo = mix(albedo, vec3(0.02), soot_amt);

	// Per-building offset for the 2D lookups below, so no two buildings share a pattern.
	vec2 so = vec2(fract(seed * 0.1731) * 97.0, fract(seed * 0.3127) * 89.0);

	// Soot wash: broad sheets of wall that was never cleaned.
	float sheet = smoothstep(0.35, 0.75, fbm(p * 0.35 + so));
	albedo *= mix(1.0, 0.45, soot * sheet);

	// Soot runs: streaks hanging below each floor line and the roof edge, 0.8 m columns.
	if (p.y >= ground_height && p.y <= facade_height) {
		float run_d = facade_height - p.y;
		if (floor_height > 0.0) {
			run_d = min(run_d, floor_height - mod(p.y - ground_height, floor_height));
		}
		float rcx = floor(p.x / 0.8);
		if (hash11(rcx + so.x) < 0.35 + 0.4 * soot) {
			float run_len = mix(0.6, 1.5, hash11(rcx + 17.0 + so.x));
			float run_w = mix(0.25, 0.6, hash11(rcx + 31.0 + so.x));
			float run_dx = abs(p.x - (rcx + 0.5) * 0.8);
			float run_k = clamp(1.0 - run_d / run_len, 0.0, 1.0)
				* (1.0 - smoothstep(run_w * 0.25, run_w * 0.5, run_dx));
			albedo *= 1.0 - 0.5 * soot * run_k * (1.0 - pattern_fade(0.8, fw.x));
		}
	}

	float foot_edge = 0.9 + (fbm(vec2(p.x * 1.5, 3.0) + seed + 13.0) - 0.5) * 0.5;
	float foot = 1.0 - smoothstep(0.0, foot_edge, p.y);
	foot *= 0.4 + 0.6 * fbm(vec2(p.x * 4.0, p.y * 3.0) + seed + 7.0);
	albedo = mix(albedo, dirt_color, foot * (0.35 + 0.4 * grime));

	float stain = smoothstep(0.58, 0.85, fbm(p * 0.45 + seed + 5.2)) * grime;
	albedo = mix(albedo, albedo * vec3(0.55, 0.5, 0.42), stain * 0.8);

	float cracks = (1.0 - smoothstep(0.012, 0.04, crack_field(p * 0.8 + seed + 4.1)))
		* (1.0 - line_fade(0.03, fwm));
	cracks *= smoothstep(0.45, 0.75, fbm(p * 0.3 + seed + 17.0))
		* clamp(0.25 * grime + 0.9 * damage, 0.0, 1.0);
	albedo = mix(albedo, mortar_color * 0.4, cracks * 0.8);

	if (fbm(p * 0.6 + seed + 23.0) > 1.0 - overgrowth * 0.5 && p.y < facade_height * 0.7) {
		albedo = vec3(0.05, 0.075, 0.035) * (0.7 + 0.6 * noise21(p * 6.0));
		rough = 0.95;
	}
	// Foot growth: moss and dry grass in 0.25 m clumps, thinning out up to growth_height.
	float grow_top = growth_height * mix(0.6, 1.4, fbm(vec2(p.x * 0.8, 3.7) + so));
	float grow_dens = pow(1.0 - smoothstep(0.0, max(grow_top, 0.05), p.y), 0.7);
	// Soft round blobs (one per cell, jittered) so the band reads as moss, not square pixels.
	vec2 grow_c = floor(p / 0.25);
	vec2 grow_f = fract(p / 0.25);
	vec2 blob_mid = 0.5 + (vec2(hash21(grow_c + so), hash21(grow_c + so + 17.0)) - 0.5) * 0.6;
	float blob_r = 0.35 + 0.2 * hash21(grow_c + so + 31.0);
	float blob = 1.0 - smoothstep(blob_r * 0.6, blob_r, length(grow_f - blob_mid));
	float blob_v = blob * (0.8 + 0.2 * fbm(p * 3.0 + so));
	float grow_t = 1.0 - grow_dens;
	float clump = smoothstep(grow_t, grow_t + 0.15, blob_v);
	clump = mix(grow_dens * 0.6, clump, 1.0 - pattern_fade(0.25, fwm));
	vec3 grow_col = mix(vec3(0.05, 0.075, 0.035), vec3(0.08, 0.08, 0.04),
		smoothstep(0.35, 0.65, fbm(p * 1.5 + so)));
	albedo = mix(albedo, grow_col, clump * 0.85);
	if (fbm(p * 1.3 + seed + 41.0) > 1.0 - damage * 0.45) {
		albedo = mix(base_color * 0.5, mortar_color, 0.5);
	}

	rough = min(rough + stain * 0.05 + foot * 0.06, 0.95);

	// Decay marks, after the grime so they sit on top of it. All of them are only the ghosts
	// of graffiti and posters; the windows never reach here (the caller skips panes).
	bool walled = style != 3 && style != 6;

	// 1. Buffed paint-overs: mismatched rectangles in the ground band, rarely the first floor.
	if (walled) {
		vec2 cell_size = vec2(3.0, 1.6);
		vec2 cid = floor(p / cell_size);
		float cell_mid = (cid.y + 0.5) * cell_size.y;
		float row_cap = ground_height + floor_height;
		float cell_chance = 0.45 * buff * (0.5 + grime) * (cell_mid < ground_height ? 1.0 : 0.25);
		if (cid.y * cell_size.y < row_cap && hash21(cid + vec2(seed, 17.0)) < cell_chance) {
			float rect_w = mix(0.8, 2.8, hash21(cid + vec2(seed, 18.0)));
			float rect_h = mix(0.5, 1.5, hash21(cid + vec2(seed, 19.0)));
			float rect_x0 = cid.x * cell_size.x + (cell_size.x - rect_w) * hash21(cid + vec2(seed, 20.0));
			float rect_y0 = max(cid.y * cell_size.y + (cell_size.y - rect_h) * hash21(cid + vec2(seed, 21.0)), 0.4);
			float rect_y1 = min(rect_y0 + rect_h, (cid.y + 1.0) * cell_size.y);
			if (rect_y1 - rect_y0 > 0.05) {
				vec2 rect_c = vec2(rect_x0 + rect_w * 0.5, (rect_y0 + rect_y1) * 0.5);
				vec2 rect_hs = vec2(rect_w * 0.5, (rect_y1 - rect_y0) * 0.5);
				float aa = max(0.01, fwm);
				float buff_m = 1.0 - smoothstep(-aa, aa, rect_sd(p, rect_c, rect_hs));
				float shift = 0.10 + 0.08 * hash21(cid + vec2(seed, 22.0));
				float sgn = hash21(cid + vec2(seed, 23.0)) > 0.5 ? 1.0 : -1.0;
				vec3 target = hash21(cid + vec2(seed, 24.0)) > 0.5 ? vec3(0.30, 0.29, 0.26) : base_color * 0.7;
				float hue = (hash21(cid + vec2(seed, 25.0)) - 0.5) * 0.04;
				vec3 paint = max(mix(base_color, target, 0.4) * (1.0 + sgn * shift) + vec3(hue, 0.0, -hue), vec3(0.0));
				float roller = (noise21(vec2(p.x * 0.5, floor(p.y / 0.22))) - 0.5) * 0.08;
				paint *= 1.0 + roller * (1.0 - pattern_fade(0.22, fw.y));
				// Newer paint: the dirt underneath shows through only 70%.
				vec3 dirty = albedo * clamp(paint / max(base_color, vec3(0.02)), vec3(0.6), vec3(1.6));
				albedo = mix(albedo, mix(dirty, paint, 0.3), buff_m);
				rough = mix(rough, 0.85, buff_m);
			}
		}
	}

	// 2. Peeling paint: clusters of top coat lifting off an older colour.
	if (style == 1 || style == 2 || style == 5) {
		vec2 pp = p * 0.8 + seed;
		float pf = fbm(pp);
		float cluster = smoothstep(0.44, 0.46, fbm(p * 0.25));
		float amt = clamp((0.4 + damage) * peel, 0.0, 1.0) * cluster;
		float peel_m = smoothstep(0.62, 0.66, pf) * amt;
		if (amt > 0.0) {
			// Distance to the 0.62 contour in metres, from the field's slope.
			float pe = 0.02;
			float slope = max(length(vec2(fbm(pp + vec2(pe * 0.8, 0.0)) - pf, fbm(pp + vec2(0.0, pe * 0.8)) - pf)) / pe, 0.05);
			float contour = (pf - 0.62) / slope;
			vec3 under = mix(under_color, vec3(0.22, 0.21, 0.2), fbm(p * 2.5 + seed + 61.0));
			albedo = mix(albedo, under, peel_m);
			float rim = contour >= 0.0 ? soft_line(contour, 0.015, 1.0, fwm) : 0.0;
			float shadow = contour < 0.0 ? soft_line(-contour, 0.01, 1.0, fwm) : 0.0;
			albedo *= 1.0 + 0.15 * rim * amt - 0.2 * shadow * amt;
			rough = mix(rough, 0.9, peel_m);
		}
	}
	// Brick has no top coat to lift: scraps of old paint cling to it instead.
	if (style == 0) {
		float p_lo = 1.0 - peel * 0.3;
		float paint_m = smoothstep(p_lo, p_lo + 0.03, fbm(p * 0.6 + so));
		albedo = mix(albedo, min(under_color, vec3(0.22)), paint_m * 0.85);
	}

	// 3. Ghost sign: one pale, bolted rectangle per building where a sign used to hang.
	if (walled && hash21(vec2(seed, 7.0)) < 0.55 * ghost) {
		float gw = mix(1.4, 3.2, hash21(vec2(seed, 8.0)));
		float gh = mix(0.5, 1.1, hash21(vec2(seed, 9.0)));
		float gu_lo = 0.4 + gw * 0.5;
		float gu = mix(gu_lo, max(gu_lo, facade_width - 0.4 - gw * 0.5), hash21(vec2(seed, 10.0)));
		float gy = ground_height - 0.9 + (hash21(vec2(seed, 11.0)) - 0.5) * 0.6;
		vec2 g_hs = vec2(gw * 0.5, gh * 0.5);
		float gsd = rect_sd(p, vec2(gu, gy), g_hs);
		float aa = max(0.01, fwm);
		float g_in = 1.0 - smoothstep(-aa, aa, gsd);
		// The sign shielded the wall: 12% lighter, and 60% of the rain streaks never landed.
		albedo *= mix(1.0, 1.12 * (1.0 - 0.4 * rain_k) / max(1.0 - rain_k, 0.2), g_in);
		float outline = gsd >= 0.0 ? soft_line(gsd, 0.04, 1.0, fwm) : 0.0;
		albedo = mix(albedo, albedo * 0.7, outline * 0.6);
		int bolts = 2 + int(floor(hash21(vec2(seed, 12.0)) * 3.0));
		float hole_fade = 1.0 - line_fade(0.03, fwm);
		for (int i = 0; i < 4; i++) {
			if (i >= bolts) {
				break;
			}
			vec2 corner = vec2(i % 2 == 0 ? -1.0 : 1.0, i < 2 ? 1.0 : -1.0);
			vec2 bolt = vec2(gu, gy) + corner * (g_hs - vec2(0.12, 0.1));
			vec2 bd = abs(p - bolt);
			if (bd.x < 0.015 && bd.y < 0.015) {
				albedo = mix(albedo, vec3(0.02), 0.85 * hole_fade);
			}
			float g_len = mix(0.3, 0.8, hash21(vec2(seed, 30.0 + float(i))));
			float g_rust = rust_streak(p, bolt - vec2(0.0, 0.02), g_len, 0.04, fwm);
			albedo = mix(albedo, rust_color, 0.6 * g_rust);
			rough = mix(rough, 0.88, g_rust);
		}
	}

	// 4. Rust bleed: dark bolts with an orange streak running down from each.
	if (style != 3) {
		vec2 rcell = vec2(1.8, 2.4);
		vec2 rid = floor(p / rcell);
		float rust_chance = 0.10 * rust_bleed * (0.5 + grime) * (style == 4 ? 2.0 : 1.0);
		for (int k = 0; k < 2; k++) {
			// Streaks reach up to 2.0 m, so the cell above can run into this one.
			vec2 cid2 = rid + vec2(0.0, float(k));
			vec2 rh = vec2(hash21(cid2 + vec2(seed, 40.0)), hash21(cid2 + vec2(seed, 41.0)));
			if (hash21(cid2 + vec2(seed, 42.0)) >= rust_chance) {
				continue;
			}
			vec2 anchor = (cid2 + vec2(0.15 + 0.7 * rh.x, 0.3 + 0.7 * rh.y)) * rcell;
			float r_len = mix(0.5, 2.0, hash21(cid2 + vec2(seed, 43.0)));
			float r_top = mix(0.03, 0.06, hash21(cid2 + vec2(seed, 44.0)));
			vec2 rd = abs(p - anchor);
			if (rd.x < 0.02 && rd.y < 0.02) {
				albedo = mix(albedo, vec3(0.02), 0.85 * (1.0 - line_fade(0.04, fwm)));
			}
			float r_str = rust_streak(p, anchor - vec2(0.0, 0.02), r_len, r_top, fwm);
			albedo = mix(albedo, rust_color, 0.6 * r_str);
			rough = mix(rough, 0.88, r_str);
		}
	}

	// 5. Damp tide line: darker, greener base with a pale salt rim at its top edge.
	float tide_top = 0.3 + 0.9 * fbm(vec2(p.x * 0.4, seed));
	float damp = 1.0 - smoothstep(tide_top - max(0.01, fw.y), tide_top + max(0.01, fw.y), p.y);
	albedo = mix(albedo, mix(albedo * 0.82, vec3(0.05, 0.07, 0.05), 0.15), damp);
	rough = mix(rough, 0.8, damp);
	float salt = p.y < tide_top ? soft_line(tide_top - p.y, 0.02, 1.0, fwm) : 0.0;
	albedo *= 1.0 + 0.12 * salt;

	// 6. Ivy curtains: ragged-sided columns of leaves climbing from the foot, in 2.5 m cells.
	if (ivy > 0.0) {
		float ci = floor(p.x / 2.5);
		if (hash11(ci + 5.0 + so.x) < ivy) {
			float iw = mix(1.2, 2.5, hash11(ci + 9.0 + so.x));
			float ic = (ci + 0.5) * 2.5 + (hash11(ci + 13.0 + so.x) - 0.5) * 0.4;
			float edge = abs(p.x - ic) + (fbm(vec2(p.y * 1.5, ci) + so) - 0.5) * 0.6;
			float reach = growth_height + ivy * mix(3.0, 6.0, hash11(ci + 21.0 + so.x))
				+ (fbm(vec2(p.x * 2.0, 1.3) + so) - 0.5) * 1.2;
			if (edge < iw * 0.5 && p.y >= 0.0 && p.y < reach) {
				float leaf = hash21(floor(p / 0.25) + ci + so);
				float lfade = pattern_fade(0.25, fwm);
				float cover = mix(leaf < 0.15 ? 0.0 : 1.0, 0.85, lfade);
				float bright = mix(mix(0.7, 1.2, leaf), 0.95, lfade);
				albedo = mix(albedo, vec3(0.04, 0.07, 0.03) * bright, cover);
			}
		}
	}

	float lum = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	if (lum > 0.4) {
		albedo *= 0.4 / lum;
	}
}

// Full look: ground zone or wall skin, then the window grid, then the overlays.
void facade_shade(vec2 p, out vec3 albedo, out vec3 emission, out float rough, out float metal, vec2 fw) {
	float sk = fbm(p * 0.35 + seed);
	if (p.y < ground_height) {
		shade_ground(p, sk, albedo, emission, rough, metal, fw);
	} else {
		shade_skin(p, sk, albedo, emission, rough, metal, fw);
	}
	vec2 w_id;
	vec2 w_local;
	float w_pane;
	float w_frame;
	window_cell(p, w_id, w_local, w_pane, w_frame);
	if (w_frame > 0.5) {
		albedo = accent_color;
		emission = vec3(0.0);
		rough = style == 3 ? 0.78 : 0.8;
		metal = style == 3 ? 0.2 : 0.0;
		if (style == 3) {
			float fx = mod(p.x, 1.5);
			float fy = mod(p.y - ground_height, floor_height);
			if ((fx < 0.12 || fx > 1.38) && fy >= 0.9 && fy <= floor_height - 0.12) {
				albedo = mix(accent_color, glass_color, line_fade(0.24, fw.x));
			}
		}
	} else if (w_pane > 0.5) {
		shade_window(p, w_id, w_local, albedo, emission, rough, metal, fw);
	}
	if (w_pane < 0.5) {
		apply_overlays(p, albedo, emission, rough, metal, fw);
	}
}

void fragment() {
	vec2 p = UV;
	vec2 fw = fwidth(p);
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
	facade_shade(p, albedo, emission, rough, metal, fw);
	if (collapsing && p.y > edge - 1.5) {
		albedo = vec3(0.16, 0.15, 0.14) * (0.6 + 0.5 * noise21(p * 4.0));
		emission = vec3(0.0);
		if (mod(p.y - ground_height, floor_height) < 0.3) {
			albedo = vec3(0.32, 0.31, 0.29);
		}
	}
	float e = 0.008;
	float h = facade_relief(p, fw);
	float hx = facade_relief(p + vec2(e, 0.0), fw);
	float hy = facade_relief(p + vec2(0.0, e), fw);
	vec3 n = normalize(vec3(-(hx - h) / e, -(hy - h) / e, 1.0));
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
