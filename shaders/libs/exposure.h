#ifndef EXPOSURE_H
#define EXPOSURE_H

const float targetExposure     = 0.25;
const float adaptationStrength = 0.6;

// (001) Exposure From Adapted Luma
float exposureFromLuma(float smoothedLuma) {
    float curvedLuma = pow(max(smoothedLuma, 0.001), adaptationStrength);
    return clamp(targetExposure / curvedLuma, 0.2, 5.0);
}

#endif
