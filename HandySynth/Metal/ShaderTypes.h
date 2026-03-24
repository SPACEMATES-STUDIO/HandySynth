#pragma once
#include <simd/simd.h>

typedef struct {
    float time;
    uint32_t bandCount;
    vector_float2 viewportSize;
    vector_float4 colorPrimary;
    vector_float4 colorSecondary;
    float energy;
    float _pad0;
    float _pad1;
    float _pad2;
} VisualizerUniforms;

typedef struct {
    float spectrumHeight;
    float spacing;
    float _pad0;
    float _pad1;
} TerrainUniforms;
