#include "/libs/irisEssentials.h"
#include "/libs/gbufferPacking.h"
#include "/libs/materialDefaults.h"
#include "/libs/labPBR.glsl"
#include "/libs/mathUtils.glsl"
uniform sampler2D gtexture;
uniform sampler2D normals, specular;
uniform mat4 gbufferModelViewInverse;

/* DRAWBUFFERS:012 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outPBR;

in vec3 fColor;
flat in int isFoliage, isLeaves, isTallTop;
in vec3 normalMap;
in vec4 tangentData;
in vec2 texCoord, lightCoord;
in vec3 clumpN;

// (000) Space Wizardry
mat3 tbnNormalTangent(vec3 normal, vec3 tangent) {
    vec3 biTangent = cross(tangent, normal);
    return mat3(tangent, biTangent, normal);
}

void main() {
    vec4 rawTexture = texture(gtexture, texCoord);
    if (rawTexture.a < 0.1) discard;

    vec3 albedo = pow_linear(rawTexture.rgb * fColor);

    // (000) World Space Normal
    vec3 cubeNormal   = mat3(gbufferModelViewInverse) * normalMap,
         worldTangent = mat3(gbufferModelViewInverse) * tangentData.xyz;
    mat3 TBN = tbnNormalTangent(cubeNormal, worldTangent);

    vec3 worldNormal;
    if (isFoliage != 0) {
        worldNormal = normalize(cubeNormal * 0.40 + clumpN * 0.30 + vec3(0.0, 0.30, 0.0));
    } else {
        vec4 normalData = texture(normals, texCoord) * 2.0 - 1.0;
        vec3 normalTex  = vec3(normalData.xy, sqrt(max(0.0, 1.0 - dot(normalData.xy, normalData.xy))));
        worldNormal = normalize(TBN * normalTex);
    }

    // (000) Specular Data
    PBRMaterial material = decodeLabPBR(texture(specular, texCoord));
    outPBR = mergePBR(vec4(material.roughness,
                           material.metallic,
                           material.emission,
                           material.reflectance));

    outColor  = vec4(albedo, rawTexture.a);
    outNormal = vec4(encodeNormalOct(worldNormal), lightCoord.y,
                     packSceneClass(TYPE, isFoliage != 0 ? (isLeaves != 0 ? 2 : (isTallTop != 0 ? 4 : 1)) : 0));
}
