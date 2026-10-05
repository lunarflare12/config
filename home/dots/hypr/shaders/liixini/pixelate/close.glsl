#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (pixelate/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

void main() {

    float p = progress;
    vec2 uv = v_texcoord;

    float pixel_size = mix(0.0005, 0.10 + seed * 0.04, p * p);
    vec2 pixelated_uv = floor(uv / pixel_size) * pixel_size + pixel_size * 0.5;

    vec2 tex_coords = pixelated_uv;
    vec4 color = texture(tex, tex_coords);

    float alpha = smoothstep(1.0, 0.5, p);

    fragColor = color * alpha;
    return;

}
