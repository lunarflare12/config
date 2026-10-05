#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (ripple/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from gl-transitions/ripple.glsl (MIT, gre)

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    float seed = seed * 6.28318;

    float amplitude = 100.0;
    float speed = 50.0;

    vec2 dir = uv - vec2(0.5);
    float dist = length(dir);

    float intensity = p * p;
    vec2 offset = dir * (sin(p * dist * amplitude - p * speed + seed) + 0.5) / 30.0;

    vec2 wuv = uv + offset * intensity;
    vec2 tc = wuv;
    vec4 color = texture(tex, tc);

    float alpha = smoothstep(1.0, 0.5, p);
    fragColor = color * alpha;
    return;

}
