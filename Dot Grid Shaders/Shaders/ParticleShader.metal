#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;
    float2 velocity;
    float life;
};

struct ParticleUniforms {
    float2 resolution;
    float time;
    float2 touchPosition;
    bool isTouching;
    float particleSpeed;
    float particleSize;
    float sphereSize;
    float bounceStartTime;
    float pulseTime;
    bool isPulsing;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

[[kernel]]
void particleCompute(device Particle *particles [[buffer(0)]],
                    constant ParticleUniforms &uniforms [[buffer(1)]],
                    constant uint &particleCount [[buffer(2)]],
                    uint id [[thread_position_in_grid]]) {
    Particle particle = particles[id];
    
    float time = uniforms.time * uniforms.particleSpeed;
    float2 center = uniforms.resolution * 0.5;
    
    float n = float(id);
    float N = float(particleCount);
    
    // Base spherical coordinates
    float phi = 2.0 * M_PI_F * fmod(n * 0.618034, 1.0) + time * 0.1;
    float cosTheta = 1.0 - (2.0 * n + 1.0) / N;
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    float baseRadius = uniforms.sphereSize;
    
    // Base breathing animation
    float breathing = 1.0 + 0.1 * sin(time * 0.5);
    
    // Very subtle pulse effect that maintains sphere structure
    float pulseEffect = 1.0;
    if (uniforms.isPulsing) {
        float pulseTime = time - uniforms.pulseTime;
        if (pulseTime < 2.0) {
            // Simple radial pulse
            float distanceFromCenter = length(float2(cosTheta, sinTheta));
            float pulsePhase = pulseTime * 1.8 - distanceFromCenter * 2.2;
            float pulseWave = sin(pulsePhase);
            
            // Very small amplitude, slightly increased
            pulseEffect = 1.0 + 0.065 * pulseWave;
        }
    }
    
    // Calculate final radius - keep it simple
    float radius = baseRadius * breathing * pulseEffect;
    
    // Calculate 3D position
    float x = cos(phi) * sinTheta * radius;
    float y = sin(phi) * sinTheta * radius;
    float z = cosTheta * radius;
    
    // Project to 2D with perspective
    float scale = (z + baseRadius * 2) / (baseRadius * 3);
    float2 targetPos = center + float2(x, y) * scale;
    
    // Smooth movement
    float2 toTarget = targetPos - particle.position;
    float dist = length(toTarget);
    if (dist > 0.01) {
        float attraction = uniforms.particleSpeed * min(dist * 0.08, 0.5);
        float dampening = 0.99;
        particle.velocity = particle.velocity * dampening + normalize(toTarget) * attraction;
        particle.position += particle.velocity;
    }
    
    // Calculate life normally based on z-position
    particle.life = 0.3 + 0.7 * ((z / baseRadius) * 0.5 + 0.5);
    
    particles[id] = particle;
}

[[vertex]]
VertexOut particleVertex(uint vertexID [[vertex_id]]) {
    const float2 vertices[] = {
        float2(-1, -1),
        float2( 3, -1),
        float2(-1,  3)
    };
    
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.uv = vertices[vertexID] * 0.5 + 0.5;
    return out;
}

[[fragment]]
float4 particleFragment(VertexOut in [[stage_in]],
                       constant ParticleUniforms &uniforms [[buffer(0)]],
                       device Particle *particles [[buffer(1)]],
                       constant uint &particleCount [[buffer(2)]]) {
    float2 uv = in.uv;
    float4 color = float4(0.0);
    
    for (uint i = 0; i < particleCount; i++) {
        Particle particle = particles[i];
        float2 particleUV = particle.position / uniforms.resolution;
        float dist = length(uv - particleUV);
        
        if (dist < uniforms.particleSize) {
            // Sharp, bright particles with soft edges
            float alpha = pow(1.0 - dist / uniforms.particleSize, 3.0) * particle.life;
            color += float4(1.0, 1.0, 1.0, alpha);
        }
    }
    
    return color;
} 