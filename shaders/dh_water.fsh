#version 460 compatibility

/* DRAWBUFFERS:9 */
layout(location = 0) out vec4 outData;

in vec4 fColor;

void main() {
    if (fColor.a < 0.1) discard;
    outData = vec4(0.0, 0.0, 0.0, 0.25);
}
