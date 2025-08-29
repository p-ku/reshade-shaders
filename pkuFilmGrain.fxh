#pragma once

uniform float grain_amount < __UNIFORM_SLIDER_FLOAT1 ui_category_closed = true;
ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Film Grain";
> = 0.1;
static const float3 _LUMA_COEF = float3(0.2126, 0.7152, 0.0722);

float3 applyFilmGrain(float3 color, float noise) {
  float luma = dot(color, _LUMA_COEF);
  float luma_factor = max(grain_amount * (luma - luma * luma), 0.0);
  // add noise to luma
  float new_luma = luma + luma_factor * noise;
  return color * new_luma / luma;
}