Shader "Custom/Volumetric/BoxVolumeFog"
{
    Properties
    {
        _ColorA ("Fog Color A", Color) = (0.3, 0.7, 1.0, 1)
        _ColorB ("Fog Color B", Color) = (1.0, 0.4, 0.8, 1)
        _ColorC ("Fog Color C", Color) = (0.7, 1.0, 0.4, 1)
        _ColorD ("Fog Color D", Color) = (1.0, 1.0, 0.6, 1)
          
        _ColorModeScale ("Color Noise Scale", Float) = 0.8

        _Density    ("Density", Float)       = 2.0
        _NoiseScale ("Noise Scale", Float)   = 0.6
        _Steps      ("Raymarch Steps", Range(8,256)) = 80
        _Brightness ("Brightness", Float)    = 1.8
        _Extinction ("Extinction", Float)    = 1.2

        _Threshold  ("Density Threshold", Range(0,1)) = 0.35

        // 域扭曲（让形状更随机）
        _WarpStrength ("Warp Strength", Range(0,2)) = 0.8
        _WarpScale    ("Warp Scale",   Float)       = 1.0

        // Box 半尺寸（Object Space）
        _BoxSize      ("Box Half Size", Vector) = (0.5, 0.5, 0.5, 0)

        // 体积光
        _LightDir   ("Light Direction", Vector) = (0.2, -0.6, -0.7, 0)
        _LightColor ("Light Color", Color)      = (1, 1, 1, 1)
        _Anisotropy ("Anisotropy g", Range(-0.9,0.9)) = 0.6

        _EdgeFade ("Edge Fade (0-1)", Range(0,1)) = 0.3

        //Star
        _StarColor      ("Star Color", Color)            = (1, 1, 1, 1)
        _StarIntensity  ("Star Intensity", Float)        = 5.0
        _StarNoiseScale ("Star Noise Scale", Float)      = 4.0
        _StarThreshold  ("Star Threshold (0-1)", Range(0,1)) = 0.92
        _StarSharpness  ("Star Sharpness", Float)        = 20.0


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

            float4 _ColorA;
            float4 _ColorB;

            float  _Density;
            float  _NoiseScale;
            float  _Steps;
            float  _Brightness;
            float  _Extinction;
            float  _Threshold;

            float  _WarpStrength;
            float  _WarpScale;
            float4 _BoxSize;

            float3 _LightDir;
            float4 _LightColor;
            float  _Anisotropy;

            float  _EdgeFade;

            float4 _StarColor;
            float  _StarIntensity;
            float  _StarNoiseScale;
            float  _StarThreshold;
            float  _StarSharpness;


            struct Attributes
            {
                float4 positionOS : POSITION;
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

            // ------------ 噪声 ------------
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

            // Henyey-Greenstein 相函数
            float phaseHG(float cosTheta, float g)
            {
                float g2 = g * g;
                return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
            }

            // Ray 与 AABB 求交（Object Space，下为中心在 0 的 Box）
            bool RayBoxIntersect(float3 ro, float3 rd, float3 boxHalfSize,
                                 out float tEnter, out float tExit)
            {
                float3 boxMin = -boxHalfSize;
                float3 boxMax =  boxHalfSize;

                float3 invDir = 1.0 / max(abs(rd), 1e-6) * sign(rd); // 避免除零
                float3 t0s = (boxMin - ro) * invDir;
                float3 t1s = (boxMax - ro) * invDir;

                float3 tsmaller = min(t0s, t1s);
                float3 tbigger  = max(t0s, t1s);

                tEnter = max(tsmaller.x, max(tsmaller.y, tsmaller.z));
                tExit  = min(tbigger.x,  min(tbigger.y,  tbigger.z));

                return tExit > max(tEnter, 0.0);
            }

            float4 frag (Varyings i) : SV_Target
            {
                // --- 世界空间 ray ---
                float3 camWS = _WorldSpaceCameraPos;
                float3 roWS  = camWS;
                float3 rdWS  = normalize(i.posWS - camWS);

                // --- 转到 Object Space ---
                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                // --- 和 Box 求交 ---
                float tEnter, tExit;
                if (!RayBoxIntersect(roOS, rdOS, _BoxSize.xyz, tEnter, tExit))
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
                    float3 p = roOS + rdOS * t;  // 当前采样点（Box 内的 Object Space）

                    // 归一化到 box [-1,1] 范围，方便噪声取样
                    float3 pNorm = p / _BoxSize.xyz;

                    // --- 域扭曲 ---
                    float3 warpPos = pNorm * _WarpScale;
                    float3 warp = float3(
                        fbm(warpPos + 13.1),
                        fbm(warpPos + 37.2),
                        fbm(warpPos + 73.5)
                    );
                    warp = (warp - 0.5) * 2.0 * _WarpStrength;
                    pNorm += warp;

                    // --- 噪声密度 ---
                    float n = fbm(pNorm * _NoiseScale);
                    // --- 边缘淡出：让靠近 Box 边界的地方密度逐渐变 0 ---
                    // borderDist：三轴方向到最近面的大致“剩余空间” [0,1]
                    float3 borderDist = 1.0 - abs(pNorm);          // 在面上为 0，中心附近最大
                    float  distToEdge = min(borderDist.x, min(borderDist.y, borderDist.z)); // 距离最近一个面

                    // 用 smoothstep 从 0 到 _EdgeFade 做渐隐：
                    // distToEdge <= 0 -> edgeFade = 0（在面上完全消失）
                    // distToEdge >= _EdgeFade -> edgeFade ≈ 1（离边界足够远，不受影响）
                    float edgeFade = smoothstep(0.0, max(_EdgeFade, 1e-4), distToEdge);


                    // 阈值+对比度
                    float d = saturate((n - _Threshold) * 3.0);
                    d *= edgeFade;    // 先乘边缘淡出
                    d *= _Density;    // 再乘整体密度


                    // 用另一层较高频的噪声，只决定“是不是星星”
                    float nStar = fbm(pNorm * _StarNoiseScale + 456.7);
                    float starMask = saturate((nStar - _StarThreshold) / max(1e-3, 1.0 - _StarThreshold));
                    starMask = pow(starMask, _StarSharpness);   // 让星星更像针尖点





                    if (d > 0.001)
                    {
                        // 颜色：用噪声做插值
                        float colorT = saturate(n * 1.2);
                        float3 fogCol = lerp(_ColorA.rgb, _ColorB.rgb, colorT);

                        // 体积光
                        float cosTheta = dot(rdOS, -lightDir);
                        float phase    = phaseHG(cosTheta, _Anisotropy);

                        float sigma      = d * _Extinction;
                        float absorption = exp(-sigma * stepSize);
                        float delta      = transmittance * (1.0 - absorption);

                        accum         += fogCol * _LightColor.rgb * phase * delta;
                        transmittance *= absorption;

                        if (transmittance < 0.01)
                            break;
                    }

                    //Star emit
                    if (starMask > 0.0 && transmittance > 0.0)
                    {
                        // 星星不依赖雾密度，可以出现在密度高/低的地方
                        // 这里我们把它当成各向同性自发光：L = StarColor * intensity
                        float starEmission = _StarIntensity * starMask;

                        // 同样要考虑当前透光率 & 步长，否则越远越亮不对
                        float starDelta = transmittance * starEmission * stepSize;

                        accum += _StarColor.rgb * starDelta;
                        // 注意：星星本身不额外吸收光，所以不改变 transmittance
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

