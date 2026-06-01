#include <metal_stdlib>
using namespace metal;

// Radial sunburst played over the board on a "Blocks-Out" (five-row) clear or
// a level-up. Drives a transparent overlay via `.colorEffect`. `progress` is
// 0...1 across the celebration; `seed` varies the ray pattern per event.

[[ stitchable ]]
half4 celebration(float2 position, half4 color, float2 size, float progress, float seed) {
    float2 c = size * 0.5;
    float minDim = min(size.x, size.y);
    float2 d = (position - c) / (minDim * 0.5);
    float r = length(d);
    float theta = atan2(d.y, d.x);

    float wave = 1.0 - smoothstep(progress * 1.4, progress * 1.4 + 0.12, r);
    float ring = smoothstep(0.0, 0.06, progress) * smoothstep(1.5, 0.6, r);

    float spokes = abs(sin(theta * 10.0 + seed * 6.28));
    spokes = smoothstep(0.55, 1.0, spokes);

    float angularBin = floor(theta * 5.0 / 3.14159) + floor(seed * 17.0);
    float sparkleR = 0.65 + 0.25 * sin(angularBin * 12.9898);
    float sparkle = exp(-30.0 * pow(r - progress * sparkleR, 2.0));

    half3 hot = half3(0.40, 0.92, 1.0);
    half3 cream = half3(1.0, 0.96, 0.86);

    half raysAlpha = half(wave * ring * spokes);
    half sparkleAlpha = half(sparkle * wave);
    half alpha = clamp(raysAlpha * 0.7h + sparkleAlpha, 0.0h, 1.0h);

    half3 rgb = mix(hot, cream, sparkleAlpha);
    return half4(rgb, alpha);
}
