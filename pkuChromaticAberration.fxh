#pragma once

uniform float CaIntensity < ui_type = "slider";
ui_category = "Chromatic Aberration";
ui_label = "Intensity";
ui_min = 0f;
ui_max = 1f;
> = 0.1;

uniform bool jitter < ui_type = "input";
ui_category = "Chromatic Aberration";
ui_label = "Jitter";
ui_tooltip = "Jitter chromatic aberration samples.";
> = true;

uniform uint samples < ui_type = "slider";
ui_category = "Chromatic Aberration";
ui_label = "samples";
ui_min = 2u;
ui_max = 32u;
> = 8u;

float3 applyChromaticAberration(float2 uv, float2 viewCoord,
                                float2 viewProportions, float radius,
                                float noise) {

  float blue_radius = cos(radius * CaIntensity);
  float2 blue_center_pos = viewCoord * blue_radius;
  float2 view_range = blue_center_pos - viewCoord;
  float2 uv_delta = view_range / viewProportions / samples;
  float spectrum_delta = 1f / samples;
  float2 sample_uv = uv + uv_delta * noise;
  float spectrum_pos = spectrum_delta * noise;
  float3 filter_sum = float3(0f, 0f, 0f);
  float3 sum = float3(0f, 0f, 0f);

  for (uint i = 0; i < samples; i++) {
    float3 spectrum_filter;
    float a = min(-6f * abs(spectrum_pos - 0.5) + 3f, 1f);
    spectrum_filter.r = a * saturate(3f - 6f * spectrum_pos);
    spectrum_filter.g = saturate(2f - 6f * abs(spectrum_pos - 0.5));
    spectrum_filter.b = a * saturate(3f + 6f * (spectrum_pos - 1f));
    sum += tex2D(BackBuffer, sample_uv).rgb * spectrum_filter;
    filter_sum += spectrum_filter;
    spectrum_pos += spectrum_delta;
    sample_uv += uv_delta;
  }

  return float3(sum / filter_sum);
}