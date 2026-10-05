#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (circle/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from gl-transitions/circleopen.glsl (MIT, gre)

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    float seed = seed;

    float smoothness = 0.3;
    float SQRT_2 = 1.414213562;

    // Slightly randomized center
    vec2 center = vec2(0.5 + (seed - 0.5) * 0.15, 0.5 + (seed * 0.7 - 0.35) * 0.15);

    float dist = SQRT_2 * distance(center, uv);
    float m = smoothstep(-smoothness, 0.0, dist - (1.0 - p) * (1.0 + smoothness));
    float remain = 1.0 - m;

    vec2 tc = uv;
    vec4 color = texture(tex, tc);

    fragColor = color * remain;
    return;

}
