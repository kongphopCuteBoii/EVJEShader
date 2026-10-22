#ifndef CLOUD_SETTINGS_GLSL
#define CLOUD_SETTINGS_GLSL

#define MIRAI_CLOUDS
#define CLOUD_AMBIENT_LUMA_LOCK 0
#define CLOUD_SUN_INPUT         1.0
#define CLOUD_AMBIENT_INPUT     0.90
#define CLOUD_WIND_SPEED        7.0
#define CLOUD_ALTITUDE_BIAS     200.0
#define CLOUD_GRADE             0.3

#ifdef MIRAI_CLOUDS
    #include "/libs/coreFunctions/miraiClouds.glsl"
#endif

#endif
