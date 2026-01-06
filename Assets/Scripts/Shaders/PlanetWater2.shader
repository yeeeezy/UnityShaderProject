Shader "Custom/URP_EarthOcean_Realistic_Refraction"
{
    Properties
    {
        [Header(Base Colors)]
        _DeepColor ("Deep Ocean Tint", Color) = (0.5, 0.8, 1.0, 1) // 建议设为偏白的浅蓝，因为是乘法
        _ShallowColor ("Shallow Tint", Color) = (0.8, 0.9, 1.0, 1)
        _TintStrength ("Tint Strength", Range(0, 1)) = 0.5 // 控制染色的强度

        [Header(Waves)]
        _BumpMap ("Wave Normal Map", 2D) = "bump" {}
        _WaveSpeed ("Wave Speed", Range(0, 10)) = 1.5
        _WaveScale ("Wave Scale", Range(0.1, 10)) = 3.0
        _RefractionStrength ("Distortion Strength", Range(0, 1.0)) = 0.1 // 稍微加大一点折射让效果更明显

        [Header(Lighting)]
        _ShadowStrength("Shadow Brightness", Range(0, 1)) = 0.0 
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.95
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)

        [Header(Atmosphere Rim)]
        _RimColor ("Rim Color", Color) = (0.2, 0.6, 1.0, 1)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 4.0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline" "Queue"="Transparent" }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _DeepColor;
                float4 _ShallowColor;
                float4 _RimColor;
                float4 _BumpMap_ST;
                float4 _SpecularColor;
                float _WaveSpeed;
                float _WaveScale;
                float _RimPower;
                float _Smoothness;
                float _ShadowStrength;
                float _RefractionStrength;
                float _TintStrength;
            CBUFFER_END

            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float4 tangentWS  : TEXCOORD4;
                float2 uv         : TEXCOORD5;
                float4 positionNDC : TEXCOORD6; 
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.normalWS = normalInput.normalWS;
                OUT.positionNDC = vertexInput.positionNDC;
                OUT.tangentWS = float4(normalInput.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
                OUT.uv = TRANSFORM_TEX(IN.uv, _BumpMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 viewDir = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                
                // --- 法线处理 ---
                float3 bitangent = cross(IN.normalWS, IN.tangentWS.xyz) * IN.tangentWS.w;
                float3x3 TBN = float3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);

                float2 scroll1 = IN.uv * _WaveScale + _Time.y * (_WaveSpeed * 0.05);
                float2 scroll2 = IN.uv * (_WaveScale * 0.8) - _Time.y * (_WaveSpeed * 0.03);
                float3 n1 = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, scroll1));
                float3 n2 = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, scroll2));
                float3 tangentNormal = normalize(float3(n1.xy + n2.xy, n1.z * n2.z));
                float3 normalWS = normalize(mul(tangentNormal, TBN));

                // --- 光照与阴影 ---
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 lightDir = normalize(mainLight.direction);
                float NdotL = max(0, dot(normalWS, lightDir));
                float shadowMask = NdotL * mainLight.shadowAttenuation;

                // --- 菲涅尔 ---
                float NdotV = saturate(dot(normalWS, viewDir));
                float fresnelTerm = pow(1.0 - NdotV, 4.0);

                // --- 核心修改：折射采样与染色 ---
                
                // 1. 计算折射UV
                float2 screenUV = IN.positionNDC.xy / IN.positionNDC.w;
                // 使用法线的XY作为偏移量
                float2 refractionOffset = tangentNormal.xy * _RefractionStrength * saturate(NdotV); // 视角越垂直，折射越弱(可选，防止边缘拉扯)
                
                // 2. 采样背景 (Opaque Texture)
                float3 background = SampleSceneColor(screenUV + refractionOffset);

                // 3. 应用阴影到背景 (如果在暗面，看到的背景也变暗)
                background *= (shadowMask + _ShadowStrength);

                // 4. 计算水的染色 (Tint)
                // 基于菲涅尔混合深浅色，但不直接显示这个色，而是用它乘背景
                float3 waterTint = lerp(_DeepColor.rgb, _ShallowColor.rgb, fresnelTerm);
                
                // 混合： 原始背景 <---> 染色后的背景
                // _TintStrength 控制水有多"浑浊/有色"。0=完全透明玻璃，1=完全染色玻璃
                float3 tintedBackground = background * waterTint;
                float3 finalWaterBody = lerp(background, tintedBackground, _TintStrength);

                // --- 表面光效 (叠加层) ---
                
                // 高光 (Specular) - 仅在有光照的地方显示
                float3 halfVector = normalize(lightDir + viewDir);
                float NdotH = saturate(dot(normalWS, halfVector));
                float specularIntensity = pow(NdotH, _Smoothness * 128.0);
                float3 specular = _SpecularColor.rgb * specularIntensity * mainLight.color * shadowMask;

                // 边缘光 (Rim) - 同样受阴影遮罩影响
                float rimStrength = pow(1.0 - NdotV, _RimPower);
                float3 rimEmission = _RimColor.rgb * rimStrength * (shadowMask + _ShadowStrength);

                // --- 最终合成 ---
                // 注意：这里不再是 lerp(背景, 颜色, alpha)。
                // 而是：(背景 * 染色) + 高光 + 边缘光
                float3 finalColor = finalWaterBody + specular + rimEmission;

                // Alpha 设为 1，因为我们实际上是在显示背景，只是修改了背景的颜色。
                // 如果设为透明，会导致这层效果再次和背景混合，造成双重曝光。
                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
        
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
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}