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
    float touchEndTime;
    int32_t isMultiColored;
    float gradientSpeed;
    float padding;
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

float3 getGradientColor(float2 uv, float time, float speed) {
    // Create animated gradient
    float t = (uv.x + uv.y + time * speed) * 0.5;
    
    // Create smooth color transitions
    float3 color1 = float3(0.8, 0.2, 0.3); // Red
    float3 color2 = float3(0.2, 0.5, 0.8); // Blue
    float3 color3 = float3(0.3, 0.8, 0.2); // Green
    
    float3 finalColor;
    float t3 = fract(t) * 3.0;
    
    if (t3 < 1.0) {
        finalColor = mix(color1, color2, t3);
    } else if (t3 < 2.0) {
        finalColor = mix(color2, color3, t3 - 1.0);
    } else {
        finalColor = mix(color3, color1, t3 - 2.0);
    }
    
    return finalColor;
}

fragment float4 pattern_dots(VertexOut in [[stage_in]], constant ShaderConfig &config [[buffer(0)]]) {
    // UV coordinates range from (0,0) to (1,1) across the screen
    float2 uv = in.uv;
    // Screen's width/height ratio, used to correct for non-square screens
    float aspectRatio = config.resolution.x / config.resolution.y;
    
    // Step 1: UV Space Normalization
    // Stretch the x-coordinate by aspectRatio to make cells square in screen space
    // This ensures equal horizontal and vertical spacing in screen space
    float2 normalizedUV = float2(uv.x * aspectRatio, uv.y);
    
    // Step 2: Grid Spacing Configuration
    float baseGridDensity = 2.0; // Increase this value for denser grid
    float2 grid = float2(
        config.patternScale.x * aspectRatio * baseGridDensity,  // Denser horizontal spacing
        config.patternScale.y * baseGridDensity                 // Denser vertical spacing
    );
    
    // Step 3: Grid Cell Calculation
    // fract() creates repeating cells of size 1/grid
    // Each cell will contain one dot
    float2 gridPos = fract(normalizedUV * grid);
    
    // Step 4: Dot Position in Cell
    // Center the coordinate system in each cell (-0.5 to 0.5 range)
    // Scale the y-coordinate by aspectRatio to maintain circular shape
    float2 center = (gridPos - 0.5) * float2(1.0, aspectRatio);
    
    // Step 5: Dot Shape Calculation
    // length() gives distance from cell center
    // Divide by aspectRatio to counter the y-scaling above
    // This ensures dots remain circular regardless of screen shape
    float dots = length(center) / aspectRatio;
    
    // Step 6: Dot Size
    // Base size for dots, scaled down to look better
    float baseDotSize = config.dotSize * 0.5;
    
    // The final dot shape is created in the pattern calculation below
    // smoothstep(size, size - 0.005, dots) creates the circular shape
    // where 'size' determines the dot radius
    
    // Get ripple influence
    float ripple = touchRipple(normalizedUV, config.touchPosition, config.touchTime, config.touchEndTime, config.patternSpeed);
    
    float pattern;
    if (config.patternType == 0) {  // Wave pattern
        float wave = sin(uv.y * 3.14159 + config.time * config.patternSpeed) * 0.5 + 0.5;
        // Increase wave contrast
        wave = pow(wave, 1.2);  // Makes peaks brighter and valleys darker
        float dynamicDotSize = mix(baseDotSize * 0.3, baseDotSize * 1.7, wave);
        // Sharper dot edges
        pattern = smoothstep(dynamicDotSize, dynamicDotSize - 0.002, dots);
    }
    else if (config.patternType == 1) {  // Circular wave
        float2 screenCenter = normalizedUV - float2(0.5 * aspectRatio, 0.5);
        float distFromCenter = length(screenCenter * 2.0);
        
        float wave = sin(distFromCenter - config.time * config.patternSpeed) * 0.5 + 0.5;
        float dynamicDotSize = mix(baseDotSize * 0.4, baseDotSize * 2.0, wave);
        pattern = smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
    }
    else if (config.patternType == 2) {  // Ripple
        float2 pos = normalizedUV - float2(0.5 * aspectRatio, 0.5);
        float dist = length(pos * 2.0);
        
        float baseRipple = sin((dist * 4.0 - config.time * config.patternSpeed) * 3.14159) / (1.0 + dist * 3.0);
        float dynamicDotSize = mix(baseDotSize * 0.4, baseDotSize * 2.0, baseRipple * 0.5 + 0.5);
        pattern = smoothstep(dynamicDotSize, dynamicDotSize - 0.005, dots);
    }
    else {  // Noise pattern
        pattern = noisePattern(normalizedUV, grid, config.time, config.patternSpeed, 
                             baseDotSize, config.resolution, config.touchPosition, 
                             config.touchTime, config.touchTime);
    }
    
    // Apply ripple effect with increased contrast
    float rippleDotSize = baseDotSize * (1.0 + ripple * 4.0); // Increased ripple intensity
    pattern = mix(pattern, smoothstep(rippleDotSize, rippleDotSize - 0.002, dots), ripple);
    
    // Increase overall pattern contrast
    pattern = pow(pattern, 0.8); // Makes light areas brighter while keeping dark areas dark
    
    float4 finalColor;
    if (config.isMultiColored == 1) {
        float3 gradientColor = getGradientColor(normalizedUV, config.time, config.gradientSpeed);
        finalColor = float4(mix(float3(0), gradientColor, pattern), 1.0);
    } else {
        // Increased contrast for monochrome mode
        finalColor = mix(float4(0, 0, 0, 1), float4(1, 1, 1, 1), pattern);
    }
    
    return finalColor;
}
