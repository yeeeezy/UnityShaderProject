Shader "Custom/Shader/StarfieldFullScreen"
{
    Properties
    {
        _StarDensity   ("Star Density",   Range(20, 400)) = 200
        _StarIntensity ("Star Intensity", Range(1, 50))   = 20
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "StarfieldFullScreen"
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _StarDensity;
            float _StarIntensity;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings o;
               
                o.positionHCS = TransformObjectToHClip(input.positionOS);
                o.uv = input.uv;
                return o;
            }

            
            float Hash3(float3 p)
            {
                p  = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            
            float StarLayer(float2 uv, float scale, float threshold, float sharp)
            {
                float3 p = float3(uv * scale, scale);
                float h = Hash3(p);
                float m = step(threshold, h);
                float b = pow(h, sharp);
                return m * b;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float2 uv = i.uv;          // [0,1]

                
                float smallStars = StarLayer(uv, _StarDensity,       0.995,  50.0);
                float midStars   = StarLayer(uv, _StarDensity * 0.4, 0.997,  30.0);
                float bigStars   = StarLayer(uv, _StarDensity * 0.15,0.9985, 10.0);

                float stars = smallStars + midStars + bigStars;

                
                float t = _Time.y;
                float flickerSeed = Hash3(float3(uv * 512.0, 1.0));
                float flicker = 0.5 + 0.5 * sin(t * 5.0 + flickerSeed * 6.2831);

                stars *= flicker;

               
                float colorSeed = Hash3(float3(uv * 1024.0, 2.0));
                float3 baseColor = lerp(float3(0.6, 0.7, 1.0),
                                        float3(1.0, 0.9, 0.8),
                                        colorSeed);

                
                float hdrFactor = _StarIntensity;

                float3 starCol = stars * baseColor * hdrFactor;

               
                float3 bg = float3(0.01, 0.01, 0.015);

                float3 col = bg + starCol;

                return float4(col, 1.0);
            }

            ENDHLSL
        }
    }
}

