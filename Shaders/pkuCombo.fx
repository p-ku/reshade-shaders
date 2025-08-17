#include "ReShade.fxh"
#include "ReShadeUI.fxh"
#include "pkuDither.fxh"
#ifndef PERSPECTIVE_CORRECTION
#define PERSPECTIVE_CORRECTION 1
#endif
#ifndef CHROMATIC_ABERRATION
#define CHROMATIC_ABERRATION 1
#endif
#ifndef VIGNETTE
#define VIGNETTE 1
#endif
#ifndef FILM_GRAIN
#define FILM_GRAIN 1
#endif
#if CHROMATIC_ABERRATION
#include "pkuChromaticAberration.fxh"
#endif
#if VIGNETTE
#include "pkuVignette.fxh"
#endif
#if FILM_GRAIN
#include "pkuFilmGrain.fxh"
#endif
#if PERSPECTIVE_CORRECTION
#include "pkuPerspectiveCorrection.fxh"
#endif
#if CHROMATIC_ABERRATION | FILM_GRAIN
uniform float timer < source = "timer";
> ;

float nrand(float2 seed) {
  return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}
#endif
void pku_VS(in uint id : SV_VertexID, out float4 position : SV_Position,
            out float2 uv : TEXCOORD, out float2 viewCoord : TEXCOORD1) {
  uv.x = (id == 2) ? 2.0 : 0.0;
  uv.y = (id == 1) ? 2.0 : 0.0;
  position = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
  float2 viewProportions = normalize(BUFFER_SCREEN_SIZE);
  viewCoord = float2(position.x, -position.y) * viewProportions;
}

float4 PS_Effects(float4 pos : SV_Position, float2 uv : TEXCOORD0,
                  float2 viewCoord : TEXCOORD1)
    : SV_Target {
#if PERSPECTIVE_CORRECTION | CHROMATIC_ABERRATION | VIGNETTE
  float2 viewProp = normalize(BUFFER_SCREEN_SIZE);
  float radius = length(viewCoord);
#endif

#if PERSPECTIVE_CORRECTION
  float2 viewCoordDistort =
      applyPerspectiveCorrection(pos.xy, viewCoord, viewProp);
  float2 uv_distort = 0.5f * (1f + viewCoordDistort);
#endif
#if CHROMATIC_ABERRATION | FILM_GRAIN
  float seconds = timer * 0.001;
#endif

#if CHROMATIC_ABERRATION
#if CA_JITTER
  float white_noise = nrand(uv + frac(seconds));
#else
  float white_noise = 0.5;
#endif
#if PERSPECTIVE_CORRECTION
  float3 display = applyChromaticAberration(uv_distort, viewCoord, viewProp,
                                            radius, white_noise);
#else
  float3 display =
      applyChromaticAberration(uv, viewCoord, viewProp, radius, white_noise);
#endif

#elif PERSPECTIVE_CORRECTION
  float3 display = tex2D(ReShade::BackBuffer, uv_distort);
#else
  float3 display = tex2Dfetch(ReShade::BackBuffer, pos.xy);
#endif

#if VIGNETTE
  display = applyVignette(display, radius);
#endif

#if FILM_GRAIN
  float film_noise = triangle(2.0 * nrand(uv + frac(seconds + 0.5)) - 1.0);
  display = applyFilmGrain(display, film_noise);
#endif

#if PERSPECTIVE_CORRECTION
#if TEST_GRID
  display = GridModeViewPass(display, viewCoordDistort * viewProp);
#endif
  display = applyBorder(display, viewCoordDistort);
//  if (viewCoordDistort.x == 1.0)
//  display = float3(0f, 1f, 0f);
#endif
  return dither(float4(display, 1.0), uint2(pos.xy));
}

technique UseTexture {
  // #if PERSPECTIVE_CORRECTION
  //   pass {
  //     VertexShader = PostProcessVS; // the included fullscreen‐quad VS
  //     PixelShader = PS_Texture_Gen;
  //     RenderTarget = PCTex; // render into texTarget
  //   }
  // #endif
  pass {
    VertexShader = pku_VS;
    PixelShader = PS_Effects;
  }
}