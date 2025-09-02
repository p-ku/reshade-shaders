#pragma once

#if PERSPECTIVE_CORRECTION
uniform float v_factor < ui_type = "slider";
ui_label = "Intensity";
ui_min = 0.0;
ui_max = 2.0;
ui_category = "Vignette";
> = 1.0;
#else
uniform float v_amount < ui_type = "slider";
ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Vignette";
> = 0.1;
#endif

float3 applyVignette(float3 color, float radius, float distance) {
#if PERSPECTIVE_CORRECTION
  float center_angle = atan((1f / v_factor) * distance / radius);
#else
  float center_angle = atan(((1f - v_amount) / v_amount) / radius);
#endif
  float vig = pow(cos(center_angle), 4f);
  return color * (1f - vig);
}