#ifndef CLOUD_SETTINGS_GLSL
#define CLOUD_SETTINGS_GLSL

#define MIRAI_CLOUDS
#define CLOUD_AMBIENT_LUMA_LOCK 0
#define CLOUD_SUN_INPUT         1.0
#define CLOUD_AMBIENT_INPUT     0.90
#define CLOUD_WIND_SPEED        7.0
#define CLOUD_ALTITUDE_BIAS     200.0
#define CLOUD_GRADE             0.3
#define CLOUD_AMBIENT_HORIZON   0.8
#define CLOUD_HAZE_DIST         2200.0
#define CLOUD_HAZE_GAIN         1.0
#define CLOUD_HAZE_SUN          0.06

#if defined(MIRAI_CLOUDS) && !defined(CLOUD_SETTINGS_ONLY)
    #include "/libs/coreFunctions/miraiClouds.glsl"
#endif

#endif
