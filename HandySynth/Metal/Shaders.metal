#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    uint   barIndex;
};

// MARK: - Terrain Shaders

vertex VertexOut terrainVertex(
    uint                        vertexID   [[ vertex_id ]],
    constant float             *history   [[ buffer(0) ]],
    constant VisualizerUniforms &uni       [[ buffer(1) ]],
    constant uint              &histCount  [[ buffer(2) ]],
    constant TerrainUniforms   &terrainUni [[ buffer(3) ]])
{
    const float X_HALF = 0.95;
    uint bandCount   = uni.bandCount;
    uint vertsPerType = (bandCount - 1) * 6;
    uint vertsPerRow  = vertsPerType * 2;

    uint rowIdx   = vertexID / vertsPerRow;
    uint typeIdx  = (vertexID % vertsPerRow) / vertsPerType;
    uint quadIdx  = (vertexID % vertsPerType) / 6;
    uint localIdx = vertexID % 6;

    float t = float(rowIdx) / float(histCount - 1);

    float spacingScale = terrainUni.spacing / 20.0;
    float heightScale  = terrainUni.spectrumHeight / 770.0;

    float y_base  = mix(0.80, -0.78, t) * spacingScale;
    float x_scale = mix(0.45, 1.00,  t);
    float amp     = mix(0.18, 0.68,  t) * heightScale;

    float xStep = 2.0 * X_HALF / float(bandCount - 1);
    float xL = (-X_HALF + float(quadIdx)     * xStep) * x_scale;
    float xR = (-X_HALF + float(quadIdx + 1) * xStep) * x_scale;
    float yTL = y_base + clamp(history[rowIdx * bandCount + quadIdx],     0.0, 1.0) * amp;
    float yTR = y_base + clamp(history[rowIdx * bandCount + quadIdx + 1], 0.0, 1.0) * amp;

    float2 pos;
    float2 uv;

    if (typeIdx == 0) {
        float2 corners[6] = {
            float2(xL, yTL),
            float2(xR, yTR),
            float2(xL, -1.0),
            float2(xL, -1.0),
            float2(xR, yTR),
            float2(xR, -1.0)
        };
        pos = corners[localIdx];
        uv  = float2(0.0, t);
    } else {
        float lineH = 0.007 * mix(0.6, 1.0, t);
        float2 corners[6] = {
            float2(xL, yTL + lineH),
            float2(xR, yTR + lineH),
            float2(xL, yTL),
            float2(xL, yTL),
            float2(xR, yTR + lineH),
            float2(xR, yTR)
        };
        pos = corners[localIdx];
        uv  = float2(1.0, t);
    }

    VertexOut out;
    out.position = float4(pos, 0.0, 1.0);
    out.uv       = uv;
    out.barIndex = quadIdx;
    return out;
}

fragment float4 terrainFragment(
    VertexOut                   in  [[stage_in]],
    constant float             *history [[ buffer(0) ]],
    constant VisualizerUniforms &uni    [[ buffer(1) ]])
{
    if (in.uv.x < 0.5) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    float t = in.uv.y;
    float4 color = mix(uni.colorSecondary, uni.colorPrimary, t);
    color.a = mix(0.2, 1.0, t);

    float shimmer = 1.0 + 0.06 * sin(uni.time * 4.0 + float(in.barIndex) * 0.25);
    color.rgb *= shimmer;

    return color;
}
