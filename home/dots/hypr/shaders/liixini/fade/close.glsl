#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (fade/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

void main() {

    float p = progress;
    vec2 uv = v_texcoord;

    vec2 center = vec2(0.5, 0.5);
    float scale = mix(1.0, 0.95, p);
    vec2 scaled_uv = (uv - center) / scale + center;

    vec2 tex_coords = scaled_uv;
    vec4 color = texture(tex, tex_coords);

    float alpha = smoothstep(1.0, 0.2, p);

    fragColor = color * alpha;
    return;

}
