#version 460 compatibility

out vec4 fColor;

vec3 distortShadowClipPos(vec3 shadowClipPos) {
    float distortionFactor = length(shadowClipPos.xy) + 0.1;
    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

void main() {
    fColor = gl_Color;
    
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}