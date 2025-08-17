#pragma once

uniform float v_amount < __UNIFORM_SLIDER_FLOAT1 ui_category_closed = true;
ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
ui_category = "Vignette";
> = 0.1;

float3 applyVignette(float3 color, float radius) {
  float center_angle = atan(radius * v_amount);
  float vig = pow(cos(center_angle), 4.0);
  return color * vig;
}