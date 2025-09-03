#pragma once

#if PERSPECTIVE_CORRECTION
uniform float VFactor < ui_type = "slider";
ui_label = "Intensity";
ui_min = 0f;
ui_max = 2f;
ui_text = "Vignette";
> = 1f;
#else
uniform float VAmount < ui_type = "slider";
ui_label = "Intensity";
ui_min = 0f;
ui_max = 1f;
ui_text = "Vignette";
> = 0.1;
#endif

float3 applyVignette(float3 color, float radius, float distance) {
#if PERSPECTIVE_CORRECTION
  float center_angle = atan((1f / VFactor) * distance / radius);
#else
  float center_angle = atan(((1f - VAmount) / VAmount) / radius);
#endif
  float cosine = cos(center_angle);
  float vig = cosine * cosine * cosine * cosine;
  return color * (1f - vig);
}