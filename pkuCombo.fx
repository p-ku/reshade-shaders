#include "pku.fxh"
#include "pkuDither.fxh"
#ifndef PERSPECTIVE_CORRECTION
#define PERSPECTIVE_CORRECTION 1
#endif
#if PERSPECTIVE_CORRECTION
#include "pkuPerspectiveCorrection.fxh"
#endif
#ifndef CHROMATIC_ABERRATION
#define CHROMATIC_ABERRATION 0
#endif
#if CHROMATIC_ABERRATION
#include "pkuChromaticAberration.fxh"
#endif
#ifndef VIGNETTE
#define VIGNETTE 0
#endif
#if VIGNETTE
#include "pkuVignette.fxh"
#endif
#ifndef FILM_GRAIN
#define FILM_GRAIN 0
#endif
#if FILM_GRAIN
#include "pkuFilmGrain.fxh"
#endif

#if CHROMATIC_ABERRATION | FILM_GRAIN
uniform float timer < source = "timer";
> ;

float nrand(float2 seed) {
  return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}
#endif

float3 PS_Effects(float4 pos : SV_Position, float2 uv : TEXCOORD0,
                  float2 viewCoord : TEXCOORD1)
    : SV_Target {
#if PERSPECTIVE_CORRECTION | CHROMATIC_ABERRATION | VIGNETTE
  float2 viewProp = normalize(BUFFER_SCREEN_SIZE);
  float radius = length(viewCoord);
#endif
  float fs = 0f;
#if PERSPECTIVE_CORRECTION
  float modRad =
      applyPerspectiveCorrection(pos.xy, radius / ZoomFactor, viewProp, fs);
  float2 viewCoordDistort = modRad * normalize(viewCoord) / viewProp;
  float2 uv_distort = 0.5f * viewCoordDistort + 0.5f;
#endif
#if CHROMATIC_ABERRATION | FILM_GRAIN
  float seconds = timer * 0.001;
#endif

#if CHROMATIC_ABERRATION
  float white_noise = 0.5;

  if (jitter) {
    white_noise = nrand(uv + frac(seconds));
  }
#if PERSPECTIVE_CORRECTION
  float3 display = applyChromaticAberration(uv_distort, viewCoord, viewProp,
                                            radius, white_noise);
#else
  float3 display =
      applyChromaticAberration(uv, viewCoord, viewProp, radius, white_noise);
#endif

#elif PERSPECTIVE_CORRECTION
  float3 display = tex2D(BackBuffer, uv_distort).rgb;
#else
  float3 display = tex2Dfetch(BackBuffer, pos.xy).rgb;
#endif

#if VIGNETTE
  display = applyVignette(display, radius, fs);
#endif

#if FILM_GRAIN
  float film_noise = triangle(nrand(uv + frac(seconds + 0.5)) * 2f - 1f);
  display = applyFilmGrain(display, film_noise);
#endif

#if PERSPECTIVE_CORRECTION
#if TEST_GRID
  display = GridModeViewPass(display, viewCoordDistort * viewProp);
#endif
  display = applyBorder(display, viewCoordDistort);
#endif
  return applyDither(display, uint2(pos.xy));
}
technique pkuFX {
#if LIVE_LUT
  pass {
    VertexShader = pku_VS; // the included fullscreen‐quad VS
    PixelShader = PS_Texture_Gen;
    RenderTarget = PCTex; // render into texTarget
  }
#endif
  pass {
    VertexShader = pku_VS;
    PixelShader = PS_Effects;
  }
}