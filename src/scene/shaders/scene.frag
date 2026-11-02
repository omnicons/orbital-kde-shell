#version 440
// Pass 1: renders the space scene at one pixel per ASCII cell.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;   // output width / height
    vec2 grid;      // ASCII columns and rows, so stars land on single cells
    vec2 mouse;     // smoothed cursor, -1..1, y up
};

layout(binding = 1) uniform sampler2D earthMap;
layout(binding = 2) uniform sampler2D cloudMap;
layout(binding = 3) uniform sampler2D moonMap;
layout(binding = 4) uniform sampler2D starMap;

const vec3 SUN = normalize(vec3(-0.65, 0.55, 0.55));

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

mat3 rotX(float a)
{
    float c = cos(a), s = sin(a);
    return mat3(1, 0, 0, 0, c, s, 0, -s, c);
}

mat3 rotY(float a)
{
    float c = cos(a), s = sin(a);
    return mat3(c, 0, -s, 0, 1, 0, s, 0, c);
}

const float PI = 3.14159265;

vec3 hash33(vec3 p)
{
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx) * 2.0 - 1.0;
}

float corner(vec3 i, vec3 f, vec3 o)
{
    return dot(hash33(i + o), f - o);
}

// Gradient noise, roughly -0.5..0.5. Gradient rather than value noise, so
// nothing lines up with the lattice.
float noise3(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(corner(i, f, vec3(0, 0, 0)), corner(i, f, vec3(1, 0, 0)), u.x),
                   mix(corner(i, f, vec3(0, 1, 0)), corner(i, f, vec3(1, 1, 0)), u.x), u.y),
               mix(mix(corner(i, f, vec3(0, 0, 1)), corner(i, f, vec3(1, 0, 1)), u.x),
                   mix(corner(i, f, vec3(0, 1, 1)), corner(i, f, vec3(1, 1, 1)), u.x), u.y), u.z);
}

float fbm3(vec3 p)
{
    return noise3(p) + 0.5 * noise3(p * 2.1 + 7.3) + 0.25 * noise3(p * 4.3 + 1.9);
}

// Equirectangular lookup: longitude 0 at the map's centre, north at the top.
vec2 sphereUv(vec3 s)
{
    return vec2(0.5 + atan(s.x, s.z) / (2.0 * PI), 0.5 - asin(clamp(s.y, -1.0, 1.0)) / PI);
}

// The sky is the real one: the Yale Bright Star Catalogue baked into an
// equirectangular map (u = right ascension, v = declination), seen by a
// camera pointed toward Orion.
const float SKY_RA = 84.0 * PI / 180.0;
const float SKY_DEC = -8.0 * PI / 180.0;
const float SKY_FOV = 1.3;  // horizontal, radians (about 75 degrees)

vec2 skyUv(vec2 p)
{
    vec3 fwd = vec3(cos(SKY_DEC) * cos(SKY_RA), cos(SKY_DEC) * sin(SKY_RA), sin(SKY_DEC));
    // Right points toward decreasing RA: from inside the sphere, east is on the left.
    vec3 right = normalize(cross(fwd, vec3(0.0, 0.0, 1.0)));
    vec3 up = cross(right, fwd);
    float k = tan(SKY_FOV * 0.5) / (aspect * 0.5);
    vec3 dir = normalize(fwd + (p.x * right + p.y * up) * k);
    return vec2(fract(atan(dir.y, dir.x) / (2.0 * PI)), 0.5 - asin(dir.z) / PI);
}

vec3 stars(vec2 p)
{
    // Each star is one texel, about a fifth of a cell. A 5x5 grid of taps
    // tiles the cell exactly, so every star is caught by one cell and only one.
    // Over a single cell the projection is close to linear, so the taps step
    // along the cell's edges in uv instead of re-projecting each one.
    vec2 cell = vec2(aspect / grid.x, 1.0 / grid.y);
    vec2 uv = skyUv(p);
    vec2 du = skyUv(p + vec2(cell.x, 0.0)) - uv;
    vec2 dv = skyUv(p + vec2(0.0, cell.y)) - uv;
    du.x -= floor(du.x + 0.5);  // don't step the long way across the RA seam
    dv.x -= floor(dv.x + 0.5);
    vec3 col = vec3(0.0);
    for (int y = -2; y <= 2; ++y)
        for (int x = -2; x <= 2; ++x)
            col = max(col, texture(starMap, uv + (float(x) * du + float(y) * dv) / 5.0).rgb);
    vec2 g = floor(p / cell);
    float twinkle = 0.92 + 0.08 * sin(time * (0.7 + 2.0 * hash12(g)) + hash12(g + 3.1) * 40.0);
    return col * twinkle;
}

// The Moon sits in the background. It's tidally locked, so it doesn't spin;
// the mouse only turns it slightly.
vec3 moon(vec2 p, out float mask)
{
    vec2 d = (p - vec2(aspect * 0.5 - 0.38, 0.3)) / 0.12;
    float d2 = dot(d, d);
    mask = step(d2, 1.0);
    if (d2 > 1.0)
        return vec3(0.0);
    vec3 n = vec3(d, sqrt(1.0 - d2));
    vec3 s = rotY(mouse.x * 0.08) * rotX(0.1 - mouse.y * 0.05) * n;
    float light = smoothstep(-0.2, 0.8, dot(n, SUN));
    return texture(moonMap, sphereUv(s)).rgb * 0.6 * (0.08 + 0.92 * light);
}

vec3 earth(vec2 p, out float mask)
{
    vec2 d = (p - vec2(0.0, -0.66)) / 0.8;
    float d2 = dot(d, d);
    mask = step(d2, 1.0);

    if (d2 > 1.0) {
        // Thin atmospheric halo just outside the limb.
        float halo = exp(-(sqrt(d2) - 1.0) * 45.0);
        float lit = 0.5 + 0.5 * dot(normalize(vec3(d, 0.2)), SUN);
        return vec3(0.25, 0.4, 0.95) * halo * lit * 0.6;
    }

    vec3 n = vec3(d, sqrt(1.0 - d2));
    // Soft terminator so the night side fades instead of cutting to black.
    float light = smoothstep(-0.35, 0.75, dot(n, SUN));

    // Tilt into the planet's frame, then spin around its pole. Spinning
    // backwards moves the surface west to east, like the real thing.
    // The mouse nudges both, which is the subtle "look around" shift.
    float spin = 0.35 - time * 0.02 + mouse.x * 0.22;
    float tilt = 0.35 - mouse.y * 0.12;
    vec3 s = rotY(spin) * rotX(tilt) * n;

    // The gamma lift and scale map the photo onto the glyph ramp: dark ocean
    // lands on - and =, desert on + and *.
    vec3 col = 0.64 * pow(texture(earthMap, sphereUv(s)).rgb, vec3(0.55));
    // Push land (anything redder than it is blue) toward the reference's salmon.
    float landness = smoothstep(0.0, 0.12, col.r - col.b);
    col = mix(col, col * vec3(1.1, 0.82, 0.7), landness);
    col = mix(col, vec3(dot(col, vec3(0.3, 0.5, 0.2))), 0.15);

    // Clouds drift slowly relative to the ground. Thick cores read as % and @,
    // thin edges as #.
    // The noise field slides through 3D space over time, so the clouds evolve
    // everywhere on the sphere without a seam. It bends the lookup (swirl and
    // stretch) and swells or thins the density (clouds form and fade).
    vec3 sc = rotY(time * 0.004) * s;
    vec3 flow = vec3(time * 0.012, -time * 0.008, time * 0.01);
    vec3 warp = vec3(fbm3(sc * 3.0 + flow), fbm3(sc * 3.0 + flow + 17.0), fbm3(sc * 3.0 + flow + 31.0));
    float c = texture(cloudMap, sphereUv(normalize(sc + warp * 0.06))).r;
    c *= 1.0 + 1.2 * fbm3(sc * 2.2 - flow * 1.5 + 5.0);
    float cloud = smoothstep(0.1, 0.55, c);
    vec3 cloudCol = vec3(0.86, 0.87, 0.9) * mix(0.8, 1.05, smoothstep(0.55, 0.9, c));
    col = mix(col, cloudCol, cloud);

    col *= 0.12 + 0.88 * light;
    float rim = pow(1.0 - n.z, 2.5);
    col = mix(col, vec3(0.5, 0.58, 0.95), rim * 0.7 * light);
    return col;
}
void main()
{
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, -1.0);

    // Parallax: nearer layers move further against the cursor.
    float nearMask, farMask;
    vec3 near = earth(p - mouse * 0.035, nearMask);
    vec3 far = moon(p - mouse * 0.015, farMask);
    vec3 sky = stars(p - mouse * 0.006);

    vec3 col = near + (1.0 - nearMask) * (far + (1.0 - farMask) * sky);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
