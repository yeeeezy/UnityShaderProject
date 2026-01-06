Shader "URP/Custom/SphereWaterSimple"
{
    Properties
    {
        _ShallowColor   ("Shallow Color", Color) = (0.10, 0.40, 0.60, 1)
        _DeepColor      ("Deep Color",    Color) = (0.02, 0.08, 0.16, 1)

        _WaveStrength   ("Wave Normal Strength", Float) = 0.2
        _WaveFreq       ("Wave Frequency",       Float) = 6.0
        _WaveSpeed      ("Wave Speed",           Float) = 1.0

        _FresnelPower   ("Fresnel Power",        Float) = 4.0
        _SpecStrength   ("Specular Strength",    Float) = 0.7
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"     = "Opaque"
            "Queue"          = "Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            Blend Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 worldPos    : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 viewDirWS   : TEXCOORD2;
                float2 uv          : TEXCOORD3;
            };

            float4 _ShallowColor;
            float4 _DeepColor;

            float _WaveStrength;
            float _WaveFreq;
            float _WaveSpeed;

            float _FresnelPower;
            float _SpecStrength;

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 nWS   = TransformObjectToWorldNormal(IN.normalOS);

                OUT.worldPos    = posWS;
                OUT.normalWS    = normalize(nWS);
                OUT.viewDirWS   = GetWorldSpaceViewDir(posWS);
                OUT.uv          = IN.uv;
                OUT.positionHCS = TransformWorldToHClip(posWS);

                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(IN.viewDirWS);

                // ----- fake wave normal: just perturb normal with a simple animated sin -----
                float t = _Time.y;
                float2 uv = IN.uv;

                float wave1 = sin(uv.x * _WaveFreq + t * _WaveSpeed);
                float wave2 = cos(uv.y * (_WaveFreq * 1.7) - t * (_WaveSpeed * 1.3));
                float wave  = (wave1 + wave2) * 0.5;

                // perturb along tangent-ish direction (no vertex move, only shading)
                float3 perturb = float3(0, wave, wave * 0.5);
                N = normalize(N + perturb * _WaveStrength);

                // ----- lighting -----
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.worldPos));
                float3 L = normalize(mainLight.direction);

                float NdotL = saturate(dot(N, L));
                float NdotV = saturate(dot(N, V));

                // shallow vs deep: use "up" to fake depth
                float upFactor = saturate(N.y * 0.5 + 0.5);
                float3 waterCol = lerp(_DeepColor.rgb, _ShallowColor.rgb, upFactor);

                float3 diffuse = waterCol * (NdotL * mainLight.color.rgb);
                float3 ambient = waterCol * 0.25;

                // Fresnel specular
                float fresnel = pow(1.0 - NdotV, _FresnelPower);
                float3 specular = _SpecStrength * fresnel * mainLight.color.rgb;

                float3 color = diffuse + ambient + specular;

                return half4(color, 1.0);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
