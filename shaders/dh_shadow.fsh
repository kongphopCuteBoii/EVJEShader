#version 460 compatibility

in vec4 fColor;

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor;

void main() {
    if (fColor.a < 0.1) discard;
    outColor = vec4(fColor.rgb, 1.0);
}