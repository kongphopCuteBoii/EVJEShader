in vec2 vaUV0;
in ivec2 vaUV2;
in vec2 mc_Entity;
in vec4 vaColor, at_tangent;
in vec3 vaPosition, vaNormal;

uniform vec3 chunkOffset;
uniform mat3 normalMatrix;
uniform vec3 cameraPosition;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec3 fColor;
flat out int isFoliage, isLeaves, isTallTop;
out vec3 normalMap;
out vec4 tangentData;
out vec2 texCoord, lightCoord;
out vec3 clumpN;

void main() {
    int blockId = int(mc_Entity.x);
    isFoliage = 0; isLeaves = 0; isTallTop = (blockId == 102) ? 1 : 0;
    if (blockId >= 100 && blockId <= 104) {
        if(blockId >= 103) isLeaves = 1;
        isFoliage = 1;
    }

    tangentData = vec4(normalize(normalMatrix * at_tangent.xyz), at_tangent.w);
    normalMap = normalMatrix * vaNormal;
    texCoord = vaUV0; 
    fColor = vaColor.rgb; 
    lightCoord = vaUV2 * 3.9e-3 + 3.125e-2;
    
    vec3 playerPos = vaPosition + chunkOffset;
    
    vec3 fragWorldSpace = playerPos + mod(cameraPosition, 1024.0);

    clumpN = vec3(0.0);
    if (isFoliage != 0) {
        vec3 p1 = fragWorldSpace * 0.15,
             p2 = fragWorldSpace * 0.35;
        clumpN  = sin(p1.yzx * 1.5 + sin(p1.zxy * 2.0)) * 0.22
                + sin(p2.zxy * 2.5) * 0.10;
    }

    gl_Position = projectionMatrix * modelViewMatrix * vec4(playerPos, 1.0);
}