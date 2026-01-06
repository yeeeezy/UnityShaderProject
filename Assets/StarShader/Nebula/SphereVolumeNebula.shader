Shader "Custom/Nebula/SphereVolumeNebula"
{
    Properties
    {
        // 颜色分层：核心 / 壳体 / 外圈
        _ColorCore  ("Core Color",  Color) = (0.3, 0.8, 1.0, 1)
        _ColorRing  ("Ring Color",  Color) = (1.0, 0.4, 0.8, 1)
        _ColorOuter ("Outer Color", Color) = (0.05, 0.02, 0.08, 1)

        // 几何与密度（注意：Radius 在物体空间，默认 Sphere 半径约为 0.5）
        _Radius     ("Nebula Radius", Float)        = 0.5
        _RingInnerRadius ("Ring Inner Radius", Float) = 0.2
        _RingOuterRadius ("Ring Outer Radius", Float) = 0.48

        _Density    ("Density", Float)       = 2.0
        _NoiseScale ("Noise Scale", Float)   = 0.4
        _Steps      ("Raymarch Steps", Range(16,256)) = 96
        _Brightness ("Brightness", Float)    = 2.0
        _Extinction ("Extinction", Float)    = 1.3

        // 尘埃裂缝
        _DustStrength ("Dust Strength", Range(0,2)) = 0.8
        _DustScale    ("Dust Noise Scale", Float)   = 2.0

        // 域扭曲（打破圆形）
        _WarpStrength ("Domain Warp Strength", Range(0,2)) = 0.8
        _WarpScale    ("Domain Warp Scale",   Float)       = 0.7

        // 椭球缩放（整体变扁/拉长）
        _AnisoScale   ("Ellipsoid Scale XYZ", Vector) = (1.0, 0.7, 1.3, 0)

        // 靠近球面的边缘淡出，0~1 越大淡出越早
        _EdgeFade ("Edge Fade (0-1)", Range(0,1)) = 0.3

        // 体积光
        _LightDir   ("Light Direction", Vector) = (0.2, -0.6, -0.7, 0)
        _LightColor ("Light Color", Color)      = (1.1, 0.95, 0.9, 1)
        _Anisotropy ("Anisotropy g", Range(-0.9,0.9)) = 0.6
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Transparent"
            "RenderType"     = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target   4.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _ColorCore;
            float4 _ColorRing;
            float4 _ColorOuter;

            float  _Radius;
            float  _RingInnerRadius;
            float  _RingOuterRadius;

            float  _Density;
            float  _NoiseScale;
            float  _Steps;
            float  _Brightness;
            float  _Extinction;

            float  _DustStrength;
            float  _DustScale;

            float  _WarpStrength;
            float  _WarpScale;
            float4 _AnisoScale;

            float  _EdgeFade;

            float3 _LightDir;
            float4 _LightColor;
            float  _Anisotropy;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 posWS      : TEXCOORD0;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                float3 posWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionCS = TransformWorldToHClip(posWS);
                o.posWS      = posWS;
                return o;
            }

            // -------- 噪声 & fbm --------
            float hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                return frac(p.x * p.y * p.z * 95.433);
            }

            float noise(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);

                float a  = hash(i);
                float b  = hash(i + float3(1,0,0));
                float c  = hash(i + float3(0,1,0));
                float d  = hash(i + float3(1,1,0));
                float e  = hash(i + float3(0,0,1));
                float f1 = hash(i + float3(1,0,1));
                float g  = hash(i + float3(0,1,1));
                float h  = hash(i + float3(1,1,1));

                float3 u = f * f * (3.0 - 2.0 * f);

                float nx00 = lerp(a,  b,  u.x);
                float nx10 = lerp(c,  d,  u.x);
                float nx01 = lerp(e,  f1, u.x);
                float nx11 = lerp(g,  h,  u.x);

                float nxy0 = lerp(nx00, nx10, u.y);
                float nxy1 = lerp(nx01, nx11, u.y);

                return lerp(nxy0, nxy1, u.z);
            }

            float fbm(float3 p)
            {
                float v   = 0.0;
                float amp = 0.5;

                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    v   += noise(p) * amp;
                    p   *= 2.0;
                    amp *= 0.5;
                }
                return v;
            }

            // HG 相函数
            float phaseHG(float cosTheta, float g)
            {
                float g2 = g * g;
                return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
            }

            // ray-sphere 求交（球心在原点，半径 radius，坐标都在物体空间）
            bool RaySphere(float3 ro, float3 rd, float radius, out float tEnter, out float tExit)
            {
                float b = dot(ro, rd);
                float c = dot(ro, ro) - radius * radius;
                float disc = b * b - c;
                if (disc < 0.0)
                {
                    tEnter = tExit = 0.0;
                    return false;
                }

                float s = sqrt(disc);
                float t0 = -b - s;
                float t1 = -b + s;

                tEnter = t0;
                tExit  = t1;

                if (t1 < 0.0)
                    return false;

                return true;
            }

            float4 frag (Varyings i) : SV_Target
            {
                // 1. 世界空间 ray
                float3 camWS = _WorldSpaceCameraPos;
                float3 roWS  = camWS;
                float3 rdWS  = normalize(i.posWS - camWS);

                // 2. 转到物体空间
                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                // 3. 与体积球相交
                float tEnter, tExit;
                if (!RaySphere(roOS, rdOS, _Radius, tEnter, tExit))
                    return float4(0,0,0,0);

                tEnter = max(tEnter, 0.0);

                int   steps    = (int)_Steps;
                float dist     = tExit - tEnter;
                float stepSize = dist / max((float)steps, 1.0);

                float3 lightDir      = normalize(_LightDir);
                float3 accum         = 0;
                float  transmittance = 1.0;

                float t = tEnter;

                [loop]
                for (int s = 0; s < steps; s++)
                {
                    float3 p = roOS + rdOS * t;    // 物体空间采样点

                    // --- 1. 椭球缩放 ---
                    float3 pEllip = p * _AnisoScale.xyz;

                    // --- 2. 域扭曲（domain warping） ---
                    float3 warpPos = pEllip * _WarpScale;
                    float3 warp = float3(
                        fbm(warpPos + 13.1),
                        fbm(warpPos + 37.2),
                        fbm(warpPos + 73.5)
                    );
                    warp = (warp - 0.5) * 2.0 * _WarpStrength;
                    pEllip += warp;

                    // 半径用扭曲后的坐标
                    float r = length(pEllip);

                    // --- 3. 壳形：先用 min/max 自动纠正内外半径 ---
                    float inner = min(_RingInnerRadius, _RingOuterRadius);
                    float outer = max(_RingInnerRadius, _RingOuterRadius);
                    outer = min(outer, _Radius * 0.999);   // 外半径不超过体积球

                    float shellWidth = max((outer - inner) * 0.4, 0.001);

                    float innerStep = smoothstep(inner - shellWidth, inner + shellWidth, r);
                    float outerStep = 1.0 - smoothstep(outer - shellWidth, outer + shellWidth, r);
                    float shellFactor = saturate(innerStep * outerStep);

                    // --- 4. 噪声 & 尘埃 ---
                    float baseNoise = fbm(pEllip * _NoiseScale);
                    baseNoise = saturate((baseNoise - 0.35) * 2.2);

                    float detailNoise = fbm(pEllip * (_NoiseScale * 2.5) + 17.3);
                    detailNoise = detailNoise * 0.5 + 0.5;

                    float dustNoise = fbm(pEllip * _DustScale + 39.7);
                    float dustMask  = saturate(1.0 - dustNoise * _DustStrength);

                    // --- 5. 球壳外缘淡出：避免看到硬球轮廓 ---
                    float fadeStart = _Radius * (1.0 - _EdgeFade);  // 从某个半径开始渐隐
                    float edgeFade  = 1.0 - smoothstep(fadeStart, _Radius, r);
                    edgeFade = saturate(edgeFade);

                    float d = baseNoise * detailNoise * shellFactor * dustMask * edgeFade;
                    d *= _Density;

                    if (d > 0.001)
                    {
                        // --- 6. 颜色：半径 + 噪声共同控制 ---
                        float ringT = saturate( (r - inner) / max(outer - inner, 0.001) );
                        float3 coreToRing = lerp(_ColorCore.rgb, _ColorRing.rgb, ringT);

                        float outerT = smoothstep(outer, outer * 1.4, r);
                        float3 baseCol = lerp(coreToRing, _ColorOuter.rgb, outerT);

                        float colorNoise = fbm(pEllip * (_NoiseScale * 1.3) + 91.7);
                        float3 noisyCol  = lerp(baseCol, _ColorRing.rgb, colorNoise * 0.7);

                        float3 nebulaCol = noisyCol * (0.4 + d * 1.6);

                        // --- 7. 体积光 ---
                        float cosTheta = dot(rdOS, -lightDir);
                        float intensity = phaseHG(cosTheta, _Anisotropy);

                        float sigma      = d * _Extinction;
                        float absorption = exp(-sigma * stepSize);
                        float delta      = transmittance * (1.0 - absorption);

                        accum         += nebulaCol * _LightColor.rgb * intensity * delta;
                        transmittance *= absorption;

                        if (transmittance < 0.01)
                            break;
                    }

                    t += stepSize;
                }

                float3 finalColor = accum * _Brightness;
                float  alpha      = saturate(1.0 - transmittance);
                return float4(finalColor, alpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}




