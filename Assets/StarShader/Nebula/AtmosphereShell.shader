Shader "Custom/AtmosphereShell_DayNightMask"
{
    Properties
    {
        [Header(Base Appearance)]
        _FogColor   ("Fog Color", Color) = (0.4, 0.7, 1.0, 1)
        _Density    ("Density", Float)       = 2.0
        _NoiseScale ("Noise Scale", Float)   = 0.6
        _Steps      ("Raymarch Steps", Range(8,256)) = 80
        _Brightness ("Brightness", Float)    = 1.8
        _Extinction ("Extinction", Float)    = 1.2
        _Threshold  ("Density Threshold", Range(0,1)) = 0.35

        [Header(Day Night Mask)]
        // --- 新增：控制云层在背光面消失的过渡柔和度 ---
        // 范围越小边界越硬，范围越大过渡越宽
        _TerminatorSoftness ("Terminator Softness", Range(0.01, 0.5)) = 0.2
        // --- 新增：偏移晨昏线位置 ---
        // 0.0 = 正好90度位置，正值 = 云层延伸到黑夜一点，负值 = 云层提前在白天结束
        _TerminatorOffset ("Terminator Offset", Range(-0.5, 0.5)) = -0.1

        [Header(Animation)]
        _CloudSpeed ("Cloud Move Speed", Float) = 0.1
        _WarpSpeed  ("Cloud Warp Speed", Float) = 0.05

        [Header(Domain Warping)]
        _WarpStrength ("Warp Strength", Range(0,2)) = 0.8
        _WarpScale    ("Warp Scale",   Float)       = 1.0

        [Header(Geometry)]
        _Radius       ("Sphere Radius (OS)", Float) = 0.5
        _ShellStart   ("Shell Start (0-1)", Range(0,1)) = 0.7
        _ShellSoft    ("Shell Softness",    Range(0.001,0.5)) = 0.15

        [Header(Lighting)]
        _LightDir   ("Light Direction", Vector) = (0.2, -0.6, -0.7, 0)
        _LightColor ("Light Color", Color)      = (1, 1, 1, 1)
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

            float4 _FogColor;

            float  _Density;
            float  _NoiseScale;
            float  _Steps;
            float  _Brightness;
            float  _Extinction;
            float  _Threshold;

            float  _TerminatorSoftness; // 新增
            float  _TerminatorOffset;   // 新增

            float  _CloudSpeed;
            float  _WarpSpeed;

            float  _WarpStrength;
            float  _WarpScale;
            float  _Radius;

            float  _ShellStart;
            float  _ShellSoft;

            float3 _LightDir;
            float4 _LightColor;
            float  _Anisotropy;

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

            // ------------ 噪声 (保持不变) ------------
            float hash(float3 p) {
                p = frac(p * 0.3183099 + 0.1);
                return frac(p.x * p.y * p.z * 95.433);
            }
            float noise(float3 p) {
                float3 i = floor(p); float3 f = frac(p); float3 u = f * f * (3.0 - 2.0 * f);
                float a = hash(i); float b = hash(i + float3(1,0,0)); float c = hash(i + float3(0,1,0)); float d = hash(i + float3(1,1,0));
                float e = hash(i + float3(0,0,1)); float f1 = hash(i + float3(1,0,1)); float g = hash(i + float3(0,1,1)); float h = hash(i + float3(1,1,1));
                float nx00 = lerp(a, b, u.x); float nx10 = lerp(c, d, u.x); float nx01 = lerp(e, f1, u.x); float nx11 = lerp(g, h, u.x);
                float nxy0 = lerp(nx00, nx10, u.y); float nxy1 = lerp(nx01, nx11, u.y);
                return lerp(nxy0, nxy1, u.z);
            }
            float fbm(float3 p) {
                float v = 0.0; float amp = 0.5;
                [unroll] for (int i = 0; i < 4; i++) { v += noise(p) * amp; p *= 2.0; amp *= 0.5; }
                return v;
            }

            float phaseHG(float cosTheta, float g)
            {
                float g2 = g * g;
                return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
            }

            bool RaySphereIntersect(float3 ro, float3 rd, float radius, out float tEnter, out float tExit)
            {
                float b = dot(ro, rd); float c = dot(ro, ro) - radius * radius; float disc = b * b - c;
                if (disc <= 0.0) { tEnter = 0.0; tExit = 0.0; return false; }
                float sdisc = sqrt(disc); tEnter = max(-b - sdisc, 0.0); tExit = -b + sdisc;
                return tExit > tEnter;
            }

            float4 frag (Varyings i) : SV_Target
            {
                float3 camWS = _WorldSpaceCameraPos;
                float3 roWS  = camWS;
                float3 rdWS  = normalize(i.posWS - camWS);

                float3 roOS = mul(unity_WorldToObject, float4(roWS, 1.0)).xyz;
                float3 rdOS = normalize(mul((float3x3)unity_WorldToObject, rdWS));

                float tEnter, tExit;
                if (!RaySphereIntersect(roOS, rdOS, _Radius, tEnter, tExit))
                    return float4(0,0,0,0);

                int   steps    = (int)_Steps;
                float dist     = tExit - tEnter;
                float stepSize = dist / max((float)steps, 1.0);

                float3 lightDir      = normalize(_LightDir);
                float3 accum         = 0;
                float  transmittance = 1.0;

                float t = tEnter;

                float3 cloudMoveOffset = float3(_Time.y * _CloudSpeed, 0, _Time.y * _CloudSpeed * 0.2);
                float3 warpMoveOffset  = float3(_Time.y * _WarpSpeed, _Time.y * _WarpSpeed * 0.5, 0);

                [loop]
                for (int s = 0; s < steps; s++)
                {
                    float3 p = roOS + rdOS * t; 

                    float r      = length(p);
                    float rNorm  = saturate(r / max(_Radius, 1e-4));

                    float shellMask = smoothstep(_ShellStart,
                                                 min(1.0, _ShellStart + _ShellSoft),
                                                 rNorm);

                    if (shellMask > 0.0)
                    {
                        // ==========================================================
                        // ?? 光照遮罩计算 (Day/Night Mask)
                        // ==========================================================
                        // p 是物体空间的点，(0,0,0) 是球心。
                        // normalize(p) 就是该点的法线方向。
                        float3 pDir = normalize(p);
                        
                        // 计算当前点与光照方向的对齐程度
                        // dot > 0 表示向光，dot < 0 表示背光
                        float sunDot = dot(pDir, lightDir);
                        
                        // 计算遮罩：
                        // 使用 _TerminatorOffset 允许云层稍微越过中线或者提前结束
                        // 使用 _TerminatorSoftness 进行平滑过渡
                        float dayNightMask = smoothstep(
                            _TerminatorOffset - _TerminatorSoftness, 
                            _TerminatorOffset + _TerminatorSoftness, 
                            sunDot
                        );

                        // 只有在白天 mask > 0 时才计算昂贵的噪声
                        if (dayNightMask > 0.01)
                        {
                            float3 pNorm = p / _Radius; 

                            float3 warpPos = pNorm * _WarpScale + warpMoveOffset;
                            float3 warp = float3(fbm(warpPos+13.1), fbm(warpPos+37.2), fbm(warpPos+73.5));
                            warp = (warp - 0.5) * 2.0 * _WarpStrength;

                            float3 noisePos = (pNorm + warp) * _NoiseScale + cloudMoveOffset;
                            float n = fbm(noisePos);
                            float d = saturate((n - _Threshold) * 3.0);

                            // 应用光照遮罩：背光面的密度直接乘 0
                            d *= dayNightMask;
                            d *= shellMask;
                            d *= _Density;

                            if (d > 0.001)
                            {
                                float3 fogCol = _FogColor.rgb;
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
                        }
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