#pragma once

#if BUFFER_COLOR_SPACE <= 2 // 8-bit quantization
#define QUANTIZATION_LEVEL 255u
#else // 10-bit quantization
#define QUANTIZATION_LEVEL 1023u
#endif

#define TEX_SIZE 128u
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

uint hash(uint x) {
  x ^= x >> 17;
  x *= 0xed5ad4bbU;
  x ^= x >> 11;
  x *= 0xac4c1b51U;
  x ^= x >> 15;
  x *= 0x31848babU;
  x ^= x >> 14;
  return x;
}

uint2 hash2D(uint x) { return uint2(hash(x), hash(x + 42)); }

float3 applyDither(float3 color, uint2 pixelPos) {
  uint2 dip = (hash2D(framecount) + pixelPos) % TEX_SIZE;
  const float4 noise = triangle(2f * tex2Dfetch(Noise_Sampler, dip, 0) - 1f);
  return color + (noise + 0.5) / 1f;
}