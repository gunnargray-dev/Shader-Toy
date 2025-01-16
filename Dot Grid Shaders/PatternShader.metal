#include <metal_stdlib>
using namespace metal;

struct ShaderConfig {
    float time;
    float2 resolution;
    float2 patternScale;
    float4 colorA;
    float4 colorB;
    float patternSpeed;
    float dotSize;
    int32_t patternType;
    float2 touchPosition;
    float touchTime;
    float padding; // Add padding to ensure 16-byte alignment
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut pattern_vertex(uint vertexID [[vertex_id]]) {
    const float2 vertices[] = {
        float2(-1, -1),
        float2(-1,  1),
        float2( 1, -1),
        float2( 1,  1)
    };
    
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.uv = (vertices[vertexID] + 1.0) * 0.5;
    return out;
}

float verticalWavePattern(float2 uv, float2 grid, float time, float speed, float dotSize) {
    float2 gridPos = fract(uv * grid);
    float2 center = gridPos - 0.5;
    float dots = length(center * 2.0);
    
    float wave = sin(uv.y * 3.14159 + time * speed) * 0.5 + 0.5;
    float dynamicDotSize = mix(dotSize * 0.5, dotSize * 1.5, wave);
    return smoothstep(dynamicDotSize, dynamicDotSize - 0.01, dots);
}

float circularWavePattern(float2 uv, float2 grid, float time, float speed, float dotSize, float2 resolution) {
    // Create the basic dot grid
    float2 gridPos = fract(uv * grid);
    float2 center = gridPos - 0.5;
    float dots = length(center * 2.0);
    
    // Calculate the wave center and distance with separate x,y control
    float2 centerOffset = float2(0.4, 0.5); // Control x,y center position separately
    float2 screenCenter = uv - centerOffset;
    float distFromCenter = length(screenCenter * 2.0) * 4.0;
    
    // Create the wave animation
    float wave = sin(distFromCenter - time * speed) * 0.5 + 0.5;
    
    // Control dot sizes
    float dynamicDotSize = mix(dotSize * 0.4, dotSize * 2, wave);
    
    return smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
}

float ripplePattern(float2 uv, float2 grid, float time, float speed, float dotSize, float2 resolution) {
    // Create the basic dot grid
    float2 gridPos = fract(uv * grid);
    float2 center = gridPos - 0.5;
    float dots = length(center * 2.0);
    
    // Calculate screen position relative to center
    float2 centerOffset = float2(0.4, 0.5);
    float2 pos = uv - centerOffset;
    float dist = length(pos * 2.0);
    
    // Create ripple effect
    float ripple = sin((dist * 4.0 - time * speed) * 3.14159) / (1.0 + dist * 3.0);
    float wave = ripple * 0.5 + 0.5;
    
    // Control dot sizes with distance-based attenuation
    float dynamicDotSize = mix(dotSize * 0.4, dotSize * 2, wave);
    
    return smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
}

float noise21(float2 p) {
    float3 a = fract(float3(p.xyx) * float3(213.897, 653.453, 253.098));
    a += dot(a, a.yzx + 79.76);
    return fract((a.x + a.y) * a.z);
}

// Improved noise function for smoother results
float smoothNoise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    
    // Cubic smoothing
    float2 u = f * f * (3.0 - 2.0 * f);
    
    // Mix 4 corners
    float a = noise21(i);
    float b = noise21(i + float2(1.0, 0.0));
    float c = noise21(i + float2(0.0, 1.0));
    float d = noise21(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, u.x),
              mix(c, d, u.x), u.y);
}

float touchRipple(float2 uv, float2 touchPos, float touchTime, float touchEndTime, float speed) {
    if (touchPos.x < 0 || touchPos.y < 0) return 0.0;
    
    float2 delta = uv - touchPos;
    float dist = length(delta);
    
    // Constants for ripple animation
    float duration = 1.5;
    float maxRadius = 0.8;
    float waveCount = 2.0;
    
    // Create continuous ripple during drag
    float dragRipple = smoothstep(0.2, 0.0, dist) * 0.5; // Constant ripple around touch point
    
    // Calculate expanding ripple phase
    float progress = touchTime / duration;
    float currentRadius = progress * maxRadius;
    float phase = (dist - currentRadius) * 6.28318 * waveCount;
    
    // Create more pronounced wave
    float wave = sin(phase) * 0.5 + 0.5;
    wave = pow(wave, 0.7);
    
    // Fade based on time and distance
    float timeFade = smoothstep(1.0, 0.0, progress);
    float distanceFade = smoothstep(currentRadius + 0.05, currentRadius - 0.05, dist);
    
    // Combine both ripple effects
    float expandingRipple = wave * timeFade * distanceFade * 1.5;
    return max(expandingRipple, dragRipple); // Use stronger of the two effects
}

// Modify existing pattern functions to include touch ripple
float noisePattern(float2 uv, float2 grid, float time, float speed, float dotSize, float2 resolution, float2 touchPos, float touchTime, float touchEndTime) {
    // Create base dot grid
    float2 gridPos = fract(uv * grid);
    float2 center = gridPos - 0.5;
    float dots = length(center * 2.0);
    float basePattern = smoothstep(dotSize, dotSize - 0.005, dots);
    
    // Create animated noise layers with increased speeds
    float2 movement1 = float2(time * speed * 0.15, time * speed * 0.1);
    float2 movement2 = float2(time * speed * -0.12, time * speed * 0.18);
    
    // Layer 1: Smaller scale movement
    float noise1 = smoothNoise((uv + movement1) * 5);
    // Layer 2: Different direction and smaller scale
    float noise2 = smoothNoise((uv + movement2) * 5);
    
    // Combine noise layers
    float combinedNoise = mix(noise1, noise2, 0.5);
    
    // Create smooth mask with wider range
    float mask = smoothstep(0.3, 0.7, combinedNoise);
    
    // Add touch ripple
    float ripple = touchRipple(uv, touchPos, touchTime, touchEndTime, speed);
    
    // Blend with existing pattern
    return basePattern * (mask * 0.8 + 0.2 + ripple * 0.5);
}

fragment float4 pattern_dots(VertexOut in [[stage_in]], constant ShaderConfig &config [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspectRatio = config.resolution.x / config.resolution.y;
    
    // Correct UV and grid for aspect ratio
    float2 aspectCorrectedUV = float2(uv.x * aspectRatio, uv.y);
    float2 grid = float2(config.patternScale.x * aspectRatio, config.patternScale.y);
    
    // Get ripple influence
    float ripple = touchRipple(aspectCorrectedUV, config.touchPosition, config.touchTime, config.touchTime, config.patternSpeed);
    
    float pattern;
    if (config.patternType == 0) {
        // Calculate base dot pattern
        float2 gridPos = fract(aspectCorrectedUV * grid);
        float2 center = gridPos - 0.5;
        float dots = length(center * 2.0);
        float dynamicDotSize = config.dotSize * (1.0 + ripple * 3.0);
        
        float wave = sin(aspectCorrectedUV.y * 3.14159 + config.time * config.patternSpeed) * 0.5 + 0.5;
        dynamicDotSize = mix(dynamicDotSize * 0.5, dynamicDotSize * 1.5, wave);
        pattern = smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
    } else if (config.patternType == 1) {
        // Calculate base dot pattern
        float2 gridPos = fract(aspectCorrectedUV * grid);
        float2 center = gridPos - 0.5;
        float dots = length(center * 2.0);
        float dynamicDotSize = config.dotSize * (1.0 + ripple * 3.0);
        
        // Circular wave pattern
        float2 centerOffset = float2(0.4, 0.5);
        float2 screenCenter = aspectCorrectedUV - centerOffset;
        float distFromCenter = length(screenCenter * 2.0) * 4.0;
        float wave = sin(distFromCenter - config.time * config.patternSpeed) * 0.5 + 0.5;
        dynamicDotSize = mix(dynamicDotSize * 0.4, dynamicDotSize * 2.0, wave);
        pattern = smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
    } else if (config.patternType == 2) {
        // Calculate base dot pattern
        float2 gridPos = fract(aspectCorrectedUV * grid);
        float2 center = gridPos - 0.5;
        float dots = length(center * 2.0);
        float dynamicDotSize = config.dotSize * (1.0 + ripple * 3.0);
        
        // Ripple pattern
        float2 centerOffset = float2(0.4, 0.5);
        float2 pos = aspectCorrectedUV - centerOffset;
        float dist = length(pos * 2.0);
        float baseRipple = sin((dist * 4.0 - config.time * config.patternSpeed) * 3.14159) / (1.0 + dist * 3.0);
        dynamicDotSize = mix(dynamicDotSize * 0.4, dynamicDotSize * 2.0, baseRipple * 0.5 + 0.5);
        pattern = smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
    } else {
        // Use the noise pattern directly
        pattern = noisePattern(aspectCorrectedUV, grid, config.time, config.patternSpeed, 
                             config.dotSize, config.resolution, config.touchPosition, 
                             config.touchTime, config.touchTime);
    }
    
    return mix(float4(0, 0, 0, 1), float4(1, 1, 1, 1), pattern);
}
