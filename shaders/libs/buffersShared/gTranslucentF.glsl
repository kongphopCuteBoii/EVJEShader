uniform sampler2D gtexture;
uniform mat4 gbufferModelView;
uniform vec3 shadowLightPosition;

/* DRAWBUFFERS:029 */
layout(location = 0) out vec4 outScene;
layout(location = 1) out vec4 outGlass;
layout(location = 2) out vec4 outData;

flat in int materialType;
in vec4 fColor;
in vec3 normalMap;
in vec2 texCoord;
in vec3 worldPos, worldN, viewPos;

#define WATER_TEXTURE_BLEND 0.0

#define BEVEL_WIDTH 0.18
#define BEVEL_BEND  0.9

void main() {
    vec4 albedo = texture(gtexture, texCoord) * fColor;

    if (materialType == 1) {
        albedo.rgb *= 0.3183;
        outScene = vec4(albedo.rgb, albedo.a * WATER_TEXTURE_BLEND);
        outGlass = albedo;
        outData = vec4(0.5, 0.5, 0.0, 0.5);
        return;
    }

    outScene = (materialType == 2) ? vec4(0.0) : albedo;
    outGlass = vec4(0.0);
    outData = vec4(0.0);

    if (materialType == 2) {
        outGlass = vec4(clamp(albedo.rgb, 0.0, 1.0), albedo.a);

        vec3 n  = normalize(worldN);
        vec3 an = abs(n);
        vec3 f  = fract(worldPos);

        vec3 d = min(f, 1.0 - f);
        d = mix(d, vec3(1.0), step(0.5, an));
        float edge = min(d.x, min(d.y, d.z));
        vec3 axis  = step(d, vec3(edge + 1e-4));
        vec3 inward = sign(0.5 - f) * axis;

        float k = 1.0 - smoothstep(0.0, BEVEL_WIDTH, edge);
        k *= k;
        vec3 bentW = normalize(n + inward * BEVEL_BEND * k);

        vec3 nV    = mat3(gbufferModelView) * bentW;
        vec3 flatV = mat3(gbufferModelView) * n;
        vec2 delta = (nV - flatV).xy;

        vec3 V = -normalize(viewPos);
        vec3 H = normalize(normalize(shadowLightPosition) + V);
        float spec = pow(max(dot(nV, H), 0.0), 96.0);
        float rim  = pow(1.0 - max(dot(nV, V), 0.0), 3.0) * k;
        float shine = spec * 3.0 + rim * 0.5;

        outData = vec4(delta * 0.5 + 0.5, 0.0, 1.0);
    }
}
