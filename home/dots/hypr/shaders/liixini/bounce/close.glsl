#version 320 es
precision highp float;
// @duration 0.55
// Ported from https://github.com/liixini/shaders (bounce/close.glsl)

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;

// Ported from skwd-wall bounce transition

void main() {

    float p = progress;
    vec2 uv = v_texcoord;
    float PI = 3.14159265358;
    float bounces = 3.0;

    float time = p;
    float stime = sin(time * PI / 2.0);
    float phase = time * PI * bounces;
    float yy = (abs(cos(phase))) * (1.0 - stime);
    float d = uv.y - yy;

    vec2 sample_uv = uv;
    sample_uv.y = uv.y + (1.0 - yy);
    vec2 tc = sample_uv;
    vec4 win = texture(tex, tc);

    float reveal = step(d, 0.0);
    fragColor = win * reveal;
    return;

}
