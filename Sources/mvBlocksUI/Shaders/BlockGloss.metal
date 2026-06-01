#include <metal_stdlib>
using namespace metal;

// Glossy bevel for a single settled/active cell. Applied via SwiftUI
// `.colorEffect` to a rounded-rect filled with the piece's tint: the incoming
// `color` is the flat tint, and we add a soft top-left highlight and a
// bottom-right shadow so each cell reads as a beveled tile.
//
// `size` is the cell's pixel size.

[[ stitchable ]]
half4 blockGloss(float2 position, half4 color, float2 size) {
    float2 uv = position / size;          // 0...1 within the cell
    float2 c = uv - 0.5;

    // Diagonal light from the top-left.
    float lightDir = dot(normalize(float2(-1.0, -1.0)), normalize(c + 1e-4));
    float highlight = smoothstep(0.2, 1.0, lightDir) * (1.0 - length(c) * 1.2);
    float shadow = smoothstep(0.2, 1.0, -lightDir) * 0.6;

    half3 rgb = color.rgb;
    rgb += half3(half(max(0.0, highlight)) * 0.45);   // lift toward white
    rgb -= half3(half(max(0.0, shadow)) * 0.30);      // sink toward black

    // Subtle inner border so adjacent cells stay distinct.
    float edge = max(abs(c.x), abs(c.y));
    float border = smoothstep(0.46, 0.5, edge);
    rgb *= (1.0 - half(border) * 0.35);

    return half4(clamp(rgb, 0.0, 1.0), color.a);
}
