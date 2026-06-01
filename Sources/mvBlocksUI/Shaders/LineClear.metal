#include <metal_stdlib>
using namespace metal;

// Horizontal flash sweep played over a row that's clearing. Drives a
// transparent overlay sized to the row via `.colorEffect`. `progress` runs
// 0...1 over the clear animation; a bright band sweeps across and fades.

[[ stitchable ]]
half4 lineClear(float2 position, half4 color, float2 size, float progress) {
    float x = position.x / size.x;        // 0...1 across the row

    // A bright band centered at the sweep position.
    float band = exp(-40.0 * pow(x - progress, 2.0));
    // Whole row brightens then fades out as progress completes.
    float fade = 1.0 - smoothstep(0.7, 1.0, progress);

    half3 flash = half3(1.0, 0.98, 0.86);
    half alpha = half((0.85 * band + 0.25) * fade);

    return half4(flash, alpha);
}
