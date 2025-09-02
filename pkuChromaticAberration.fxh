#pragma once

uniform float ca_amount < ui_type = "slider";
ui_category = "Chromatic Aberration";
ui_label = "Intensity";
ui_min = 0.0;
ui_max = 1.0;
> = 0.1;

uniform bool jitter < ui_type = "input";
ui_category = "Chromatic Aberration";
ui_label = "Jitter";
ui_tooltip = "Jitter chromatic aberration samples.";
> = false;

uniform uint samples < ui_type = "slider";
ui_category = "Chromatic Aberration";
ui_label = "samples";
ui_min = 2u;
ui_max = 32u;
> = 8u;

float3 applyChromaticAberration(float2 uv, float2 viewCoord,
                                float2 viewProportions, float radius,
                                float noise) {

  float blue_radius = cos(radius * ca_amount);
  float2 blue_center_pos = viewCoord * blue_radius;
  float2 view_range = blue_center_pos - viewCoord;
  float2 uv_delta = view_range / viewProportions / samples;
  float spectrum_delta = 1.0 / samples;
  float2 sample_uv = uv + uv_delta * noise;
  float spectrum_pos = spectrum_delta * noise;
  float3 filter_sum = float3(0.0, 0.0, 0.0);
  float3 sum = float3(0.0, 0.0, 0.0);

  for (uint i = 0; i < samples; i++) {
    float3 spectrum_filter;
    float a = min(-6.0 * abs(spectrum_pos - 0.5) + 3.0, 1.0);
    spectrum_filter.r = a * saturate(3.0 - 6.0 * spectrum_pos);
    spectrum_filter.g = saturate(2.0 - 6.0 * abs(spectrum_pos - 0.5));
    spectrum_filter.b = a * saturate(3.0 + 6.0 * (spectrum_pos - 1.0));
    sum += tex2D(BackBuffer, sample_uv).rgb * spectrum_filter;
    filter_sum += spectrum_filter;
    spectrum_pos += spectrum_delta;
    sample_uv += uv_delta;
  }

  return float3(sum / filter_sum);
}