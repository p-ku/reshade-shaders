#pragma once

#ifndef FOV_TYPE   // 0 for horizontal
#define FOV_TYPE 0 // 1 for vertical
#endif             // 2 for diagonal
#ifndef TEST_GRID
#define TEST_GRID 0
#endif
#ifndef PC_STEPS
#define PC_STEPS 4
#endif

uniform float screenDistance < __UNIFORM_SLIDER_FLOAT1 ui_label = "Distance";
ui_tooltip = "Physical distance from screen. Units for screen distance and "
             "screen diagonal should match.";
ui_step = 1f;
ui_min = 1f;
ui_max = 200f;
ui_category = "Perspective Correction";
> = 22f;

uniform float screenDiagonal < __UNIFORM_SLIDER_FLOAT1 ui_label = "Diagonal";
ui_tooltip = "Physical length of screen diagonal. Units for screen distance "
             "and screen diagonal should match.";
ui_step = 1f;
ui_min = 1f;
ui_max = 200f;
ui_category = "Perspective Correction";
> = 27f;

uniform uint gameFov < __UNIFORM_SLIDER_INT1 ui_category_closed = true;
ui_units = "°";
ui_label = "FOV";
ui_tooltip = "Should match in-game FOV value.";
ui_min = 35u;
ui_max = 179u;
ui_category = "Perspective Correction";
> = 75u;

uniform float zoom_factor < __UNIFORM_SLIDER_FLOAT1 ui_label = "Zoom";
ui_min = 0f;
ui_max = 2f;
ui_category = "Perspective Correction";
> = 1f;

#if TEST_GRID
uniform uint GridSize < __UNIFORM_SLIDER_INT1 ui_text = "Calibration Grid";
ui_category = "Perspective Correction";
ui_label = "Size";
ui_tooltip = "Adjust calibration grid size.";
ui_min = 2;
ui_max = 32;
ui_category = "Perspective Correction";
> = 16;

uniform uint GridThickness < __UNIFORM_SLIDER_INT1 ui_category =
    "Perspective Correction";
ui_units = " pixels";
ui_label = "Thickness";
ui_tooltip = "Adjust calibration grid bar width in pixels.";
ui_min = 2;
ui_max = 16;
> = 4;
uniform float BackgroundDim < __UNIFORM_SLIDER_FLOAT1 ui_category =
    "Perspective Correction";
ui_label = "Background dimming";
ui_tooltip = "Choose the calibration background dimming.";
ui_min = 0f;
ui_max = 1f;
ui_step = 0.01;
> = 0.5;
#endif
texture2D PCTex < pooled = true;
> {
  Width = BUFFER_WIDTH / 2;
  Height = BUFFER_HEIGHT / 2;
  Format = R32F;
};

sampler2D PCSamp { Texture = PCTex; };
static float distancePrev = 1.0;
bool checkChange() {
  if (screenDistance == distancePrev) {
    return false;
  }
  distancePrev = screenDistance;
  return true;
}
float2 getPhysicalDimensions(float2 aspect_ratio) {
  float factor = screenDiagonal / sqrt(aspect_ratio.x * aspect_ratio.x +
                                       aspect_ratio.y * aspect_ratio.y);
  return factor * aspect_ratio;
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
float3 integrateRK4(float radius, float2 aspect_ratio) {
  float h = radius / PC_STEPS;
  float r = 0;
  float3 k = float3(0, 0, 0);

#if FOV_TYPE < 2
  float2 dims = getPhysicalDimensions(aspect_ratio);
#if FOV_TYPE == 0
  float dim = dims.x;
  float omega = aspect_ratio.x;
#elif FOV_TYPE == 1
  float dim = dims.y;
  float omega = aspect_ratio.y;
#endif
#elif FOV_TYPE == 2
  float dim = screenDiagonal;
  float omega = 1.0;
#endif
  float realHalfRads = atan(0.5 * dim / screenDistance);
  float gameHalfRads = 0.5 * radians(gameFov);
  omega = omega;
  float fa = omega / tan(realHalfRads);
  float fs = zoom_factor * omega / tan(gameHalfRads);

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

float2 applyPerspectiveCorrection(float2 pos, float2 viewCoord,
                                  float2 viewProp) {
#if FOV_TYPE == 0
  float omega = viewProp.x; // Horizontal
#elif FOV_TYPE == 1
  float omega = viewProp.y; // Vertical
#elif FOV_TYPE == 2
  float omega = 1.0; // Diagonal
#endif

  float radius = length(viewCoord);

  float3 k = integrateRK4(radius, viewProp);
  float modRad = k.z / zoom_factor;

  return modRad * normalize(viewCoord) / viewProp;
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
  // viewCoord = frac(viewCoord * GridSize);

  /* Scale coordinates to pixel size for anti-aliasing of grid
     using anti-aliasing step function from research paper
     arXiv:2010.04077 [cs.GR] (2020) */
  viewCoord *= float2(rsqrt(dot(delX, delX)), rsqrt(dot(delY, delY))) /
               GridSize; // pixel density
  // Set grid with
  viewCoord = saturate(GridThickness * 0.5 - abs(viewCoord)); // clamp values
  // Apply calibration grid colors
  color =
      lerp(float3(1f, 1f, 0f), color, (1f - viewCoord.x) * (1f - viewCoord.y));
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

float PS_Texture_Gen(float4 pos : SV_POSITION, float2 uv : TEXCOORD)
    : SV_Target {

  float2 viewProp = normalize(BUFFER_SCREEN_SIZE);
  float2 viewCoord = uv * viewProp;
  float radius = length(viewCoord);

  float3 k = integrateRK4(radius, viewProp);
  return k.z / zoom_factor;
}