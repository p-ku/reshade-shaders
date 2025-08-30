#pragma once

#define BUFFER_SCREEN_SIZE float2(BUFFER_WIDTH, BUFFER_HEIGHT)
texture BackBufferTex : COLOR;
sampler BackBuffer { Texture = BackBufferTex; };
void pku_VS(in uint id : SV_VertexID, out float4 position : SV_Position,
            out float2 uv : TEXCOORD, out float2 viewCoord : TEXCOORD1) {
  uv.x = (id == 2) ? 2.0 : 0.0;
  uv.y = (id == 1) ? 2.0 : 0.0;
  position = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
  float2 viewProportions = normalize(BUFFER_SCREEN_SIZE);
  viewCoord = float2(position.x, -position.y) * viewProportions;
}