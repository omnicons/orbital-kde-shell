#version 440
// Pass 2: turns each scene pixel into a glyph from the atlas, tinted by its colour.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;          // columns, rows
    float glyphCount;   // characters in the ramp, darkest first
    float gain;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D atlas;
layout(binding = 3) uniform sampler2D overlay;  // items drawn into the grid, premultiplied

void main()
{
    vec2 cc = qt_TexCoord0 * grid;
    vec2 cell = floor(cc);
    vec2 local = fract(cc);

    vec3 c = texture(source, (cell + 0.5) / grid).rgb;
    vec4 o = texture(overlay, (cell + 0.5) / grid);
    c = c * (1.0 - o.a) + o.rgb;
    float lum = max(max(c.r, c.g), c.b);

    float idx = clamp(floor(lum * gain * glyphCount), 0.0, glyphCount - 1.0);
    float glyph = texture(atlas, vec2((idx + local.x) / glyphCount, local.y)).a;

    // Keep the hue, but lift brightness: thin glyphs cover little of the cell.
    vec3 hue = c / max(lum, 1e-4);
    vec3 col = hue * glyph * clamp(0.45 + lum, 0.0, 1.0);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
