# p-kuFX

A collection of shader effects.

Effects are enabled using preprocessor flags:\
`CHROMATIC_ABERRATION`\
`FILM_GRAIN`\
`PERSPECTIVE_CORRECTION`\
`VIGNETTE`

[Similar effects demonstrated on Shadertoy.](https://www.shadertoy.com/view/lXjBWK)

## Perspective Correction
![perspectiveCorrection](https://github.com/user-attachments/assets/5146f78d-8b06-4aa5-942f-dc0405db9075)
Alleviate distortion from wide field of view.
[In-depth explanation in this white paper.](https://github.com/user-attachments/files/22060919/aMoreNaturalPerspective.pdf)

User variables:\
`Distance`: Distance from screen to viewer.\
`Diagonal`: Size of the screen measured diagonally.\
`FOV`: In-game field of view\
`Zoom`: Scales the image, can minimize border as desired.[^1]
[^1]: Changing this value impacts the correction calculations because zooming effectively changes the field of view.

Preprocessor definitions:\
`FOV_TYPE`: How field of view is measured, horizontally (`0`), vertically(`1`), diagonally(`2`)\
`LUT_MODE`: Enable storing of correction calculations to a lookup table.\
`PC_STEPS`: Number of iterations for the correction solver.\
`TEST_GRID`: Enable a test grid to visualize the correction surface.

When using `LUT_MODE`, you must enable the `CreateCorrectionLUT` technique in order to create the texture. Once the correction settings are dialed in, the `CreateCorrectionLUT` technique should be disabled to improve performance.

[Video demonstration.](https://youtu.be/FvE9wk0edbo)

## Chromatic Aberration
![chromaticAberration](https://github.com/user-attachments/assets/7a25f22b-ec80-4490-9cd6-ee58b7480b34)
Simulates the color fringing seen in lenses.

User variables:\
`Intensity`: Intensity of the effect

Preprocessor definitions:\
`CA_JITTER`: Enable jittering of samples (default: `1`, on).\
`CA_SAMPLES`: Number of samples to use (default: `8`, multiple of 4 recommended).\

[Wikipedia explanation.](https://en.wikipedia.org/wiki/Chromatic_aberration)

## Film Grain
![filmGrain](https://github.com/user-attachments/assets/aaf87f3a-57e8-4b46-a554-8f2f73c66b7f)
Adds noise to the image. Noise is applied to the luma rather that directly to color values.

## Vignette
![vignette](https://github.com/user-attachments/assets/63eea488-64fe-4e59-89df-14f677f6030a)
Simulates natural vignette as seen on imaging surfaces.

User variables:\
`Intensity`: Intensity of the effect

[Wikipedia explanation.](https://en.wikipedia.org/wiki/Vignetting#Natural_vignetting)

## Dithering
A dithering pass for the final image. Uses triangular, blue noise.

[Some examples, courtesy of hornet on Shadertoy.](https://www.shadertoy.com/view/WldSRf)
