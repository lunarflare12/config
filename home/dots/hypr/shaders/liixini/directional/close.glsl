#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (directional/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from skwd-wall directional transition

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    vec2 tc = uv;
    vec4 win = texture(tex, tc);

    vec2 dir = vec2(0.0, 1.0);
    vec2 q = uv + (1.0 - p) * sign(dir);
    float inside = step(0.0, q.y) * step(q.y, 1.0) * step(0.0, q.x) * step(q.x, 1.0);

    fragColor = win * (1.0 - inside);
    return;

}
