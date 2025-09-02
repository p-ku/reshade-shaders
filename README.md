# p-kuFX

A collection of shader effects.

Effects are enabled using preprocessor flags with the name of the effect.

[Similar effects demonstrated on Shadertoy.](https://www.shadertoy.com/view/lXjBWK)

## `PERSPECTIVE_CORRECTION`
![perspectiveCorrection](https://github.com/user-attachments/assets/2444a772-8f49-4620-bece-4881553ec698)

Alleviate distortion from wide field of view.
[In-depth explanation in this white paper.](https://github.com/user-attachments/files/22060919/aMoreNaturalPerspective.pdf)

User variables:\
- `Distance`: Distance from screen to viewer.\
- `Diagonal`: Size of the screen measured diagonally.\
- `FOV`: In-game field of view\
- `Zoom`: Scales the image, can minimize border as desired.[^1]
[^1]: Zoom level is accounted for in correction calculations as it impacts the field of view.

Preprocessor definitions:\
- `FOV_TYPE`: How field of view is measured, horizontally (`0`), vertically(`1`), diagonally(`2`)\
- `PC_STEPS`: Number of iterations for the correction solver.\
- `TEST_GRID`: Enable a test grid to visualize the correction surface.
- `LIVE_LUT`: Calculate LUT every frame.\
- `LUT_SIZE`: Dimensions of the square LUT texture.\
- `DX9_MODE`: When in `LUT_MODE`, there is a discrepancy between games that use DirectX 9 and DirectX 11. This enables a small adjustment in how the LUT is sampled when using DirectX 9.

When using `LUT_MODE`, you must enable the `CreateCorrectionLUT` technique in order to create the texture. Once the correction settings are dialed in, the `CreateCorrectionLUT` technique should be disabled to improve performance.

[Video demonstration.](https://youtu.be/FvE9wk0edbo)

## `CHROMATIC_ABERRATION`
![chromaticAberration](https://github.com/user-attachments/assets/b9af79aa-2bbb-453e-92ef-b27755335994)

Simulates the color fringing seen in lenses.

User variables:\
- `Intensity`: Intensity of the effect

Preprocessor definitions:\
- `CA_JITTER`: Enable jittering of samples.\
- `CA_SAMPLES`: Number of samples to use (multiple of 4 recommended).\

[Wikipedia explanation.](https://en.wikipedia.org/wiki/Chromatic_aberration)

## `FILM_GRAIN`
![filmGrain](https://github.com/user-attachments/assets/6a79628e-0e01-4acc-9f07-f6d745e9fb3c)

Adds noise to the image. Noise is applied to the luma rather that directly to color values.

User variables:\
- `Intensity`: Intensity of the effect

## `VIGNETTE`
![vignette](https://github.com/user-attachments/assets/95e3d2c3-e37a-4069-a9db-cd8f6e75b067)

Simulates natural vignette as seen on imaging surfaces.

User variables:\
- `Intensity`: Intensity of the effect

If `PERSPECTIVE_CORRECTION` is enabled, vignette will be calculated based on `FOV` and `Intensity` is a factor applied to the distance from the imaging surface. Otherwise, `Intensity` is the full range of distances, zero to infinity (at `1.0`).

[Wikipedia explanation.](https://en.wikipedia.org/wiki/Vignetting#Natural_vignetting)

## Dithering
A dithering pass for the final image. Uses triangular, blue noise.

[Some examples, courtesy of hornet on Shadertoy.](https://www.shadertoy.com/view/WldSRf)
