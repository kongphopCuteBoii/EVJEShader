#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/shadowEssentials.h"

uniform sampler2D gtexture;

flat in int isFoliage, isWater, isThinPlant;
in vec2 texCoord;
in vec4 glColor;

layout(location = 0) out vec4 outAlbedo;


void main() {
    vec4 color = texture(gtexture, texCoord) * glColor;
    if (color.a < 0.1 || isWater != 0) discard;

    outAlbedo = vec4(color.rgb, 1.0);
}