#pragma once

#if BUFFER_COLOR_SPACE <= 2 // 8-bit quantization
#define QUANTIZATION_LEVEL 255u
#else // 10-bit quantization
#define QUANTIZATION_LEVEL 1023u
#endif

#define _DITHER_TEX_SIZE 1024u
namespace pkuBlueNoise {
texture Dither_Noise_Tex < source = "pkuBlueNoise.png";
pooled = true;
> {
  Format = RGBA8;
  Width = _DITHER_TEX_SIZE;
  Height = _DITHER_TEX_SIZE;
};

sampler Dither_Noise_Sampler {
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

float4 dither(float4 color, uint2 pixelPos, float time) {
  const uint2 dip = (1337 * uint(time) + pixelPos) %
                    uint2(_DITHER_TEX_SIZE, _DITHER_TEX_SIZE);
  float4 dither_noise = 2.0 * tex2Dfetch(Dither_Noise_Sampler, dip, 0) - 1.0;
  dither_noise = triangle(dither_noise);
  color += (dither_noise + 0.5) / QUANTIZATION_LEVEL;
  return color;
}
} // namespace pkuBlueNoise