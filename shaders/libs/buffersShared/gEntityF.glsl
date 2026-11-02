#include "/libs/gbufferPacking.h"
#include "/libs/materialDefaults.h"
#include "/libs/labPBR.glsl"
#include "/libs/mathUtils.glsl"
uniform sampler2D gtexture, specular;
uniform vec4 entityColor;

/* DRAWBUFFERS:012 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outNormal;
layout(location = 2) out vec4 outPBR;

in vec3 fColor, worldN;
flat in int isCloth;
in vec2 texCoord, lightCoord;

void main() {
    vec4 rawTexture = texture(gtexture, texCoord);
    if (rawTexture.a < 0.1) discard;

    vec3 albedo = rawTexture.rgb * fColor;
    albedo = mix(albedo, entityColor.rgb, entityColor.a);
    albedo = pow_linear(albedo);

    vec3 worldNormal = normalize(worldN);
    if (!gl_FrontFacing) worldNormal = -worldNormal;

    // (000) Specular Data
    PBRMaterial material = decodeLabPBR(texture(specular, texCoord));
    outPBR = mergePBR(vec4(material.roughness,
                           material.metallic,
                           material.emission,
                           material.reflectance));

    outColor  = vec4(albedo, rawTexture.a);
    outNormal = vec4(encodeNormalOct(worldNormal), lightCoord.y, packSceneClass(TYPE, isCloth != 0 ? 3 : 0));
}
