#ifdef GL_ES
precision mediump float;
#endif

uniform float time;
uniform vec2 resolution;
uniform vec2 mouse;

#define MAX_BOUNCES 8
float gamma = 2.2;

struct Material
{
    vec3 difuseColor;
    vec3 specularColor;
};

struct Ray
{
    vec3 origin;
    vec3 direction;
};

struct Hit
{
    float t;// solution to p=o+t*d
    vec3 normal;
    Material material;
};
const Hit noHit = Hit(1e10, vec3(0.), Material(vec3(-1.), vec3(-1.)));

struct Plane
{
    float d;// solution to dot(n,p)+d=0
    vec3 normal;
    Material material;
};

struct Sphere
{
    float radius;
    vec3 center;
    Material material;
};

struct AABox
{
    vec3 size;
    vec3 centerPosition;
    Material material;
};

Hit intersectPlane(Plane p, Ray r)
{
    float dotnd = dot(p.normal, r.direction);
    if (dotnd > 0.) return noHit;

    float t = -(dot(r.origin, p.normal) + p.d) / dotnd;
    return Hit(t, p.normal, p.material);
}

bool isInside(vec2 a, vec2 b)
{
    return a.x < b.x && a.y < b.y;
}

void AAboxPlaneIntersection(vec3 o, vec3 d, vec3 s, inout float t, out float ndir)
{
    ndir = 0.;
    if (d.x != 0.)
    {
        float tmin = (-0.5 * s.x - o.x) / d.x;
        if (tmin >= 0. && tmin < t && isInside(abs(o.yz + tmin * d.yz), 0.5 * s.yz))
        {
            t = tmin;
            ndir = -1.;
        }

        float tmax = (0.5 * s.x - o.x) / d.x;
        if (tmax >= 0. && tmax < t && isInside(abs(o.yz + tmax * d.yz), 0.5 * s.yz))
        {
            t = tmax;
            ndir = 1.;
        }
    }
}

Hit intersectBox(AABox b, Ray r)
{
    Hit hit = noHit;
    vec3 ro = r.origin - b.centerPosition;

    float ndir = 0.;
    AAboxPlaneIntersection(ro.xyz, r.direction.xyz, b.size.xyz, hit.t, ndir);
    if (ndir != 0.) { hit.normal = vec3(ndir, 0., 0.); hit.material = b.material; }

    AAboxPlaneIntersection(ro.yzx, r.direction.yzx, b.size.yzx, hit.t, ndir);
    if (ndir != 0.) { hit.normal = vec3(0., ndir, 0.); hit.material = b.material; }

    AAboxPlaneIntersection(ro.zxy, r.direction.zxy, b.size.zxy, hit.t, ndir);
    if (ndir != 0.) { hit.normal = vec3(0., 0., ndir); hit.material = b.material; }

    return hit;
}

Hit intersectSphere(Sphere s, Ray r)
{
    vec3 op = s.center - r.origin;
    float b = dot(op, r.direction);
    float det = b * b - dot(op, op) + s.radius * s.radius;
    if (det < 0.) return noHit;

    det = sqrt(det);
    float t = b - det;
    if (t < 0.) t = b + det;
    if (t < 0.) return noHit;

    return Hit(t, (r.origin + t*r.direction - s.center) / s.radius, s.material);
}

bool compare(inout Hit a, Hit b)
{
    if (b.material.specularColor.r >= 0. && b.t < a.t)
    {
        a = b;
        return true;
    }
    return false;
}

Hit intersectScene(Ray r)
{
    Sphere s1 = Sphere(1., vec3(-2., 1., 0.), Material(vec3(1.0, 0.0, 0.2), vec3(0.04)));
    s1.center.x += time;

    Sphere s2 = Sphere(0.8, vec3(0.5, 0.8, -1.2), Material(vec3(0.0), vec3(0.55, 0.56, 0.55)));
    s2.center.z -= time;

    Sphere s3 = Sphere(0.8, vec3(2.0, 0.8, -0.8), Material(vec3(0.0), vec3(1., 0.77, 0.34)));
    s3.center.y += time;

    Plane p = Plane(0., vec3(0., 1., 0.), Material(vec3(0.5, 0.4, 0.3), vec3(0.04)));
    AABox b = AABox(vec3(0.8, 0.1, 0.75), vec3(1.2, 0.1, 1.7), Material(vec3(0.1), vec3(0.95, 0.64, 0.54)));

    Hit hit = noHit;
    compare(hit, intersectPlane(p, r));
    compare(hit, intersectSphere(s1, r));
    compare(hit, intersectSphere(s2, r));
    compare(hit, intersectSphere(s3, r));
    compare(hit, intersectBox(b, r));
    return hit;
}

vec3 sunCol = vec3(1e3);
vec3 sunDir = normalize(vec3(.8, .55, -1.));
vec3 skyColor(vec3 d)
{
    float transition = pow(smoothstep(0.02, .5, d.y), 0.4);

    vec3 sky = 2e2*mix(vec3(0.52, 0.77, 1), vec3(0.12, 0.43, 1), transition);
    vec3 sun = vec3(1e7) * pow(abs(dot(d, sunDir)), 5000.);
    return sky + sun;
}

float pow5(float x) { return x * x * x * x * x; }

// Schlick approximation
vec3 fresnel(vec3 h, vec3 v, vec3 f0)
{
    return pow5(1. - clamp(dot(h, v), 0., 1.)) * (1. - f0) + f0;
}

vec3 radiance(Ray r)
{
    float epsilon = 4e-4;

    vec3 accum = vec3(0.);
    vec3 attenuation = vec3(1.);

    for (int i = 0; i <= MAX_BOUNCES; ++i)
    {
        Hit hit = intersectScene(r);

        if (hit.material.specularColor.r >= 0.)
        {
            vec3 f = fresnel(hit.normal, -r.direction, hit.material.specularColor);

            // Diffuse
            if (intersectScene(Ray(r.origin + hit.t * r.direction + epsilon * sunDir, sunDir)).material.specularColor.r < 0.)
            {
                accum += (1. - f) * attenuation * hit.material.difuseColor * clamp(dot(hit.normal, sunDir), 0., 1.) * sunCol;
            }

            // Specular: next bounce
            attenuation *= f;
            vec3 d = reflect(r.direction, hit.normal);
            r = Ray(r.origin + hit.t * r.direction + epsilon * d, d);
        }
        else
        {
            accum += attenuation * skyColor(r.direction);
            break;
        }
    }
    return accum;
}

vec3 Uncharted2ToneMapping(vec3 color)
{
    float A = 0.15;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20;
    float E = 0.02;
    float F = 0.30;
    float W = 11.2;
    float exposure = 0.012;
    color *= exposure;
    color = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
    float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
    color /= white;
    color = pow(color, vec3(1. / gamma));
    return color;
}


mat4 rotationMatrix(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    return mat4(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0,
    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0.0,
    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0.0,
    0.0, 0.0, 0.0, 1.0);
}

vec3 rotate(vec3 v, vec3 axis, float angle) {
    mat4 m = rotationMatrix(axis, angle);
    return (m * vec4(v, 1.0)).xyz;
}

void main()
{
    vec2 uv = 2. * gl_FragCoord.xy / resolution.xy - 1.;

    float o1 = 0.25;
    float o2 = 0.75;
    vec2 msaa[4];
    msaa[0] = vec2(o1, o2);
    msaa[1] = vec2(o2, -o1);
    msaa[2] = vec2(-o1, -o2);
    msaa[3] = vec2(-o2, o1);

    vec3 color = vec3(0.);
    for (int i = 0; i < 4; ++i)
    {
        vec3 initialPosition = vec3(0., 1.1, 4.);

        vec3 position = vec3((2. * (mouse.xy==vec2(0.)?.5*resolution.xy:mouse.xy) / resolution.xy - 1.) * vec2(1., 1.), 0.) + initialPosition;
        position = initialPosition;

        vec3 offset = vec3(msaa[i] / resolution.y, 0.);
        vec3 direction = normalize(vec3(resolution.x/resolution.y * uv.x, uv.y + mouse.y / 100., -1.5) + offset);
        direction = rotate(direction, vec3(0, 1, 0), mouse.x / 500.);


        Ray r = Ray(position, direction);
        color += radiance(r) / 4.;
    }

    gl_FragColor = vec4(Uncharted2ToneMapping(color), 1.0);
}
