#version 460 compatibility

#include "/libs/irisEssentials.h"
#include "/libs/typeClassifier.h"
#include "/libs/gbufferPacking.h"

/* RENDERTARGETS: 11 */
layout(location = 0) out vec4 outExposure;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex11;

uniform float frameTime;

in vec2 texCoord;

void main() {
    if (gl_FragCoord.x >= 1.0 || gl_FragCoord.y >= 1.0) discard;

    float accumLogLuma = 0.0;
    float weightSum = 0.0;
    
    for (int x = 0; x < 5; x++) {
        for (int y = 0; y < 5; y++) {
            vec2 sampleCoord = vec2(x, y) / 4.0; 
            sampleCoord = mix(vec2(0.1), vec2(0.9), sampleCoord);
            
            float distFromCenter = distance(sampleCoord, vec2(0.5));
            float weight = 1.0 - smoothstep(0.0, 0.6, distFromCenter);
            if (unpackSceneType(texelFetch(colortex1, ivec2(sampleCoord * vec2(textureSize(colortex1, 0))), 0).a) == TYPE_HAND) weight = 0.0;
            
            vec3 sampColor = textureLod(colortex0, sampleCoord, 4.0).rgb; 
            float luma = dot(sampColor, vec3(0.2126, 0.7152, 0.0722));
            
            accumLogLuma += log2(max(luma, 0.0001)) * weight;
            weightSum += weight;
        }
    }
    
    float currentLuma = exp2(accumLogLuma / weightSum);
    currentLuma = clamp(currentLuma, 0.01, 10.0);
    
    float prevLuma = texelFetch(colortex11, ivec2(0), 0).r;
    if (prevLuma <= 0.0001) prevLuma = currentLuma;
    
    float adaptSpeed = (currentLuma > prevLuma) ? 1.5 : 0.8; 
    
    float smoothedLuma = prevLuma + (currentLuma - prevLuma) * (1.0 - exp(-frameTime * adaptSpeed));
    
    outExposure = vec4(smoothedLuma, 0.0, 0.0, 1.0);
}