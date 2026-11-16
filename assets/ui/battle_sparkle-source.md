# Battle sparkle

Provided by the user on 16 November 2026 as `sparkle-white.png` for the battle-entry animation.
The original sheet is 16384 x 2048, with three sparkle styles and seven occupied columns.
Original SHA-256: `6fd8de47e9aea2294419fbb75c9a983157f48b3d7b5a9337f09b0129ac84e2bc`.
`tools/prepare_battle_sparkle.gd` packs the first style into seven 128 x 128 frames,
cropping 512 x 512 around each sparkle before downsampling. The original is preserved.
This is a UI effect, outside the world-texture smoothing pipeline.
