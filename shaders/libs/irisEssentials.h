#ifndef IRIS_ESSENTIALS_H
#define IRIS_ESSENTIALS_H

// (001) Sun & Shadow Setup
const float sunPathRotation     = -35.0;
const int   shadowMapResolution = 2048;

// (002) Vanilla Behaviour Overrides
const float ambientOcclusionLevel = 0.0;

// (003) Buffer Formats
/*
const int colortex0Format    = RGBA16F;
const int colortex2Format    = RGBA8;
const int colortex5Format    = RGBA16F;
const int colortex7Format    = RGBA16F;
const int colortex3Format    = R11F_G11F_B10F;
const int colortex4Format    = R11F_G11F_B10F;
const int colortex6Format    = R11F_G11F_B10F;
const int colortex8Format    = R11F_G11F_B10F;
const int colortex10Format   = R11F_G11F_B10F;
const int colortex12Format   = R11F_G11F_B10F;
const int colortex13Format   = R11F_G11F_B10F;
*/

// (004) Mipmapping
/*
const bool colortex0MipmapEnabled = true;
*/

// (005) Clear Behaviour
const bool colortex11Clear = false;

#endif
