#pragma once

#if BUFFER_COLOR_SPACE <= 2 // 8-bit quantization
#define QUANTIZATION_LEVEL 255u
#else // 10-bit quantization
#define QUANTIZATION_LEVEL 1023u
#endif

#define TEX_SIZE 1024u
uniform uint framecount < source = "framecount";
> ;

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
};

float4 triangle(float4 noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float3 triangle(float3 noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float2 triangle(float2 noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float triangle(float noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float4 dither(float4 color, uint2 pixelPos) {
  uint2 dip = 1225 * (framecount % TEX_SIZE) + pixelPos;
  float4 noise = triangle(2.0 * tex2Dfetch(Noise_Sampler, dip, 0) - 1.0);
  return color + (noise + 0.5) / QUANTIZATION_LEVEL;
}