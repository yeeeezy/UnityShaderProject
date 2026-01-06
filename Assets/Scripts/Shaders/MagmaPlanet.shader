Shader "Custom/URP_MagmaPlanet"
{
    Properties
    {
        [Header(Base Appearance)]
        _RockColor ("Rock Color", Color) = (0.1, 0.05, 0.05, 1)
        [HDR] _LavaColor ("Lava Color", Color) = (3.0, 1.2, 0.2, 1) 
        
        [Header(Magma Simulation)]
        _NoiseMap ("Flow Noise Map", 2D) = "white" {}
        _NoiseTiling ("Noise Tiling", Float) = 2.0
        _FlowSpeed ("Flow Speed", Range(0, 2)) = 0.2
        
        [Header(Crust Control)]
        _MagmaThreshold ("Crust Threshold", Range(0, 1)) = 0.5 
        _MagmaSoftness ("Edge Softness", Range(0.01, 0.5)) = 0.05 
        
        [Header(Normal)]
        _RockNormal ("Rock Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 5)) = 1.0

        [Header(Lighting)]
        _Smoothness ("Rock Smoothness", Range(0, 1)) = 0.2
        _EmissionStrength ("Emission Intensity", Range(0, 5)) = 1.5
        _PulseSpeed ("Pulse Speed", Range(0, 10)) = 2.0 

        [Header(Atmosphere)]
        [HDR] _RimColor ("Heat Rim Color", Color) = (1.0, 0.3, 0.0, 1)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 3.0
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
            #pragma multi_compile _ _NORMALMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _RockColor;
                float4 _LavaColor;
                float4 _RimColor;
                float4 _NoiseMap_ST;
                float4 _RockNormal_ST;
                float _NoiseTiling;
                float _FlowSpeed;
                float _MagmaThreshold;
                float _MagmaSoftness;
                float _NormalStrength;
                float _Smoothness;
                float _EmissionStrength;
                float _PulseSpeed;
                float _RimPower; // <--- 之前漏掉了这一行，已补上
            CBUFFER_END

            TEXTURE2D(_NoiseMap); SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_RockNormal); SAMPLER(sampler_RockNormal);

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
                float4 tangentWS  : TEXCOORD2;
                float2 uv         : TEXCOORD3;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = float4(normalInput.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 1. 基础数据准备
                float3 viewDir = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 lightDir = normalize(mainLight.direction);

                float3 bitangent = cross(IN.normalWS, IN.tangentWS.xyz) * IN.tangentWS.w;
                float3x3 TBN = float3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);

                // 2. 噪点采样
                float2 uvBase = IN.uv * _NoiseTiling;
                float2 flow1 = float2(_Time.y * _FlowSpeed * 0.5, _Time.y * _FlowSpeed * 0.2);
                float2 flow2 = float2(-_Time.y * _FlowSpeed * 0.4, _Time.y * _FlowSpeed * 0.6);

                float noise1 = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvBase + flow1).r;
                float noise2 = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, uvBase + flow2).r;
                float flowNoise = (noise1 + noise2) * 0.5;

                // 3. 地壳遮罩
                float crustMask = smoothstep(_MagmaThreshold, _MagmaThreshold + _MagmaSoftness, flowNoise);

                // 4. 法线
                float3 rockNormal = UnpackNormalScale(SAMPLE_TEXTURE2D(_RockNormal, sampler_RockNormal, uvBase), _NormalStrength);
                float3 lavaNormal = float3(0, 0, 1);
                float3 tangentNormal = lerp(lavaNormal, rockNormal, crustMask);
                float3 normalWS = normalize(mul(tangentNormal, TBN));

                // 5. 光照
                float NdotL = saturate(dot(normalWS, lightDir));
                float lightIntensity = NdotL * mainLight.shadowAttenuation;

                // 6. 颜色混合
                // 岩石
                float3 rockDiffuse = _RockColor.rgb * lightIntensity * mainLight.color;
                float3 halfDir = normalize(lightDir + viewDir);
                float NdotH = saturate(dot(normalWS, halfDir));
                float specular = pow(NdotH, _Smoothness * 128) * _Smoothness * lightIntensity;
                float3 rockFinal = rockDiffuse + specular;

                // 岩浆 (自发光 + 呼吸)
                float pulse = 1.0 + sin(_Time.y * _PulseSpeed) * 0.2; 
                float deepLavaFactor = pow(1.0 - flowNoise, 2.0); 
                float3 lavaEmission = _LavaColor.rgb * _EmissionStrength * pulse * deepLavaFactor;

                // 混合
                float3 bodyColor = lerp(lavaEmission, rockFinal, crustMask);

                // 7. 边缘热浪 (现在 _RimPower 已经被正确声明了)
                float NdotV = saturate(dot(normalWS, viewDir));
                float rimFactor = pow(1.0 - NdotV, _RimPower);
                float3 rim = _RimColor.rgb * rimFactor;

                return float4(bodyColor + rim, 1.0);
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
}