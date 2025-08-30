# p-kuFX

A collection of shader effects.

Effects are enabled using preprocessor flags:\
`CHROMATIC_ABERRATION`\
`FILM_GRAIN`\
`PERSPECTIVE_CORRECTION`\
`VIGNETTE`\
[Similar effects in motion on Shadertoy.](https://www.shadertoy.com/view/lXjBWK)

## Perspective Correction
Alleviate distortion from wide field of view.

[In-depth explanation in this white paper.](https://github.com/user-attachments/files/22053379/aMoreNaturalPerspective.pdf)

[Video demonstration.](https://youtu.be/FvE9wk0edbo)

## Chromatic Aberration
Simulates the color fringing seen in lenses.

[Wikipedia explanation.](https://en.wikipedia.org/wiki/Chromatic_aberration)

## Film Grain
Adds noise to the image. Noise is applied to the luma rather that directly to color values.

## Vignette
Simulates natural vignette as seen on imaging surfaces.

[Wikipedia explanation.](https://en.wikipedia.org/wiki/Vignetting#Natural_vignetting)

## Dithering
A dithering pass for the final image. Uses triangular, blue noise.

[Some examples, courtesy of hornet on Shadertoy.](https://www.shadertoy.com/view/WldSRf)
