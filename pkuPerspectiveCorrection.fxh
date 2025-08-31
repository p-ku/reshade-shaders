#pragma once

#ifndef FOV_TYPE   // 0 for horizontal
#define FOV_TYPE 0 // 1 for vertical
#endif             // 2 for diagonal
#ifndef LUT_MODE
#define LUT_MODE 1
#endif
#ifndef PC_STEPS
#define PC_STEPS 4
#endif
#ifndef TEST_GRID
#define TEST_GRID 0
#endif

uniform float screenDistance < ui_type = "slider";
ui_label = "Distance";
ui_tooltip = "Physical distance from screen. Units for screen distance and "
             "screen diagonal should match.";
ui_step = 1f;
ui_min = 1f;
ui_max = 200f;
ui_category = "Perspective Correction";
> = 22f;

uniform float screenDiagonal < ui_type = "slider";
ui_label = "Diagonal";
ui_tooltip = "Physical length of screen diagonal. Units for screen distance "
             "and screen diagonal should match.";
ui_step = 1f;
ui_min = 1f;
ui_max = 200f;
ui_category = "Perspective Correction";
> = 27f;

uniform uint gameFov < ui_type = "slider";
ui_category_closed = true;
ui_units = "°";
ui_label = "FOV";
ui_tooltip = "Should match in-game FOV value.";
ui_min = 1u;
ui_max = 160u;
ui_category = "Perspective Correction";
> = 75u;

uniform float zoom_factor < ui_type = "slider";
ui_label = "Zoom";
ui_min = 0.5;
ui_max = 2f;
ui_category = "Perspective Correction";
> = 1f;

#if TEST_GRID
uniform uint GridSize < ui_type = "slider";
ui_text = "Calibration Grid";
ui_category = "Perspective Correction";
ui_label = "Size";
ui_tooltip = "Adjust calibration grid size.";
ui_min = 2;
ui_max = 32;
ui_category = "Perspective Correction";
> = 16;

uniform uint GridThickness < ui_type = "slider";
ui_category = "Perspective Correction";
ui_units = " pixels";
ui_label = "Thickness";
ui_tooltip = "Adjust calibration grid bar width in pixels.";
ui_min = 2;
ui_max = 16;
> = 4;

uniform float BackgroundDim < ui_type = "slider";
ui_category = "Perspective Correction";
ui_label = "Background dimming";
ui_tooltip = "Choose the calibration background dimming.";
ui_min = 0f;
ui_max = 1f;
ui_step = 0.01;
> = 0.5;
#endif

#if LUT_MODE
#ifndef DX9_MODE
#define DX9_MODE 0
#endif
#define LUT_SIZE 128
texture2D PCTex < pooled = true;
> {
  Width = LUT_SIZE;
  Height = LUT_SIZE;
  Format = R32F;
};

sampler2D PCSamp { Texture = PCTex; };
#endif
float getPhysicalDimension(float2 aspect_ratio) {
#if FOV_TYPE < 2
  float factor = screenDiagonal / sqrt(aspect_ratio.x * aspect_ratio.x +
                                       aspect_ratio.y * aspect_ratio.y);
  float2 dims = factor * aspect_ratio;
#if FOV_TYPE == 0
  return dims.x;
#elif FOV_TYPE == 1
  return dims.y;
#endif
#elif FOV_TYPE == 2
  return screenDiagonal;
#endif
}
///* Linear pixel step function for anti-aliasing by Jakub Max Fober.
//   This algorithm is part of scientific paper:
//  � arXiv:2010.04077 [cs.GR] (2020) */
float aastep(float grad) {
  // Differential vector
  float2 Del = float2(ddx(grad), ddy(grad));
  // Gradient normalization to pixel size, centered at the step edge
  return saturate(mad(rsqrt(dot(Del, Del)), grad, 0.5)); // half-pixel offset
}

// Border mask shader
float GetBorderMask(float2 borderCoord) {
  // Get coordinates for each corner
  borderCoord = abs(borderCoord);

  return aastep(max(borderCoord.x, borderCoord.y) - 1f);
}

//  The vector field:  dk/dr = f(k, r)
float3 field(float3 k, float r, float fa, float fs) {
  float x = k.x, y = k.y, s = k.z;
  float q = fa - y;
  float A = fs * x - s * q;
  float B = s * x + fs * q;
  float C = sqrt(A * A + B * B);
  float dxdr = q * q * B / (fa * (B * q + x * A));    // dx/dr
  float dydr = q * q * A / (fa * (B * q + x * A));    // dy/dr
  float dsdr = q * q * C / (fa * B * q + fa * x * A); // ds/dr
  return float3(dxdr, dydr, dsdr);
}

//  A simple in‐shader RK4
float3 integrateRK4(float radius, float2 aspect_ratio, float fa, float fs) {
  float h = radius / PC_STEPS;
  float r = 0;
  float3 k = float3(0, 0, 0);

  for (int i = 0; i < PC_STEPS; i++) {
    float3 k1 = field(k, r, fa, fs);
    float3 k2 = field(k + 0.5 * h * k1, r + 0.5 * h, fa, fs);
    float3 k3 = field(k + 0.5 * h * k2, r + 0.5 * h, fa, fs);
    float3 k4 = field(k + h * k3, r + h, fa, fs);

    k += (h / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4);
    r += h;
  }
  return k;
}
float getOmega(float2 viewProp) {
#if FOV_TYPE == 0
  return viewProp.x;
#elif FOV_TYPE == 1
  return viewProp.y;
#elif FOV_TYPE == 2
  return 1.0;
#endif }

  float getFs(float omega) {
    float gameHalfRads = 0.5 * radians(gameFov);
    return zoom_factor * omega / tan(gameHalfRads);
  }
  float getFa(float omega, float2 viewProp) {
    float dim = getPhysicalDimension(viewProp);
    float realHalfRads = atan(0.5 * dim / screenDistance);
    return omega / tan(realHalfRads);
  }
  float calculateCorrection(float radius, float2 viewProp, float omega,
                            float fs) {
    float fa = getFa(omega, viewProp);
    float3 k = integrateRK4(radius, viewProp, fa, fs);
    return k.z;
  }
  float applyPerspectiveCorrection(float2 pos, float radius, float2 viewProp,
                                   out float fs) {
    float omega = getOmega(viewProp);
    fs = getFs(omega);
#if LUT_MODE
    float total_pixels = LUT_SIZE * LUT_SIZE;
    float pixel_index = radius * (total_pixels - 1f);
    float row = floor(pixel_index / LUT_SIZE);
    float column = pixel_index - (row * LUT_SIZE);
    float u = (column + 0.5) / LUT_SIZE;
    float v = (row + 0.5) / LUT_SIZE;
    return tex2D(PCSamp, float2(u, v)).r;
#else
    return calculateCorrection(radius, viewProp, omega, fs);
#endif
  }

#if TEST_GRID
  float3 GridModeViewPass(float3 color, float2 viewCoord) {
    // Dim calibration background
    color = saturate(color * (1f - BackgroundDim));
    // Get coordinates pixel size
    float2 delX = float2(ddx(viewCoord.x), ddy(viewCoord.x));
    float2 delY = float2(ddx(viewCoord.y), ddy(viewCoord.y));
    // Scale coordinates to grid size and center
    viewCoord = frac(viewCoord * GridSize) - 0.5;

    /* Scale coordinates to pixel size for anti-aliasing of grid
       using anti-aliasing step function from research paper
       arXiv:2010.04077 [cs.GR] (2020) */
    viewCoord *= float2(rsqrt(dot(delX, delX)), rsqrt(dot(delY, delY))) /
                 GridSize; // pixel density
    // Set grid with
    viewCoord = saturate(GridThickness * 0.5 - abs(viewCoord)); // clamp values
    // Apply calibration grid colors
    color = lerp(float3(1f, 1f, 0f), color,
                 (1f - viewCoord.x) * (1f - viewCoord.y));
    if ((1f - viewCoord.x) * (1f - viewCoord.y) < 0f) {
      return float3(1f, 0f, 0f);
    }
    return color; // background picture with grid superimposed over it
  }
#endif
  float3 applyBorder(float3 color, float2 viewCoordDistort) {
    // Outside border mask with anti-aliasing
    float2 absDistort = abs(viewCoordDistort);

    float borderMask = GetBorderMask(viewCoordDistort);
    return lerp(color, float3(0f, 0f, 0f), borderMask);
  }
#if LUT_MODE
  float PS_Texture_Gen(float4 pos : SV_POSITION, float2 uv : TEXCOORD)
      : SV_Target {
    float2 viewProp = normalize(BUFFER_SCREEN_SIZE);
#if DX9_MODE
    float radius = (pos.y + pos.x / (LUT_SIZE - 1f)) / LUT_SIZE;
#else
    float radius = (-0.5f + pos.y + pos.x / (LUT_SIZE - 1f)) / LUT_SIZE;
#endif
    float omega = getOmega(viewProp);
    float fs = getFs(omega);
    return calculateCorrection(radius, viewProp, omega, fs);
  }
  technique CreateCorrectionLUT {
    pass {
      VertexShader = pku_VS; // the included fullscreen‐quad VS
      PixelShader = PS_Texture_Gen;
      RenderTarget = PCTex; // render into texTarget
    }
  }
#endif