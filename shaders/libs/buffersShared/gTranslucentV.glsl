in vec2 vaUV0;
in vec4 vaColor;
in vec2 mc_Entity;
in vec3 vaPosition, vaNormal;

uniform float frameTimeCounter;
uniform vec3 chunkOffset;
uniform vec3 cameraPosition;
uniform mat3 normalMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 gbufferModelViewInverse;

flat out int materialType;
out vec4 fColor;
out vec3 normalMap;
out vec2 texCoord;
out vec3 worldPos, worldN, viewPos;

#define SWELL_SCALE vec2(1.0)
#define SWELL_DRIFT vec2(0.0, 0.5)
#define SWELL_AMP 0.35
#define SWELL_DRAG 0.5
#include "/libs/coreFunctions/swellOcean.glsl"

void main() {
    int blockId = int(mc_Entity.x); materialType = 0;
    if (blockId == 200) materialType = 1; else if(blockId > 200) materialType = 2;
    //isBlock = 0;
    normalMap = normalMatrix * vaNormal; texCoord = vaUV0; fColor = vaColor;
    vec4 viewSpace = modelViewMatrix * vec4(vaPosition + chunkOffset, 1.0);

    viewPos = viewSpace.xyz;
    worldPos = (gbufferModelViewInverse * viewSpace).xyz + cameraPosition;
    worldN = mat3(gbufferModelViewInverse) * (normalMatrix * vaNormal);
    if (materialType == 1) viewSpace.y += swellHeight(worldPos.xz, frameTimeCounter);
    gl_Position = projectionMatrix * viewSpace;
}