#pragma once

#if BUFFER_COLOR_SPACE <= 2 // 8-bit quantization
#define QUANTIZATION_LEVEL 255u
#else // 10-bit quantization
#define QUANTIZATION_LEVEL 1023u
#endif

#define TEX_SIZE 128u
uniform uint framecount < source = "framecount";
> ;

static const uint3 perms[24] = {
    uint3(0, 1, 2), uint3(1, 2, 3), uint3(2, 3, 0), uint3(3, 0, 1),
    uint3(0, 2, 3), uint3(1, 3, 0), uint3(2, 0, 1), uint3(3, 1, 2),
    uint3(0, 3, 1), uint3(1, 0, 2), uint3(2, 1, 3), uint3(3, 2, 0),
    uint3(0, 1, 3), uint3(1, 2, 0), uint3(2, 3, 1), uint3(3, 0, 2),
    uint3(0, 2, 1), uint3(1, 3, 2), uint3(2, 0, 3), uint3(3, 1, 0),
    uint3(0, 3, 2), uint3(1, 0, 3), uint3(2, 1, 0), uint3(3, 2, 1)};

texture Dither_Noise_Tex < source = "pkuBlueNoise.png";
pooled = true;
> {
  Format = RGBA8;
  Width = TEX_SIZE;
  Height = TEX_SIZE;
};

sampler Noise_Sampler {
  Texture = Dither_Noise_Tex;
  AddressU = REPEAT;
  AddressV = REPEAT;
  // Filter = POINT;
};

float4 triangle(float4 noise) {
  return sign(noise) * (1f - sqrt(1f - abs(noise)));
}

float3 triangle(float3 noise) {
  return sign(noise) * (1f - sqrt(1f - abs(noise)));
}

float2 triangle(float2 noise) {
  return sign(noise) * (1f - sqrt(1f - abs(noise)));
}

float triangle(float noise) {
  return sign(noise) * (1f - sqrt(1f - abs(noise)));
}

float3 applyDither(float3 color, uint2 pixelPos) {
  float4 noise =
      triangle(2f * tex2Dfetch(Noise_Sampler, pixelPos % TEX_SIZE) - 1f);
  uint rotation = framecount % 24;
  float channels[4] = {noise.r, noise.g, noise.b, noise.a};
  uint3 p = perms[rotation];
  float3 dither = float3(channels[p.x], channels[p.y], channels[p.z]);
  dither = (dither + 0.5) / QUANTIZATION_LEVEL;
  return saturate(color) + dither;
}