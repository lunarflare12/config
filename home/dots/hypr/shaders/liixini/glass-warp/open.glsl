#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (glass-warp/open.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

void main() {

    float p = progress;
    vec2 uv = v_texcoord;

    float dist = length(uv - 0.5) * 2.0;
    float start_delay = dist * 0.6;
    float t = clamp((p - start_delay) / (1.0 - start_delay), 0.0, 1.0);
    float strong_t = pow(t, 2.5);

    if (p < start_delay) return vec4(0.0);

    vec2 center = vec2(0.5);
    vec2 from_center = uv - center;
    vec2 spawn = center + from_center * 0.1;
    vec2 render_pos = mix(spawn, uv, strong_t);

    vec2 tex_coords = render_pos;
    vec4 color = texture(tex, tex_coords);

    bool is_window_area = uv.x >= -0.075 && uv.x <= 1.075 &&
    uv.y >= -0.075 && uv.y <= 1.075;

    float alpha = mix(1.0, t, pow(dist, 0.5));
    if (!is_window_area) {
    float ring_fade = 1.0 - smoothstep(0.99, 0.999, p);
    alpha *= ring_fade;
    }
    fragColor = color * alpha;
    return;
}
