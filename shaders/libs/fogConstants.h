#ifndef FOG_CONSTANTS_H
#define FOG_CONSTANTS_H

#include "/libs/skyGrade.h"

// (071) Fog Constants
#ifndef FOG_STEPS
    #define FOG_STEPS 12
#endif
#ifndef FOG_STEPS_PER_BLOCK
    #define FOG_STEPS_PER_BLOCK 0.3
#endif

const float FOG_DENSITY           = 0.0035,
            FOG_BASE_HEIGHT       = 61.0,
            FOG_FALLOFF           = 16.0,
            FOG_MAX_EXPONENT      = 2.0,
            FOG_MARCH_DIST        = 160.0,
            FOG_SKY_DIST          = 512.0,
            FOG_SCATTER_ALBEDO    = 0.95,
            FOG_SUN_INTENSITY     = 0.60,
            FOG_AMBIENT_INTENSITY = 0.25,
            FOG_MIE_G_FORWARD     = 0.78,
            FOG_MIE_G_SOFT        = 0.25,
            FOG_MIE_BLEND         = 0.65,
            FOG_SHADOW_BIAS       = 0.0002,
            FOG_CAVE_FLOOR        = 0.10;
const vec3  FOG_TINT              = vec3(SKY_GRADE.x, SKY_GRADE.y * 0.95, SKY_GRADE.z) * 0.7;

// (080) Underwater Medium Constants
#ifndef UW_STEPS
    #define UW_STEPS 10
#endif
const vec3  UW_EXTINCTION      = vec3(0.150, 0.052, 0.042),
            UW_LIGHT_EXT       = vec3(0.280, 0.085, 0.060),
            UW_AMBIENT_EXT     = vec3(0.110, 0.040, 0.030),
            UW_WATER_COLOR     = vec3(0.30, 1.00, 0.85);
const float UW_MARCH_DIST      = 72.0,
            UW_SKY_DIST        = 56.0,
            UW_LIGHT_DEPTH     = 15.0,
            UW_ALBEDO          = 0.92,
            UW_SUN_INTENSITY   = 1.5,
            UW_AMBIENT         = 2.2,
            UW_PHASE_G         = 0.72,
            UW_SHAFT_CONTRAST  = 0.55,
            UW_CAUSTIC_STRENGTH = 0.75,
            UW_CAUSTIC_FADE    = 0.10;

#endif
