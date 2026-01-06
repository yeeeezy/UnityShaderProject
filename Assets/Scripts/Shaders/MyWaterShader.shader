Shader "Custom/WaterRippleFoam"
{
    Properties
    {
        _WaterColor("Water Color", Color) = (0,0.5,0.7,1)
        _FoamColor("Foam Color", Color) = (1,1,1,1)

        _FoamDistance("Foam Distance", Float) = 1.0
        _FoamSoftness("Foam Softness", Float) = 1.0
        _FoamIntensity("Foam Intensity", Float) = 1.0
        
        _WaveSpeed("Wave Speed", Float) = 1.0
        _WaveScale("Wave Scale", Float) = 0.1
        _WaveFrequency("Wave Frequency", Float) = 5.0

        _MainTex("Water Normal", 2D) = "bump" {}
    }

    SubShader
    {
        Tags{
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Depth texture declaration
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _WaterColor;
            float4 _FoamColor;

            float _FoamDistance;
            float _FoamSoftness;
            float _FoamIntensity;

            float _WaveSpeed;
            float _WaveScale;
            float _WaveFrequency;

            Varyings vert(Attributes IN)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                o.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.positionHCS);
                return o;
            }

            // --- Cross-platform depth sampling
            float GetSceneDepth(float2 uv)
            {
                float raw = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                return LinearEyeDepth(raw, _ZBufferParams);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

                float depthScene = GetSceneDepth(screenUV);
                float depthWater = IN.positionHCS.w;

                float foamFactor = saturate(1 - (depthScene - depthWater) / _FoamDistance);
                foamFactor = smoothstep(0, _FoamSoftness, foamFactor);
                foamFactor *= _FoamIntensity;

                float wave = sin(_Time.y * _WaveSpeed + IN.uv.x * _WaveFrequency) * _WaveScale;
                wave += sin(_Time.y * _WaveSpeed * 1.3 + IN.uv.y * _WaveFrequency * 1.2) * _WaveScale;

                float3 color = lerp(_WaterColor.rgb, _FoamColor.rgb, foamFactor);
                float alpha = 0.6 + wave * 0.2;

                return float4(color, alpha);
            }

            ENDHLSL
        }
    }
}
