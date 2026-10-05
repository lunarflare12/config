#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (snap/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    float seed = seed * 100.0;

    float num_layers = 10.0;
    float pixel_layer = floor(hash(floor(uv * vec3(1.0).xy) + seed) * num_layers);

    vec4 result = vec4(0.0);
    vec2 target = vec2(1.0, 0.0);

    for (int i = 0; i < 10; i++) {
    float layer = float(i);
    float layer_delay = layer * 0.06;
    float layer_p = clamp((p - layer_delay) / (1.0 - layer_delay * 0.5), 0.0, 1.0);

    float t = layer_p * layer_p;

    float layer_alpha = 1.0 - smoothstep(0.3, 0.85, layer_p);

    float lh = hash(vec2(layer + 0.5, seed));
    vec2 layer_target = target + vec2(-0.08 + lh * 0.16, -0.04 + lh * 0.08);

    float converge = t * 0.92;
    vec2 sample_uv = (uv - layer_target * converge) / (1.0 - converge);

    vec2 tex_coords = sample_uv;
    vec4 color = texture(tex, tex_coords);

    float belongs = step(abs(pixel_layer - layer), 0.5);
    result += color * belongs * layer_alpha;
    }

    float initial_fade = smoothstep(0.0, 0.05, p);
    result.a *= mix(1.0, 0.0, initial_fade);
    vec2 base_tex = uv;
    vec4 base_color = texture(tex, base_tex);
    float base_alpha = 1.0 - smoothstep(0.0, 0.1, p);

    fragColor = base_color * base_alpha + result * (1.0 - base_alpha);
    return;

}
