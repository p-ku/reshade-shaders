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

#if PERSPECTIVE_CORRECTION
#ifndef FOV_TYPE   // 0 for horizontal
#define FOV_TYPE 0 // 1 for vertical
#endif             // 2 for diagonal
uniform uint gameFov < __UNIFORM_SLIDER_INT1 ui_category_closed = true;
ui_units = "°";
ui_label = "In-game FOV";
ui_tooltip = "Should match in-game FOV value.";
ui_min = 15u;
ui_max = 135u;
> = 70u;

uniform uint realFov < __UNIFORM_SLIDER_INT1 ui_category_closed = true;
ui_units = "°";
ui_label = "Actual FOV";
ui_tooltip = "Should match real-world field of view";
ui_min = 15u;
ui_max = 135u;
> = 57u;

uniform float CropFactor < __UNIFORM_SLIDER_FLOAT1 ui_label = "Crop";
ui_min = 1f;
ui_max = 2f;
ui_step = 0.001;
> = 1.015;

float correctPerspective(const float radius, const float omega) {
  const float gameRads = radians(gameFov);
  const float realRads = radians(realFov);
  const float fScreen = omega / tan(gameRads * 0.5);
  const float fActual = omega / tan(realRads * 0.5) / CropFactor;
  const float rc = 1 / (1 / fScreen - 1 / fActual);
  const float arc = radius / rc;          // half arc
  const float ch = rc * sin(radius / rc); // half chord length
  const float sag = rc - sqrt(rc * rc - ch * ch);
  return fActual * ch / (sag + fActual);
}

///* Linear pixel step function for anti-aliasing by Jakub Max Fober.
//   This algorithm is part of scientific paper:
//  · arXiv:2010.04077 [cs.GR] (2020) */
float aastep(const float grad) {
  // Differential vector
  const float2 Del = float2(ddx(grad), ddy(grad));
  // Gradient normalization to pixel size, centered at the step edge
  return saturate(mad(rsqrt(dot(Del, Del)), grad, 0.5)); // half-pixel offset
}

// Border mask shader
float GetBorderMask(float2 borderCoord, const float maxx) {
  // Get coordinates for each corner
  borderCoord = abs(borderCoord);
  return aastep(max(borderCoord.x, borderCoord.y) - 1f);
}
#endif

#if CHROMATIC_ABERRATION
#ifndef CA_SAMPLES
#define CA_SAMPLES 8
#endif
#ifndef CA_JITTER // Jitters chromatic aberration samples
#define CA_JITTER 1
#endif
#ifndef CA_VIA_FOV   // Uses the result from perspective
#define CA_VIA_FOV 1 // correction for chromatic aberration
#endif
uniform float ca_amount < __UNIFORM_SLIDER_FLOAT1 ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Chromatic Aberration";
> = 0.1;
#endif

#if VIGNETTE
uniform float v_amount < __UNIFORM_SLIDER_FLOAT1 ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Vignette";
> = 0.1;
#endif

#if FILM_GRAIN
uniform float grain_amount < __UNIFORM_SLIDER_FLOAT1 ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Film Grain";
> = 0.1;
static const float3 _LUMA_COEF = float3(0.2126, 0.7152, 0.0722);
#endif

#if CHROMATIC_ABERRATION | FILM_GRAIN
uniform float timer < source = "timer";
> ;

float nrand(const float2 seed) {
  return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}
#endif

void pku_VS(in uint id : SV_VertexID, out float4 position : SV_Position,
            out float2 uv : TEXCOORD, out float2 viewCoord : TEXCOORD1) {
  uv.x = (id == 2) ? 2.0 : 0.0;
  uv.y = (id == 1) ? 2.0 : 0.0;
  position = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
  const float2 viewProportions = normalize(BUFFER_SCREEN_SIZE);
  viewCoord = float2(position.x, -position.y) * viewProportions;
}

float4 pku_PS(float4 pixelPos : SV_Position, float2 uv : TEXCOORD0,
              float2 viewCoord : TEXCOORD1)
    : SV_Target {
#if PERSPECTIVE_CORRECTION | CHROMATIC_ABERRATION | VIGNETTE
  const float2 viewProportions = normalize(BUFFER_SCREEN_SIZE);
#if PERSPECTIVE_CORRECTION
  viewCoord.xy /= CropFactor;
#if FOV_TYPE == 0
  const float omega = viewProportions.x; // Horizontal
#elif FOV_TYPE == 1
  const float omega = viewProportions.y; // Vertical
#elif FOV_TYPE == 2
  const float omega = 1.0; // Diagonal
#endif
#endif
  const float radius = length(viewCoord.xy);
#endif

#if PERSPECTIVE_CORRECTION
  const float xr = correctPerspective(radius, omega);
  const float2 pCoord = viewCoord.xy / (xr / radius) / viewProportions;
  const float2 uv_distort = 0.5 + 0.5 * pCoord;
#endif
#if CHROMATIC_ABERRATION | FILM_GRAIN
  const float seconds = timer * 0.001;
#endif

#if CHROMATIC_ABERRATION
// determine how far to blur
#if PERSPECTIVE_CORRECTION & CA_VIA_FOV
  const float2 croppedUv = 0.5 + (uv - 0.5) / CropFactor;
  const float2 uv_range = croppedUv - uv_distort;
  const float2 uv_delta = ca_amount * uv_range / CA_SAMPLES;
#else
  const float blue_radius = cos(radius * ca_amount);
  const float2 blue_center_pos = viewCoord * blue_radius;
  const float2 view_range = blue_center_pos - viewCoord;
  const float2 uv_delta = view_range / viewProportions / CA_SAMPLES;
#endif
  const float spectrum_delta = 1.0 / CA_SAMPLES;

// Jitter
#if CA_JITTER
  const float white_noise = nrand(uv + frac(seconds));
#else
  const float white_noise = 0.5;
#endif
#if PERSPECTIVE_CORRECTION
  float2 sample_uv = uv_distort + uv_delta * white_noise;
#else
  float2 sample_uv = uv + uv_delta * white_noise;
#endif
  float spectrum_pos = spectrum_delta * white_noise;
  float3 filter_sum = float3(0.0, 0.0, 0.0);
  float3 sum = float3(0.0, 0.0, 0.0);

  // sample away
  for (uint i = 0; i < CA_SAMPLES; i++) {
    float3 spectrum_filter;
    const float a = min(-6.0 * abs(spectrum_pos - 0.5) + 3.0, 1.0);
    spectrum_filter.r = a * clamp(3.0 - 6.0 * spectrum_pos, 0.0, 1.0);
    spectrum_filter.g = clamp(2.0 - 6.0 * abs(spectrum_pos - 0.5), 0.0, 1.0);
    spectrum_filter.b = a * clamp(3.0 + 6.0 * (spectrum_pos - 1.0), 0.0, 1.0);
    sum += tex2D(ReShade::BackBuffer, sample_uv).rgb * spectrum_filter;
    filter_sum += spectrum_filter;
    spectrum_pos += spectrum_delta;
    sample_uv += uv_delta;
  }

  float4 display = float4(sum / filter_sum, 1);
#elif PERSPECTIVE_CORRECTION
  float4 display = tex2D(ReShade::BackBuffer, uv_distort);
#else
  float4 display = tex2Dfetch(ReShade::BackBuffer, pixelPos.xy);
#endif

#if VIGNETTE
#if PERSPECTIVE_CORRECTION
  const float center_angle = atan(radius * CropFactor * v_amount);
#else
  const float center_angle = atan(radius * v_amount);
#endif
  const float vig = pow(cos(center_angle), 4.0);
  display.rgb *= vig;
#endif

#if FILM_GRAIN
  const float luma = dot(display.rgb, _LUMA_COEF);
  const float luma_factor = max(grain_amount * (luma - luma * luma), 0.0);
  // add noise to luma
  const float noise = triangle(2.0 * nrand(uv + frac(seconds + 0.5)) - 1.0);
  const float new_luma = luma + luma_factor * noise;
  display.rgb = display.rgb * new_luma / luma;
#endif

#if PERSPECTIVE_CORRECTION
  // Get border image
  const float4 border = float4(0, 0, 0, 1);
  // Outside border mask with anti-aliasing
  const float borderMask = GetBorderMask(pCoord, 0);
  display = lerp(display, border, borderMask);
#endif
  // DITHER
  display = dither(display, uint2(pixelPos.xy));
  return display;
}

technique pku {
  pass {
    VertexShader = pku_VS;
    PixelShader = pku_PS;
  }
}
