#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (overexposure/open.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from skwd-wall overexposure transition

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    float strength = 0.6;
    float PI = 3.141592653589793;

    vec2 tc = uv;
    vec4 win = texture(tex, tc);

    float to_m = p + sin(PI * p) * strength;
    vec4 mixed = vec4(
    win.r * win.a * to_m,
    win.g * win.a * to_m,
    win.b * win.a * to_m,
    win.a * p
    );

    fragColor = mixed;
    return;

}
