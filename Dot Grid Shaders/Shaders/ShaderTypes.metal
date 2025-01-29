#include <metal_stdlib>
using namespace metal;

struct ShaderConfig {
    float time;
    float padding1;
    float2 resolution;
    float2 patternScale;
    float4 colorA;
    float4 colorB;
    float patternSpeed;
    float dotSize;
    int patternType;
    float padding2;
    float2 touchPosition;
    float touchTime;
    float touchEndTime;
    int isMultiColored;
    float gradientSpeed;
    float padding3;
};
