Shader "Custom/Nebula/ObjectSpaceNebula"
{
    Properties
    {
        _Color1("Nebula Color A", Color) = (0.3, 0.6, 1, 1)
        _Color2("Nebula Color B", Color) = (1, 0.4, 0.8, 1)

        _Density("Density", Float) = 1.0
        _NoiseScale("Noise Scale", Float) = 2.0
        _Steps("Raymarch Steps", Range(16,256)) = 96
        _Brightness("Brightness", Float) = 1.5
        _Extinction("Extinction", Float) = 1.0

        _LightDir("Light Direction", Vector) = (0, -0.5, -1, 0)
        _LightColor("Light Color", Color) = (1,1,1,1)
        _Anisotropy("Anisotropy g", Range(-0.9,0.9)) = 0.5

        _Radius("Nebula Radius", Float) = 5.0
    }

    SubShader
    {
        Tags{
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 _Color1;
            float4 _Color2;
            float _Density;
            float _NoiseScale;
            float _Steps;
            float _Brightness;
            float _Extinction;

            float3 _LightDir;
            float4 _LightColor;
            float _Anisotropy;
            float _Radius;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 posOS       : TEXCOORD0;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.posOS = v.positionOS.xyz;  // 用物体空间进行 Raymarch（关键）
                return o;
            }

            // 简易 hash
            float hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                return frac(p.x * p.y * p.z * 95.433);
            }

            // 3D noise
            float noise(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);

                float a = hash(i);
                float b = hash(i + float3(1,0,0));
                float c = hash(i + float3(0,1,0));
                float d = hash(i + float3(1,1,0));
                float e = hash(i + float3(0,0,1));
                float f1 = hash(i + float3(1,0,1));
                float g = hash(i + float3(0,1,1));
                float h = hash(i + float3(1,1,1));

                float3 u = f*f*(3.0 - 2.0*f);

                return lerp(
                        lerp( lerp(a, b, u.x), lerp(c, d, u.x), u.y ),
                        lerp( lerp(e, f1, u.x), lerp(g, h, u.x), u.y ),
                        u.z);
            }

            float fbm(float3 p)
            {
                float v = 0.0;
                float amp = 0.5;
                for(int i=0;i<4;i++)
                {
                    v += noise(p) * amp;
                    p *= 2.0;
                    amp *= 0.5;
                }
                return v;
            }

            float phaseHG(float cosTheta, float g)
            {
                float g2 = g*g;
                return (1-g2) / pow(1 + g2 - 2*g*cosTheta, 1.5);
            }

            float4 frag(Varyings i) : SV_Target
            {
                float3 rayOrigin = 0;              // 摄像机在球体中心
                float3 rayDir = normalize(i.posOS); // 朝向该像素处 Mesh 表面方向

                float distToSurface = length(i.posOS);
                if(distToSurface > _Radius) return float4(0,0,0,0);

                float tMax = distToSurface;
                float stepSize = tMax / _Steps;

                float3 accum = 0;
                float transmittance = 1.0;
                float3 lightDir = normalize(_LightDir);

                float t = 0;

                [loop]
                for(int s=0;s<_Steps;s++)
                {
                    float3 p = rayOrigin + rayDir * t;

                    float d = fbm(p * _NoiseScale);
                    d = saturate((d - 0.4) * 2.0);
                    d *= _Density;

                    if(d > 0.001)
                    {
                        float3 nebulaCol = lerp(_Color1.rgb, _Color2.rgb, d);

                        float cosTheta = dot(rayDir, -lightDir);
                        float intensity = phaseHG(cosTheta, _Anisotropy);

                        float absorption = exp(-d * _Extinction * stepSize);
                        float delta = transmittance * (1.0 - absorption);

                        accum += nebulaCol * _LightColor.rgb * intensity * delta;
                        transmittance *= absorption;

                        if(transmittance < 0.01) break;
                    }

                    t += stepSize;
                }

                float3 color = accum * _Brightness;
                float alpha = saturate(1.0 - transmittance);

                return float4(color, alpha);
            }

            ENDHLSL
        }
    }

    FallBack Off
}
