#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (glass-warp/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

void main() {

    float p = 1.0 - progress;
    vec2 uv = v_texcoord;

    float dist = length(uv - 0.5) * 2.0;
    float start_delay = dist * 0.6;

    float t = clamp((p - start_delay) / (1.0 - start_delay), 0.0, 1.0);
    float strong_t = pow(t, 2.5);
    if (p < start_delay) return vec4(0.0);

    vec2 target = uv;
    vec2 center = vec2(0.5);
    vec2 from_center = uv - center;
    vec2 spawn = center + from_center * 0.0;

    vec2 render_pos = mix(spawn, target, strong_t);

    vec2 tex_coords = render_pos;
    vec4 color = texture(tex, tex_coords);

    fragColor = color * t;
    return;
}
