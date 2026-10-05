#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (fadecolor/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from skwd-wall fadecolor transition

void main() {

    float p = 1.0 - progress;
    vec2 uv = v_texcoord;
    float colorPhase = 0.4;

    vec2 tc = uv;
    vec4 win = texture(tex, tc);

    float reveal = smoothstep(colorPhase, 1.0, p);
    fragColor = win * reveal;
    return;

}
