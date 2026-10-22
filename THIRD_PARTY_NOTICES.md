# Third-party notices

Crystaline is Copyright © 2026 CuteBoii and licensed under the Mozilla Public License 2.0 (see `LICENSE`). That license covers only the original Crystaline contributions. The components below are third-party material and keep their own licenses, which are not replaced by the project license.

Full license texts are in `licenses/`:

- `licenses/MIT-bambosan.txt`
- `licenses/MIT-afl_ext.txt`

## Swell ocean

- File: `shaders/libs/coreFunctions/swellOcean.glsl`
- Original work: Copyright (c) 2017-2024 afl_ext, MIT License (`licenses/MIT-afl_ext.txt`)
- Modifications: Copyright (c) 2026 bambosan, MIT License (`licenses/MIT-bambosan.txt`)

## Volumetric clouds

- File: `shaders/libs/coreFunctions/miraiClouds.glsl`
- Source: adapted from an earlier revision of the clouds code in [bambosan/mirai](https://github.com/bambosan/mirai) (base noise, height sculpting, Worley sculpting and cloud layer setup). Lighting and ray marching have since been reworked by CuteBoii.
- Copyright (c) 2026 bambosan, MIT License (`licenses/MIT-bambosan.txt`)
- Research reference: Andrew Schneider and Nathan Vos, Guerrilla Games, "Nubis: Authoring Real-Time Volumetric Cloudscapes with the Decima Engine," *Advances in Real-Time Rendering in Games*, SIGGRAPH 2017. <https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine>
- Nubis is cited as a research reference only. This does not imply that Guerrilla Games authored, endorsed or licensed the Crystaline implementation.

## Cloud noise texture

- File: `shaders/textures/cloudNoise.png`
- Source: [bambosan/mirai](https://github.com/bambosan/mirai), `cloudNoise` texture
- Copyright (c) 2026 bambosan, MIT License (`licenses/MIT-bambosan.txt`)

## Special thanks

- [Musk Rose](https://github.com/Rinloid/musk_rose_je) by Rinloid, released under CC0 1.0. No attribution is required, but the early backbone of Crystaline grew from it, and it is credited here with gratitude.