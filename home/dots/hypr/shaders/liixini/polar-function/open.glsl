#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (polar-function/open.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from skwd-wall polar-function transition

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    vec2 tc = uv;
    vec4 win = texture(tex, tc);

    int segments = 5;
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float radius = (cos(float(segments) * angle) + 4.0) / 4.0;
    float difference = length(uv - vec2(0.5, 0.5));
    float reveal = step(difference, radius * p);

    fragColor = win * reveal;
    return;

}
