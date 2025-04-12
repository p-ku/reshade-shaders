#pragma once

#if BUFFER_COLOR_SPACE <= 2 // 8-bit quantization
#define QUANTIZATION_LEVEL 255u
#else // 10-bit quantization
#define QUANTIZATION_LEVEL 1023u
#endif

#define TEX_SIZE 1024u

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

uniform uint framecount < source = "framecount";
> ;

float4 triangle(const float4 noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float3 triangle(const float3 noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float2 triangle(const float2 noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float triangle(const float noise) {
  return sign(noise) * (1.0 - sqrt(1.0 - abs(noise)));
}

float4 dither(const float4 color, const uint2 pixelPos) {
  const uint2 dip = (1337 * framecount + pixelPos) % uint2(TEX_SIZE, TEX_SIZE);
  const float4 noise = triangle(2.0 * tex2Dfetch(Noise_Sampler, dip, 0) - 1.0);
  return color + (noise + 0.5) / QUANTIZATION_LEVEL;
}
