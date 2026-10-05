#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (colour-distance/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from skwd-wall colour-distance transition

void main() {

    float p = 1.0 - progress;
    vec2 uv = v_texcoord;
    float power = 5.0;

    vec2 tc = uv;
    vec4 win = texture(tex, tc);

    float colorMag = length(win.rgb);
    float m = step(colorMag, p);
    float reveal = mix(m, 1.0, pow(p, power));

    fragColor = win * reveal;
    return;

}
