Shader "Custom/ShiningSunSphereAdvanced"
{
    Properties
    {
        //[Header("Core Appearance")]
        _CoreColor("Core Color", Color) = (1.0, 1.0, 0.0, 1.0)
        _OuterColor("Outer Color", Color) = (1.0, 0.0, 0.0, 1.0)
        _Speed("Animation Speed", Range(0, 5)) = 1.0
        _Density("Sun Density", Range(0, 10)) = 1.0
        _Zoom("Noise Scale", Range(0.1, 5.0)) = 1.0

        //[Header("Volumetric Corona")]
        _HaloRatio("Corona Scale (Ratio)", Range(0.0, 1.0)) = 0.2
        _HaloOpacity("Corona Intensity", Range(0.0, 20.0)) = 5.0
        _RaySteps("Raymarch Steps (Quality)", Int) = 16
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" "Queue" = "Transparent" }
            LOD 100

            // --- SHARED FUNCTIONS ---
            CGINCLUDE
                #include "UnityCG.cginc"

            // 1. Hash Function
            float4 hash4(float4 n) {
                return frac(sin(n) * 1399763.5453123);
            }

        // 2. 4D Noise Function
        float noise4q(float4 x)
        {
            float4 n3 = float4(0, 0.25, 0.5, 0.75);
            float4 p2 = floor(x.wwww + n3);
            float4 b = floor(x.xxxx + n3) + floor(x.yyyy + n3) * 157.0 + floor(x.zzzz + n3) * 113.0;
            float4 p1 = b + frac(p2 * 0.00390625) * float4(164352.0, -164352.0, 163840.0, -163840.0);
            p2 = b + frac((p2 + 1.0) * 0.00390625) * float4(164352.0, -164352.0, 163840.0, -163840.0);

            float4 f1 = frac(x.xxxx + n3);
            float4 f2 = frac(x.yyyy + n3);

            f1 = f1 * f1 * (3.0 - 2.0 * f1);
            f2 = f2 * f2 * (3.0 - 2.0 * f2);

            float4 n1 = float4(0, 1.0, 157.0, 158.0);
            float4 n2 = float4(113.0, 114.0, 270.0, 271.0);

            float4 vs1 = lerp(hash4(p1), hash4(n1.yyyy + p1), f1);
            float4 vs2 = lerp(hash4(n1.zzzz + p1), hash4(n1.wwww + p1), f1);
            float4 vs3 = lerp(hash4(p2), hash4(n1.yyyy + p2), f1);
            float4 vs4 = lerp(hash4(n1.zzzz + p2), hash4(n1.wwww + p2), f1);

            vs1 = lerp(vs1, vs2, f2);
            vs3 = lerp(vs3, vs4, f2);

            vs2 = lerp(hash4(n2.xxxx + p1), hash4(n2.yyyy + p1), f1);
            vs4 = lerp(hash4(n2.zzzz + p1), hash4(n2.wwww + p1), f1);

            vs2 = lerp(vs2, vs4, f2);
            vs4 = lerp(hash4(n2.xxxx + p2), hash4(n2.yyyy + p2), f1);
            float4 vs5 = lerp(hash4(n2.zzzz + p2), hash4(n2.wwww + p2), f1);

            vs4 = lerp(vs4, vs5, f2);

            f1 = frac(x.zzzz + n3);
            f2 = frac(x.wwww + n3);

            f1 = f1 * f1 * (3.0 - 2.0 * f1);
            f2 = f2 * f2 * (3.0 - 2.0 * f2);

            vs1 = lerp(vs1, vs2, f1);
            vs3 = lerp(vs3, vs4, f1);
            vs1 = lerp(vs1, vs3, f2);

            float r = dot(vs1, float4(0.25, 0.25, 0.25, 0.25));
            return r * r * (3.0 - 2.0 * r);
        }

        // 3. Surface Noise
        float surfaceNoise(float3 pos, float3x3 mr, float zoom, float3 subnoise, float anim)
        {
            float3 r1 = mul(pos, mr);
            float s = 0.0;
            float d = 0.03125;
            float d2 = zoom / (d * d);
            float ar = 5.0;

            for (int i = 0; i < 3; i++) {
                s += abs(noise4q(float4(r1 * d2 + subnoise * ar, anim * ar)) * d);
                ar -= 2.0;
                d *= 4.0;
                d2 *= 0.0625;
            }
            return s;
        }

        // 4. Matrix Builder
        float3x3 buildRotationMatrix(float time) {
            float mx = time * 0.025;
            float my = -0.6;
            float2 rotate = float2(mx, my);
            float2 sins = sin(rotate);
            float2 coss = cos(rotate);

            float3x3 mr1 = float3x3(
                coss.x, 0.0, sins.x,
                0.0,    1.0, 0.0,
                -sins.x, 0.0, coss.x
            );

            float3x3 mr2 = float3x3(
                1.0, 0.0,     0.0,
                0.0, coss.y,  sins.y,
                0.0, -sins.y, coss.y
            );
            return mul(mr2, mr1);
        }
    ENDCG

        // --- PASS 1: The Core (Solid) ---
        Pass
        {
            Name "Core"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata {
                float4 vertex : POSITION;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float3 objPos : TEXCOORD0;
            };

            float4 _CoreColor;
            float4 _OuterColor;
            float _Speed;
            float _Density;
            float _Zoom;

            v2f vert(appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.objPos = v.vertex.xyz;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float time = _Time.y * _Speed;
                float3x3 mr = buildRotationMatrix(time);
                float3 pos = normalize(i.objPos);

                float s1 = surfaceNoise(pos, mr, 0.5, float3(0.0,0.0,0.0), time);
                s1 = pow(min(1.0, s1 * 2.4), 2.0);

                float s2 = surfaceNoise(pos, mr, 4.0, float3(83.23, 34.34, 67.453), time);
                s2 = min(1.0, s2 * 2.2);

                float3 col = lerp(_CoreColor.rgb, float3(1.0,1.0,1.0), pow(s1, 60.0)) * s1;
                col += lerp(lerp(_OuterColor.rgb, float3(1.0, 0.0, 1.0), pow(s2, 2.0)), float3(1.0,1.0,1.0), pow(s2, 10.0)) * s2;

                return float4(col * _Density, 1.0);
            }
            ENDCG
        }

        // --- PASS 2: The Corona (Volumetric Raymarch) ---
        Pass
        {
            Name "Corona"
            Blend SrcAlpha One
            ZWrite Off
            Cull Off // Render FRONT and BACK of the gas for double density

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD0; // Using World Pos for clearer math
                float3 center : TEXCOORD1;   // World Center
                float radius : TEXCOORD3;    // World Radius
                float haloWidth : TEXCOORD4; // World Halo Width
            };

            float4 _OuterColor;
            float _Speed;
            float _HaloRatio;
            float _HaloOpacity;
            int _RaySteps;

            v2f vert(appdata v) {
                v2f o;

                // 1. Calculate World Info
                // Transform object center to world space
                o.center = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;

                // Calculate scale (uniform scaling assumed)
                float3 worldScale = float3(
                    length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)),
                    length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)),
                    length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))
                );

                // Measure the actual geometry radius
                float meshRadius = length(v.vertex.xyz);
                o.radius = meshRadius * worldScale.x; // World Space Radius

                // Calculate Halo Width
                o.haloWidth = o.radius * _HaloRatio;

                // 2. Expand Vertices
                float3 expandedPos = v.vertex.xyz + v.normal * (meshRadius * _HaloRatio);

                o.worldPos = mul(unity_ObjectToWorld, float4(expandedPos, 1.0));
                o.vertex = UnityObjectToClipPos(float4(expandedPos, 1.0));

                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                float time = _Time.y * _Speed;
                float3x3 mr = buildRotationMatrix(time);

                // Direction from Camera to Pixel (World Space)
                float3 rayDir = normalize(i.worldPos.xyz - _WorldSpaceCameraPos);
                float3 currentPos = i.worldPos.xyz;

                float totalDensity = 0.0;

                // Step size 
                float stepSize = i.haloWidth / float(_RaySteps);

                // Dither
                float dither = frac(sin(dot(i.vertex.xy, float2(12.9898, 78.233))) * 43758.5453);
                currentPos += rayDir * stepSize * dither;

                for (int s = 0; s < _RaySteps; s++)
                {
                    // Distance from Sphere Center
                    float dist = length(currentPos - i.center);

                    // Core Occlusion: Stop if we hit solid surface
                    if (dist < i.radius) break;

                    // Normalize position relative to center for noise lookup
                    float3 noisePos = normalize(currentPos - i.center);

                    // Sample Noise
                    float noiseVal = surfaceNoise(noisePos, mr, 10.0, float3(12.23, 5.34, 99.453), time * 1.5);

                    // Density Falloff
                    float fade = 1.0 - smoothstep(i.radius, i.radius + i.haloWidth, dist);

                    totalDensity += pow(noiseVal, 3.0) * fade;

                    // March Forward
                    currentPos += rayDir * stepSize;
                }

                float alpha = totalDensity * (_HaloOpacity / float(_RaySteps));
                float3 col = _OuterColor.rgb * alpha;

                return float4(col, alpha);
            }
            ENDCG
        }
        }
}

//Shader "Custom/URP_SunRay"
//{
//    Properties
//    {
//        _MainColor("Main Color", Color) = (1, 0.7, 0.2, 1)
//        _TimeSpeed("Animation Speed", Float) = 1
//        _SunRadius("Sun Radius", Float) = 0.4
//        _Intensity("Intensity", Float) = 2
//    }
//
//        SubShader
//    {
//        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
//
//        Pass
//        {
//            Name "Sun Ray"
//            HLSLPROGRAM
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//
//            #pragma fragment frag
//
//            float4 _MainColor;
//            float _SunRadius;
//            float _TimeSpeed;
//            float _Intensity;
//
//            //-------------------------------------------
//            float hash21(float2 p)
//            {
//                p = frac(p * float2(123.34, 345.45));
//                p += dot(p, p + 34.23);
//                return frac(p.x * p.y);
//            }
//
//            float4 noise4q(float4 p)
//            {
//                float4 i = floor(p);
//                float4 f = frac(p);
//
//                float n = i.x + i.y * 57.0 + i.z * 113.0 + i.w * 271.0;
//
//                float a = hash21(n);
//                float b = hash21(n + 1.0);
//                float t = smoothstep(0.0, 1.0, f.x);
//
//                return lerp(a, b, t).xxxx;
//            }
//
//            float sunNoise(float3 p, float t)
//            {
//                float n = 0;
//                float d = 1;
//
//                for (int i = 0; i < 4; i++)
//                {
//                    n += abs(noise4q(float4(p * d, t * 0.5)) * d);
//                    d *= 2.5;
//                }
//                return n;
//            }
//
//            float4 frag(float4 pos : SV_POSITION, float2 uv : TEXCOORD0) : SV_Target
//            {
//                return float4(1, 0, 0, 1);  // ȫ�������ɫ
//                //float2 c = uv - 0.5;
//                //float r = length(c);
//                //float time = _Time.y * _TimeSpeed;
//
//                //if (r <= _SunRadius)
//                //{
//                //    float3 dir = normalize(float3(c, sqrt(_SunRadius * _SunRadius - r * r)));
//                //    float n = sunNoise(dir * 2, time);
//                //    float heat = pow(1 - r / _SunRadius, 4);
//                //    float val = (n * 0.1 + heat) * _Intensity;
//                //    return float4(_MainColor.rgb * val,1);
//                //}
//
//                //float glow = smoothstep(_SunRadius + 0.1,_SunRadius,r);
//                //glow = pow(glow,8) * 3;
//                //return float4(_MainColor.rgb * glow, glow);
//            }
//
//            ENDHLSL
//        }
//    }
//}
//Shader "Custom/SunStarSimple"
//{
//    Properties
//    {
//        _MainColor("Main Color", Color) = (1,0.6,0.2,1)
//        _GlowColor("Glow Color", Color) = (1,0.8,0.4,1)
//        _GlowIntensity("Glow Intensity", Float) = 2.0
//        _NoiseScale("Noise Scale", Float) = 2.0
//        _DistortStrength("Distort Strength", Float) = 0.2
//    }
//
//        SubShader
//    {
//        Tags{"Queue" = "Transparent" "RenderType" = "Transparent"}
//        Blend One One
//        ZWrite Off
//        Cull Back
//
//        Pass
//        {
//            Name "FORWARD"
//            Tags{"LightMode" = "UniversalForward"}
//
//            HLSLPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//
//            struct Attributes
//            {
//                float4 positionOS : POSITION;
//                float2 uv : TEXCOORD0;
//            };
//
//            struct Varyings
//            {
//                float4 positionHCS : SV_POSITION;
//                float2 uv : TEXCOORD0;
//            };
//
//            float _NoiseScale;
//            float _DistortStrength;
//            float4 _MainColor;
//            float4 _GlowColor;
//            float _GlowIntensity;
//
//            // Simple hash noise
//            float hash(float2 p)
//            {
//                return frac(sin(dot(p, float2(12.9898,78.233))) * 43758.5453);
//            }
//
//            // Smooth noise
//            float noise(float2 p)
//            {
//                float2 i = floor(p);
//                float2 f = frac(p);
//
//                float a = hash(i);
//                float b = hash(i + float2(1,0));
//                float c = hash(i + float2(0,1));
//                float d = hash(i + float2(1,1));
//
//                float2 u = f * f * (3.0 - 2.0 * f);
//                return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
//            }
//
//            // Fake FBM
//            float fbm(float2 p)
//            {
//                float v = 0.0;
//                float a = 0.5;
//                for (int i = 0; i < 4; i++)
//                {
//                    v += a * noise(p);
//                    p *= 2.0;
//                    a *= 0.5;
//                }
//                return v;
//            }
//
//            Varyings vert(Attributes IN)
//            {
//                Varyings o;
//                o.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
//                o.uv = IN.uv * 2.0 - 1.0;   // convert to -1 ~ 1
//                return o;
//            }
//
//            half4 frag(Varyings IN) : SV_Target
//            {
//                float2 uv = IN.uv;
//
//                float r = length(uv);
//
//                // noise distort
//                float distort = fbm(uv * _NoiseScale + _Time.y * 0.2) * _DistortStrength;
//
//                r += distort;
//
//                // sun core
//                float core = smoothstep(1.0, 0.2, r);
//                float4 col = _MainColor * core;
//
//                // glow halo
//                float glow = smoothstep(1.2, 0.3, r);
//                col += _GlowColor * glow * _GlowIntensity;
//
//                return col;
//            }
//            ENDHLSL
//        }
//    }
//}
//Shader "Custom/Sun_Panteleymonov_Port"
//{
//    Properties
//    {
//        _Radius("Radius", Float) = 500             // ��Ӧ����뾶
//        _MainLight("Light Color", Color) = (1,1,0.8,1)
//        _MainColor("Color", Color) = (1,0.9,0.2,1)
//        _Base("Base", Color) = (1,0.3,0,1)
//        _Dark("Dark", Color) = (0.5,0,0,1)
//
//        _RayString("Ray String", Range(1.0,200.0)) = 50.0  // ������ɢ��Χ
//        _RayLight("Ray Light", Color) = (1,0.95,1.0,1)
//        _RayEnd("Ray End", Color) = (1,0.6,0.1,1)
//
//        _Detail("Detail Body", Range(0,5)) = 3
//        _Rays("Rays", Range(1.0,10.0)) = 3.0
//        _RayRing("Ray Ring", Range(1.0,10.0)) = 3.0
//        _RayGlow("Ray Glow", Range(1.0,50.0)) = 12.0
//        _Glow("Glow", Range(1.0,50.0)) = 10.0
//
//        _Zoom("Zoom", Float) = 20.0
//        _SpeedHi("Speed Hi", Range(0.0,10)) = 5.0
//        _SpeedLow("Speed Low", Range(0.0,10)) = 2.0
//        _SpeedRay("Speed Ray", Range(0.0,10)) = 5.0
//        _SpeedRing("Speed Ring", Range(0.0,20)) = 2.0
//        _Seed("Seed", Range(-10,10)) = 0
//    }
//
//
//        SubShader
//    {
//        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
//        LOD 100
//
//        Pass
//        {
//            Blend One OneMinusSrcAlpha
//            ZWrite Off
//            Cull Off
//
//            HLSLPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//            #include "UnityCG.cginc"
//
//        // ---- uniform / properties ----
//        float _Radius;
//        float4 _MainLight;
//        float4 _MainColor;
//        float4 _Base;
//        float4 _Dark;
//        float _RayString;
//        float4 _RayLight;
//        float4 _RayEnd;
//        int _Detail;
//        float _Rays;
//        float _RayRing;
//        float _RayGlow;
//        float _Glow;
//        float _Zoom;
//        float _SpeedHi;
//        float _SpeedLow;
//        float _SpeedRay;
//        float _SpeedRing;
//        float _Seed;
//
//        // Built-ins
//        //float4 _Time; // _Time.x = t, .y = t*2, etc.
//        //float3 _WorldSpaceCameraPos;
//
//        struct appdata
//        {
//            float4 vertex : POSITION;
//            float2 uv : TEXCOORD0;
//        };
//
//        struct v2f
//        {
//            float4 pos : SV_POSITION;
//            float3 posOS : TEXCOORD0; // object-space position
//            float2 uv : TEXCOORD1;
//        };
//
//        v2f vert(appdata v)
//        {
//            v2f o;
//            o.pos = UnityObjectToClipPos(v.vertex);
//            o.posOS = v.vertex.xyz;
//            o.uv = v.uv;
//            return o;
//        }
//
//        // ---------- helpers (hash / noise) ----------
//        float4 hash4(float4 n)
//        {
//            return frac(sin(n) * 1399763.5453123);
//        }
//
//        float noise4q(float4 x)
//        {
//            float4 n3 = float4(0.0, 0.25, 0.5, 0.75);
//            float4 p2 = floor(float4(x.w, x.w, x.w, x.w) + n3);
//            float4 b = floor(float4(x.x, x.x, x.x, x.x) + n3)
//                     + floor(float4(x.y, x.y, x.y, x.y) + n3) * 157.0
//                     + floor(float4(x.z, x.z, x.z, x.z) + n3) * 113.0;
//
//            float4 p1 = b + frac(p2 * 0.00390625) * float4(164352.0, -164352.0, 163840.0, -163840.0);
//            p2 = b + frac((p2 + 1.0) * 0.00390625) * float4(164352.0, -164352.0, 163840.0, -163840.0);
//
//            float4 f1 = frac(float4(x.x, x.x, x.x, x.x) + n3);
//            float4 f2 = frac(float4(x.y, x.y, x.y, x.y) + n3);
//
//            f1 = f1 * f1 * (3.0 - 2.0 * f1);
//            f2 = f2 * f2 * (3.0 - 2.0 * f2);
//
//            float4 n1 = float4(0.0, 1.0, 157.0, 158.0);
//            float4 n2 = float4(113.0, 114.0, 270.0, 271.0);
//
//            float4 vs1 = lerp(hash4(p1), hash4(n1.yyyy + p1), f1);
//            float4 vs2 = lerp(hash4(n1.zzzz + p1), hash4(n1.wwww + p1), f1);
//            float4 vs3 = lerp(hash4(p2), hash4(n1.yyyy + p2), f1);
//            float4 vs4 = lerp(hash4(n1.zzzz + p2), hash4(n1.wwww + p2), f1);
//
//            vs1 = lerp(vs1, vs2, f2);
//            vs3 = lerp(vs3, vs4, f2);
//
//            vs2 = lerp(hash4(n2.xxxx + p1), hash4(n2.yyyy + p1), f1);
//            vs4 = lerp(hash4(n2.zzzz + p1), hash4(n2.wwww + p1), f1);
//            vs2 = lerp(vs2, vs4, f2);
//
//            vs4 = lerp(hash4(n2.xxxx + p2), hash4(n2.yyyy + p2), f1);
//            float4 vs5 = lerp(hash4(n2.zzzz + p2), hash4(n2.wwww + p2), f1);
//            vs4 = lerp(vs4, vs5, f2);
//
//            f1 = frac(float4(x.z, x.z, x.z, x.z) + n3);
//            f2 = frac(float4(x.w, x.w, x.w, x.w) + n3);
//            f1 = f1 * f1 * (3.0 - 2.0 * f1);
//            f2 = f2 * f2 * (3.0 - 2.0 * f2);
//
//            vs1 = lerp(vs1, vs2, f1);
//            vs3 = lerp(vs3, vs4, f1);
//            vs1 = lerp(vs1, vs3, f2);
//
//            float r = dot(vs1, float4(0.25, 0.25, 0.25, 0.25));
//            return r * r * (3.0 - 2.0 * r);
//        }
//
//        // ---------- noise on/in sphere ----------
//        float noiseSpere(float3 ray, float3 pos, float r, float3x3 mr, float zoom, float3 subnoise, float anim)
//        {
//            float b = dot(ray, pos);
//            float c = dot(pos, pos) - b * b;
//
//            float3 r1 = float3(0.0, 0.0, 0.0);
//            float s = 0.0;
//            float d = 0.03125;
//            float d2 = zoom / (d * d);
//            float ar = 5.0;
//            for (int i = 0; i < 3; i++)
//            {
//                float rq = r * r;
//                if (c < rq)
//                {
//                    float l1 = sqrt(rq - c);
//                    r1 = ray * (b - l1) - pos;
//                    r1 = mul(mr, r1); // r1 * mr in GLSL => mul(mr, r1) in HLSL
//                    s += abs(noise4q(float4(r1 * d2 + subnoise * ar, anim * ar)) * d);
//                }
//                ar -= 2.0;
//                d *= 4.0;
//                d2 *= 0.0625;
//                r = r - r * 0.02;
//            }
//            return s;
//        }
//
//        float ringFunc(float3 ray, float3 pos, float r, float size)
//        {
//            float b = dot(ray, pos);
//            float c = dot(pos, pos) - b * b;
//            float s = max(0.0, (1.0 - size * abs(r - sqrt(max(0.0, c)))));
//            return s;
//        }
//
//        float ringRayNoise(float3 ray, float3 pos, float r, float size, float3x3 mr, float anim)
//        {
//            float b = dot(ray, pos);
//            float3 pr = ray * b - pos;
//            float c = length(pr);
//            pr = mul(mr, pr);
//            pr = normalize(pr + 1e-6); // avoid zero
//            float s = max(0.0, (1.0 - size * abs(r - c)));
//
//            float nd = noise4q(float4(pr * 1.0, -anim + c)) * 2.0;
//            nd = pow(nd, 2.0);
//            float n = 0.4;
//            float ns = 1.0;
//            if (c > r) {
//                n = noise4q(float4(pr * 10.0, -anim + c));
//                ns = noise4q(float4(pr * 50.0, -anim * 2.5 + c * 2.0)) * 2.0;
//            }
//            n = n * n * nd * ns;
//            return pow(s, 4.0) + s * s * n;
//        }
//
//        float4 noiseSpace(float3 ray, float3 pos, float r, float3x3 mr, float zoom, float3 subnoise, float anim)
//        {
//            float b = dot(ray, pos);
//            float c = dot(pos, pos) - b * b;
//
//            float3 r1 = float3(0, 0, 0);
//            float s = 0.0;
//            float d = 0.0625 * 1.5;
//            float d2 = zoom / d;
//
//            float rq = r * r;
//            float l1 = sqrt(abs(rq - c));
//            r1 = (ray * (b - l1) - pos);
//            r1 = mul(mr, r1);
//
//            r1 *= d2;
//            float t0 = abs(noise4q(float4(r1 + subnoise, anim))) * d;
//            float t1 = abs(noise4q(float4(r1 * 0.5 + subnoise, anim))) * d * 2.0;
//            float t2 = abs(noise4q(float4(r1 * 0.25 + subnoise, anim))) * d * 4.0;
//            s += t0 + t1 + t2;
//
//            float a = abs(noise4q(float4(r1 * 0.1 + subnoise, anim)));
//            float b2 = abs(noise4q(float4(r1 * 0.1 + subnoise * 6.0, anim)));
//            float c2 = abs(noise4q(float4(r1 * 0.1 + subnoise * 13.0, anim)));
//            return float4(s * 2.0, a, b2, c2);
//        }
//
//        float sphereZero(float3 ray, float3 pos, float r)
//        {
//            float b = dot(ray, pos);
//            float c = dot(pos, pos) - b * b;
//            float s = 1.0;
//            if (c < r * r) s = 0.0;
//            return s;
//        }
//
//        // ---------- fragment ----------
//        float4 frag(v2f i) : SV_Target
//        {
//            // object-space camera pos
//            float3 camOS = mul((float3x3)unity_WorldToObject, _WorldSpaceCameraPos) + float3(unity_WorldToObject._m03, unity_WorldToObject._m13, unity_WorldToObject._m23);
//            // safer: transform full vector
//            camOS = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1)).xyz;
//
//            // compute ray from camera through this fragment's object-space position
//            float3 fragPosOS = i.posOS;
//            float3 ray = normalize(fragPosOS - camOS);
//
//            // rotation matrices based on some time-driven angles (approximate original)
//            float time = _Time.x;
//            float mx = time * 0.025;
//            float my = -0.6; // static tilt, could be exposed
//
//            float sx = sin(mx), cx = cos(mx);
//            float sy = sin(my), cy = cos(my);
//
//            float3x3 mr;
//            mr[0] = float3(cx, 0.0, sx);
//            mr[1] = float3(0.0, 1.0, 0.0);
//            mr[2] = float3(-sx, 0.0, cx);
//            mr = mul(float3x3(1,0,0, 0,cy,sy, 0,-sy,cy), mr);
//
//            float3x3 imr;
//            imr[0] = float3(cx, 0.0, -sx);
//            imr[1] = float3(0.0, 1.0, 0.0);
//            imr[2] = float3(sx, 0.0, cx);
//            imr = mul(imr, float3x3(1,0,0, 0,cy,-sy, 0,sy,cy));
//
//            // sphere center (object space) is 0, so pos vector from camera to center:
//            float3 pos = -camOS;
//
//            // compute ray-sphere intersection helper values
//            float b = dot(ray, pos);
//            float sqDist = dot(pos,pos);
//            float sphere = sqDist - b * b;
//            float sqRadius = _Radius * _Radius;
//
//            float3 pr = ray * abs(b) - pos;
//
//            float3 surfase = float3(0,0,0);
//            if (sqDist <= sqRadius) {
//                surfase = -pos;
//                sphere = sqDist;
//            }
//            else if (sphere < sqRadius) {
//                float l1 = sqrt(sqRadius - sphere);
//                surfase = mul(imr, pr - ray * l1); // approximate original: surfase = mul(m,pr - ray*l1);
//            }
//            else {
//                surfase = float3(0,0,0);
//            }
//
//            // Build color
//            float4 col = float4(0,0,0,0);
//
//            if (_Detail >= 1)
//            {
//                float s1 = noiseSpere(ray, pos, _Radius, mr, 0.5 * _Zoom, float3(45.78,113.04,28.957) * _Seed, time * _SpeedLow);
//                s1 = pow(min(1.0, s1 * 2.4), 2.0);
//                float s2 = noiseSpere(ray, pos, _Radius, mr, 4.0 * _Zoom, float3(83.23,34.34,67.453) * _Seed, time * _SpeedHi);
//                s2 = min(1.0, s2 * 2.2);
//
//                float3 col1 = lerp(_MainColor.rgb, _MainLight.rgb, pow(s1, 60.0)) * s1;
//                float3 col2 = lerp(lerp(_Base.rgb, _Dark.rgb, s2 * s2), _MainLight.rgb, pow(s2, 10.0)) * s2;
//                col.rgb = col1 + col2;
//                col.a = 1.0;
//            }
//
//            // rings and rays
//            float cdist = length(pr) * _Zoom;
//            pr = normalize(mul(imr, pr));
//            float s = max(0.0, (1.0 - abs(_Radius * _Zoom - cdist) / _RayString));
//            float nd = noise4q(float4(pr + float3(83.23, 34.34, 67.453) * _Seed, -time * _SpeedRing + cdist)) * 2.0;
//            nd = pow(nd, 2.0);
//            float dr = 1.0;
//            if (sphere < sqRadius) dr = sphere / sqRadius;
//            pr *= 10.0;
//            float n = noise4q(float4(pr + float3(83.23, 34.34, 67.453) * _Seed, -time * _SpeedRing + cdist)) * dr;
//            pr *= 5.0;
//            float ns = noise4q(float4(pr + float3(83.23, 34.34, 67.453) * _Seed, -time * _SpeedRay + cdist)) * 2.0 * dr;
//            if (_Detail >= 3)
//            {
//                pr *= 3.0;
//                ns = ns * 0.5 + noise4q(float4(pr + float3(83.23, 34.34, 67.453) * _Seed, -time * _SpeedRay + 0)) * dr;
//            }
//            n = pow(n, _Rays) * pow(nd, _RayRing) * ns;
//            float s3 = pow(s, _Glow) + pow(s, _RayGlow) * n;
//
//            if (sphere < sqRadius) col.a = 1.0 - s3 * dr;
//            if (sqDist > sqRadius)
//            {
//                col.rgb += lerp(_RayEnd.rgb, _RayLight.rgb, s3 * s3 * s3) * s3;
//            }
//
//            col = saturate(col);
//
//            // outside small additional nebula / noise
//            float zero = sphereZero(ray, pos, _Radius * 0.9);
//            if (zero > 0.0)
//            {
//                float4 s4 = noiseSpace(ray, pos, 100.0, mr, 0.05, float3(1.0, 2.0, 4.0), 0.0);
//                s4.x = pow(s4.x, 3.0);
//                float3 addc = lerp(lerp(float3(1,0,0), float3(0,0,1), s4.y * 1.9), float3(0.9,1.0,0.1), s4.w * 0.75) * s4.x * pow(s4.z * 2.5, 3.0) * 0.2 * zero;
//                col.rgb += addc;
//            }
//
//            col = clamp(col, 0.0, 1.0);
//            return col;
//        }
//
//        ENDHLSL
//    }
//    }
//}
//Shader "Custom/ShiningSunSphere"
//{
//    Properties
//    {
//        _CoreColor("Core Color", Color) = (1.0, 1.0, 0.0, 1.0)
//        _OuterColor("Outer Color", Color) = (1.0, 0.0, 0.0, 1.0)
//        _Speed("Animation Speed", Range(0, 5)) = 1.0
//        _Density("Sun Density", Range(0, 10)) = 1.0
//        _Zoom("Zoom/Frequency", Range(0.1, 5.0)) = 1.0
//        _RimPower("Rim Power", Range(0.5, 8.0)) = 3.0
//    }
//        SubShader
//    {
//        Tags { "RenderType" = "Opaque" }
//        LOD 100
//
//        Pass
//        {
//            CGPROGRAM
//            #pragma vertex vert
//            #pragma fragment frag
//            #include "UnityCG.cginc"
//
//            struct appdata
//            {
//                float4 vertex : POSITION;
//                float3 normal : NORMAL;
//            };
//
//            struct v2f
//            {
//                float4 vertex : SV_POSITION;
//                float3 objPos : TEXCOORD0; // 3D Position for Noise
//                float3 normal : TEXCOORD1;
//                float3 viewDir : TEXCOORD3;
//            };
//
//            float4 _CoreColor;
//            float4 _OuterColor;
//            float _Speed;
//            float _Density;
//            float _Zoom;
//            float _RimPower;
//
//            // --- GLSL Helper Defines ---
//            #define vec2 float2
//            #define vec3 float3
//            #define vec4 float4
//            #define mat3 float3x3
//            #define mix lerp
//            #define fract frac
//
//            // --- Noise Functions ---
//            vec4 hash4(vec4 n) { return fract(sin(n) * 1399763.5453123); }
//
//            float noise4q(vec4 x)
//            {
//                vec4 n3 = vec4(0, 0.25, 0.5, 0.75);
//                vec4 p2 = floor(x.wwww + n3);
//                vec4 b = floor(x.xxxx + n3) + floor(x.yyyy + n3) * 157.0 + floor(x.zzzz + n3) * 113.0;
//                vec4 p1 = b + fract(p2 * 0.00390625) * vec4(164352.0, -164352.0, 163840.0, -163840.0);
//                p2 = b + fract((p2 + 1.0) * 0.00390625) * vec4(164352.0, -164352.0, 163840.0, -163840.0);
//
//                vec4 f1 = fract(x.xxxx + n3);
//                vec4 f2 = fract(x.yyyy + n3);
//
//                f1 = f1 * f1 * (3.0 - 2.0 * f1);
//                f2 = f2 * f2 * (3.0 - 2.0 * f2);
//
//                vec4 n1 = vec4(0, 1.0, 157.0, 158.0);
//                vec4 n2 = vec4(113.0, 114.0, 270.0, 271.0);
//
//                vec4 vs1 = mix(hash4(p1), hash4(n1.yyyy + p1), f1);
//                vec4 vs2 = mix(hash4(n1.zzzz + p1), hash4(n1.wwww + p1), f1);
//                vec4 vs3 = mix(hash4(p2), hash4(n1.yyyy + p2), f1);
//                vec4 vs4 = mix(hash4(n1.zzzz + p2), hash4(n1.wwww + p2), f1);
//
//                vs1 = mix(vs1, vs2, f2);
//                vs3 = mix(vs3, vs4, f2);
//
//                vs2 = mix(hash4(n2.xxxx + p1), hash4(n2.yyyy + p1), f1);
//                vs4 = mix(hash4(n2.zzzz + p1), hash4(n2.wwww + p1), f1);
//
//                vs2 = mix(vs2, vs4, f2);
//                vs4 = mix(hash4(n2.xxxx + p2), hash4(n2.yyyy + p2), f1);
//                vec4 vs5 = mix(hash4(n2.zzzz + p2), hash4(n2.wwww + p2), f1);
//
//                vs4 = mix(vs4, vs5, f2);
//
//                f1 = fract(x.zzzz + n3);
//                f2 = fract(x.wwww + n3);
//
//                f1 = f1 * f1 * (3.0 - 2.0 * f1);
//                f2 = f2 * f2 * (3.0 - 2.0 * f2);
//
//                vs1 = mix(vs1, vs2, f1);
//                vs3 = mix(vs3, vs4, f1);
//                vs1 = mix(vs1, vs3, f2);
//
//                float r = dot(vs1, vec4(0.25, 0.25, 0.25, 0.25));
//                return r * r * (3.0 - 2.0 * r);
//            }
//
//            // Simplified Surface Noise (No raymarching intersection)
//            float surfaceNoise(vec3 pos, mat3 mr, float zoom, vec3 subnoise, float anim)
//            {
//                vec3 r1 = mul(pos, mr); // Rotate the position
//                float s = 0.0;
//                float d = 0.03125;
//                float d2 = zoom / (d * d); // Scale modifier
//                float ar = 5.0;
//
//                // Octaves of noise
//                for (int i = 0; i < 3; i++) {
//                    s += abs(noise4q(vec4(r1 * d2 + subnoise * ar, anim * ar)) * d);
//                    ar -= 2.0;
//                    d *= 4.0;
//                    d2 *= 0.0625;
//                }
//                return s;
//            }
//
//            v2f vert(appdata v)
//            {
//                v2f o;
//                o.vertex = UnityObjectToClipPos(v.vertex);
//                o.objPos = v.vertex.xyz; // Pass 3D Object Position
//                o.normal = UnityObjectToWorldNormal(v.normal);
//
//                // Calculate View Direction for Fresnel
//                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
//                o.viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
//
//                return o;
//            }
//
//            fixed4 frag(v2f i) : SV_Target
//            {
//                float time = _Time.y * _Speed;
//
//            // Rotation Matrices for the noise field
//            float mx = time * 0.025;
//            float my = -0.6;
//            float2 rotate = float2(mx, my);
//            float2 sins = sin(rotate);
//            float2 coss = cos(rotate);
//
//            mat3 mr = mat3(
//                vec3(coss.x, 0.0, sins.x),
//                vec3(0.0, 1.0, 0.0),
//                vec3(-sins.x, 0.0, coss.x)
//            );
//            mr = mul(mat3(
//                vec3(1.0, 0.0, 0.0),
//                vec3(0.0, coss.y, sins.y),
//                vec3(0.0, -sins.y, coss.y)
//            ), mr);
//
//            // Use Normalized Object Position as the "Ray" direction for mapping
//            vec3 pos = normalize(i.objPos);
//
//            // 1. Core Noise Layer
//            float s1 = surfaceNoise(pos, mr, 0.5, vec3(0.0,0.0,0.0), time);
//            s1 = pow(min(1.0, s1 * 2.4), 2.0);
//
//            // 2. Outer/Detail Noise Layer
//            float s2 = surfaceNoise(pos, mr, 4.0, vec3(83.23, 34.34, 67.453), time);
//            s2 = min(1.0, s2 * 2.2);
//
//            // Mix Colors
//            vec3 col = mix(_CoreColor.rgb, vec3(1.0,1.0,1.0), pow(s1, 60.0)) * s1;
//            col += mix(mix(_OuterColor.rgb, vec3(1.0, 0.0, 1.0), pow(s2, 2.0)), vec3(1.0,1.0,1.0), pow(s2, 10.0)) * s2;
//
//            // 3. Fresnel / Rim Effect (Simulates the glowing edge on a sphere)
//            float fresnel = 1.0 - saturate(dot(normalize(i.normal), normalize(i.viewDir)));
//            fresnel = pow(fresnel, _RimPower);
//
//            // Add Fresnel glow to edge
//            col += _OuterColor.rgb * fresnel * 2.0;
//
//            return float4(col * _Density, 1.0);
//        }
//        ENDCG
//    }
//    }
//}