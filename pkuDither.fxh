#pragma once

#if BUFFER_COLOR_SPACE <= 2 // 8-bit quantization
#define QUANTIZATION_LEVEL 255u
#else // 10-bit quantization
#define QUANTIZATION_LEVEL 1023u
#endif

#define TEX_SIZE 64u
uniform uint framecount < source = "framecount";
> ;

texture2D Dither_Noise_Tex < source = "pkuBlueNoise.png";
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
  uint2 dip = (pixelPos + framecount * uint2(43, 17)) % TEX_SIZE;
  float4 noise = triangle(tex2Dfetch(Noise_Sampler, dip) * 2f - 1f);
  return color + (noise + 0.5) / QUANTIZATION_LEVEL;
}