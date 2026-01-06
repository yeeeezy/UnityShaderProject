Shader "Custom/URP_ProceduralPlanet_Stochastic_Forest"
{
    Properties
    {
        [Header(Base Setup)]
        _CenterPos("Center Position", Vector) = (0,0,0,0)
        _ElevationMinMax("Elevation Min Max", Vector) = (0, 1, 0, 0)

        [Header(Lighting)]
        _ShadowStrength("Shadow Brightness", Range(0, 1)) = 0.0

        [Header(Procedural Detail)]
        _NoiseScale("Noise Scale", Float) = 20.0       
        _NoiseStrength("Noise Strength", Range(0,1)) = 0.5 

        [Header(Atmosphere)]
        _RimColor("Atmosphere Color", Color) = (0.2, 0.6, 1, 1)
        _RimPower("Atmosphere Power", Range(0.5, 8.0)) = 4.0

        [Header(Water)]
        _DeepOceanColor("Deep Ocean Color", Color) = (0,0.05,0.2,1)
        _DeepOceanHeight("Deep Ocean Height", Float) = 0.05
        _OceanColor("Ocean Color", Color) = (0,0.2,0.6,1)
        _OceanHeight("Ocean Height", Float) = 0.1
        
        [Header(Stochastic Settings)]
        _StochasticContrast("Stochastic Blend Contrast", Range(0.0, 1.0)) = 0.5

        [Header(Grass Texture)]
        _GrassTex("Grass Texture", 2D) = "white" {}
        _GrassScale("Grass Scale", Float) = 20.0
        _GrassHeight("Grass Height Limit", Float) = 0.3
        _GrassWidth("Grass Blend Width", Float) = 0.1

        // ========================================================
        // 新增：森林相关设置
        // ========================================================
        [Header(Forest in Grass)]
        _ForestTex("Forest Texture", 2D) = "green" {}
        _ForestScale("Forest Texture Scale", Float) = 25.0
        _ForestNoiseScale("Forest Distribution Scale", Float) = 15.0 // 控制森林色块的大小
        _ForestThreshold("Forest Threshold", Range(0, 1)) = 0.5      // 控制森林的多少 (越小森林越多)
        _ForestBlend("Forest Edge Blend", Range(0.01, 0.5)) = 0.1    // 控制森林边缘的模糊程度

        [Header(Rock Texture)]
        _RockTex("Rock Texture", 2D) = "gray" {}
        _RockScale("Rock Scale", Float) = 20.0
        _RockHeight("Rock Height Limit", Float) = 0.5
        _RockWidth("Rock Blend Width", Float) = 0.1

        [Header(Snow Texture)]
        _SnowTex("Snow Texture", 2D) = "white" {}
        _SnowScale("Snow Scale", Float) = 20.0
        _SnowWidth("Snow Blend Width", Float) = 0.1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry" }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // --- 噪声函数 (复用) ---
            float3 hash33(float3 p) {
                p = float3(dot(p,float3(127.1,311.7, 74.7)),dot(p,float3(269.5,183.3,246.1)),dot(p,float3(113.5,271.9,124.6)));
                return -1.0 + 2.0 * frac(sin(p)*43758.5453123);
            }
            float noise(float3 p) {
                float3 i = floor(p); float3 f = frac(p); float3 u = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(lerp(dot(hash33(i+float3(0,0,0)),f-float3(0,0,0)),dot(hash33(i+float3(1,0,0)),f-float3(1,0,0)),u.x),lerp(dot(hash33(i+float3(0,1,0)),f-float3(0,1,0)),dot(hash33(i+float3(1,1,0)),f-float3(1,1,0)),u.x),u.y),lerp(lerp(dot(hash33(i+float3(0,0,1)),f-float3(0,0,1)),dot(hash33(i+float3(1,0,1)),f-float3(1,0,1)),u.x),lerp(dot(hash33(i+float3(0,1,1)),f-float3(0,1,1)),dot(hash33(i+float3(1,1,1)),f-float3(1,1,1)),u.x),u.y),u.z);
            }
            float fbm(float3 p) {
                float total = 0.0; float amp = 0.5;
                for(int i=0; i<3; ++i) { total += noise(p)*amp; p*=2.0; amp*=0.5; }
                return total + 0.5;
            }

            // --- 随机采样核心算法 (Stochastic Sampling) ---
            float2 hash2D(float2 p) {
                float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.xx+p3.yz)*p3.zy);
            }

            half3 SampleStochastic(TEXTURE2D(tex), SAMPLER(samp), float2 uv)
            {
                float2x2 gridToSkewedGrid = float2x2(1.0, 0.0, -0.57735027, 1.15470054);
                float2x2 skewedGridToGrid = float2x2(1.0, 0.0, 0.5, 0.8660254);
                float2 skewedUV = mul(gridToSkewedGrid, uv);
                float2 i = floor(skewedUV);
                float2 f = frac(skewedUV);
                float2 i1 = (f.x > f.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
                float2 i2 = float2(1.0, 1.0);
                float2 i0 = float2(0.0, 0.0);
                float2 p0 = mul(skewedGridToGrid, -f + i0);
                float2 p1 = mul(skewedGridToGrid, -f + i1);
                float2 p2 = mul(skewedGridToGrid, -f + i2);
                float w0 = 0.5 - 0.5 * dot(p0, p0);
                float w1 = 0.5 - 0.5 * dot(p1, p1);
                float w2 = 0.5 - 0.5 * dot(p2, p2);
                float3 w = float3(w0, w1, w2);
                w = max(w, 0.0);
                w = pow(w, 3.0); 
                w /= (w.x + w.y + w.z);
                float2 h0 = hash2D(i + i0);
                float2 h1 = hash2D(i + i1);
                float2 h2 = hash2D(i + i2);
                half3 c0 = SAMPLE_TEXTURE2D(tex, samp, uv + h0 * 10.0).rgb;
                half3 c1 = SAMPLE_TEXTURE2D(tex, samp, uv + h1 * 10.0).rgb;
                half3 c2 = SAMPLE_TEXTURE2D(tex, samp, uv + h2 * 10.0).rgb;
                return w.x * c0 + w.y * c1 + w.z * c2;
            }

            struct Attributes {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
            };

            struct Varyings {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float3 localPos     : TEXCOORD2; 
                float3 normalOS     : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _CenterPos;
                float4 _ElevationMinMax;
                float _ShadowStrength;
                float _NoiseScale;
                float _NoiseStrength;
                float4 _RimColor;
                float _RimPower;
                float4 _DeepOceanColor;
                float _DeepOceanHeight;
                float4 _OceanColor;
                float _OceanHeight;

                float _GrassScale;
                float _GrassWidth;
                float _GrassHeight;
                // 新增森林变量
                float _ForestScale;
                float _ForestNoiseScale;
                float _ForestThreshold;
                float _ForestBlend;

                float _RockScale;
                float _RockWidth;
                float _RockHeight;
                float _SnowScale;
                float _SnowWidth;
                
                float _StochasticContrast;
            CBUFFER_END

            TEXTURE2D(_GrassTex); SAMPLER(sampler_GrassTex);
            TEXTURE2D(_ForestTex); SAMPLER(sampler_ForestTex); // 新增森林纹理
            TEXTURE2D(_RockTex);  SAMPLER(sampler_RockTex);
            TEXTURE2D(_SnowTex);  SAMPLER(sampler_SnowTex);

            // --- Stochastic Triplanar Mapping ---
            half3 GetStochasticTriplanarColor(TEXTURE2D(tex), SAMPLER(samp), float3 position, float3 normal, float scale)
            {
                float3 blend = abs(normal);
                blend = pow(blend, 4.0); 
                blend /= dot(blend, float3(1,1,1));
                half3 xCol = SampleStochastic(tex, samp, position.yz * scale);
                half3 yCol = SampleStochastic(tex, samp, position.xz * scale);
                half3 zCol = SampleStochastic(tex, samp, position.xy * scale);
                return xCol * blend.x + yCol * blend.y + zCol * blend.z;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.localPos = input.positionOS.xyz;
                output.normalOS = input.normalOS; 
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));
                output.normalWS = normalInput.normalWS;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float height = length(input.localPos - _CenterPos.xyz);
                float value = saturate((height - _ElevationMinMax.x) / (_ElevationMinMax.y - _ElevationMinMax.x));

                float3 blendingNormal = normalize(input.normalOS);
                
                // 1. 采样所有基础纹理 (随机三向)
                // 将原本的 grassCol 改名为 rawGrassCol，因为它还没混合森林
                half3 rawGrassCol = GetStochasticTriplanarColor(_GrassTex, sampler_GrassTex, input.localPos, blendingNormal, _GrassScale);
                // 新增森林采样
                half3 forestCol = GetStochasticTriplanarColor(_ForestTex, sampler_ForestTex, input.localPos, blendingNormal, _ForestScale);
                half3 rockCol = GetStochasticTriplanarColor(_RockTex, sampler_RockTex, input.localPos, blendingNormal, _RockScale);
                half3 snowCol = GetStochasticTriplanarColor(_SnowTex, sampler_SnowTex, input.localPos, blendingNormal, _SnowScale);

                // ========================================================
                // 新增核心逻辑：计算草地中的森林分布
                // ========================================================
                // 使用 fbm 计算一个独立的噪声值用于森林分布
                // 加一个固定的偏移量 (如 float3(31.4, 92.6, 53.5)) 确保森林分布和地形起伏不完全重合
                float forestNoiseVal = fbm((input.localPos + float3(31.4, 92.6, 53.5)) * _ForestNoiseScale);
                
                // 使用 smoothstep 创建一个平滑的遮罩 (0=草, 1=森林)
                // _ForestBlend 控制边缘过渡的宽度
                float forestMask = smoothstep(_ForestThreshold - _ForestBlend, _ForestThreshold + _ForestBlend, forestNoiseVal);

                // 合成最终的“草地层”颜色：在草和森林之间插值
                half3 compositeGrassCol = lerp(rawGrassCol, forestCol, forestMask);
                // ========================================================


                half3 albedo = _DeepOceanColor.rgb;

                // --- 海拔混合逻辑 ---
                // 注意：下面所有用到草地颜色的地方，都替换成了 compositeGrassCol
                if (value < _DeepOceanHeight) {
                    albedo = _DeepOceanColor.rgb;
                }
                else if (value < _OceanHeight-0.05) {
                    float t = smoothstep(_DeepOceanHeight, _OceanHeight, value);
                    albedo = lerp(_DeepOceanColor.rgb, _OceanColor.rgb, t);
                }
                else {
                    float grassMin = _GrassHeight - _GrassWidth;
                    float grassMax = _GrassHeight + _GrassWidth;
                    float rockMin = _RockHeight - _RockWidth;
                    float rockMax = _RockHeight + _RockWidth;
                    float snowMin = 1.0 - _SnowWidth;

                    if (value < grassMin) {
                        // 海滩过渡：海洋 -> 混合后的草地森林层
                        float t = smoothstep(_OceanHeight, grassMin, value);
                        albedo = lerp(_OceanColor.rgb, compositeGrassCol, t);
                    }
                    else if (value <= grassMax) {
                        // 纯草地区域：显示混合后的草地森林层
                        albedo = compositeGrassCol;
                    }
                    else if (value <= rockMin) { 
                         // 草地过渡到岩石：混合后的草地森林层 -> 岩石
                         float t = smoothstep(grassMax, _RockHeight, value); 
                         albedo = lerp(compositeGrassCol, rockCol, t);
                    }
                    else if (value <= rockMax) {
                        albedo = rockCol;
                    }
                    else {
                        float t = smoothstep(rockMax, snowMin, value);
                        albedo = lerp(rockCol, snowCol, t);
                    }
                }

                // --- 光照 ---
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float NdotL = max(0, dot(normalize(input.normalWS), mainLight.direction));
                float lightIntensity = NdotL * mainLight.shadowAttenuation;
                half3 finalColor = albedo * (lightIntensity + _ShadowStrength);

                // --- 大气 ---
                float3 viewDir = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float NdotV = saturate(dot(normalize(input.normalWS), viewDir));
                float rim = pow(1.0 - NdotV, _RimPower);
                finalColor += _RimColor.rgb * rim;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
        // ShadowCaster Pass...
        Pass 
        {
            Name "ShadowCaster" Tags{"LightMode" = "ShadowCaster"} ZWrite On ZTest LEqual ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings { float4 positionCS : SV_POSITION; };
            Varyings vert(Attributes input) { Varyings output; VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz); output.positionCS = vertexInput.positionCS; return output; }
            half4 frag(Varyings input) : SV_Target { return 0; }
            ENDHLSL
        }
    }
}