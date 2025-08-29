#pragma once

uniform float v_amount < __UNIFORM_SLIDER_FLOAT1 ui_category_closed = true;
ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Vignette";
> = 0.1;

float3 applyVignette(float3 color, float radius, float distance) {
#if PERSPECTIVE_CORRECTION
  float center_angle = atan(distance / radius / v_amount);
#else
  float center_angle = atan((1f - distance) / radius);
#endif
  float vig = pow(cos(center_angle), 4f);
  return color * (1f - vig);
}