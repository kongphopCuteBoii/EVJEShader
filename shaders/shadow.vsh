#version 460 compatibility

in vec2 mc_Entity;

flat out int isFoliage, isWater, isThinPlant;
out vec2 texCoord;
out vec4 glColor;

uniform mat4 shadowModelViewInverse;

vec3 distortShadowClipPos(vec3 shadowClipPos){
    float distortionFactor = length(shadowClipPos.xy);
    distortionFactor += 0.1;

    shadowClipPos.xy /= distortionFactor;
    shadowClipPos.z *= 0.5;
    return shadowClipPos;
}

void main() {
    int blockId = int(mc_Entity.x);
    isFoliage = 0; isWater = 0; isThinPlant = 0;
    if (blockId == 200)
        isWater = 1;
    else if (blockId >= 100 && blockId <= 115)
        isFoliage = 1;
    if (blockId >= 100 && blockId <= 102) isThinPlant = 1;

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glColor = gl_Color;

    gl_Position = ftransform();
    gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}