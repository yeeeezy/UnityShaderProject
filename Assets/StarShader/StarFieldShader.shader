Shader "Custom/Shader/StarFieldShader"

{
    Properties
    {
        _StarIntensity ("Star Intensity (HDR)", Float) = 5.0
        _StarDensity   ("Star Density", Float) = 35.0
        _StarSize      ("Star Size", Float) = 0.25
        _TwinkleSpeed  ("Twinkle Speed", Float) = 2.0

        _ColorA        ("Star Color A", Color) = (0.9, 0.95, 1.0, 1)
        _ColorB        ("Star Color B", Color) = (1.0, 0.9, 0.8, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Background"
        }

        // 我们在球体内部看天空，所以要渲染模型的“背面”
        Cull Front
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "StarSphere"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 属性
            float  _StarIntensity;
            float  _StarDensity;
            float  _StarSize;
            float  _TwinkleSpeed;
            float4 _ColorA;
            float4 _ColorB;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 dirWS       : TEXCOORD0;   // 世界空间方向（指向天空）
            };

            // 顶点着色器：只需要算出世界方向
            Varyings Vert(Attributes input)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(input.positionOS);
                o.positionHCS     = TransformWorldToHClip(positionWS);

                // 使用世界法线作为“天穹方向”
                float3 normalWS   = TransformObjectToWorldNormal(input.normalOS);
                o.dirWS           = normalize(normalWS);

                return o;
            }

            // 简单 hash，把 float3 映射到 [0,1]
            float Hash13(float3 p)
            {
                p = frac(p * 0.1031);
                p += dot(p, p.yzx + 33.33);
                return frac((p.x + p.y) * p.z);
            }

            // 生成一层星星
            float3 StarLayer(float3 dir, float layerScale, float layerSize, float timeOffset)
            {
                // 把方向放大映射到 3D 单元格
                float3 p = dir * layerScale;

                float3 cell = floor(p);  // 当前所在立方单元
                float3 f    = frac(p);   // 单元内局部坐标 [0,1]^3

                // 每个 cell 里随机一个星星中心
                float3 randBase = cell + float3(11.0, 37.0, 57.0);
                float3 starPos  = float3(
                    Hash13(randBase + 1.0),
                    Hash13(randBase + 2.0),
                    Hash13(randBase + 3.0)
                );

                float d = distance(f, starPos);

                // 控制星星大小
                float star = smoothstep(layerSize, 0.0, d); // 中间亮、边缘软

                // 随机决定这格子里到底要不要出现星星（让空白多一点）
                float presence = step(0.8, Hash13(cell + 19.0)); // 约 20% 的格子有星
                star *= presence;

                // 星星颜色（在两种颜色之间随机）
                float colorSeed = Hash13(cell + 29.0);
                float3 baseCol  = lerp(_ColorA.rgb, _ColorB.rgb, colorSeed);

                // 闪烁
                float phase   = Hash13(cell + 73.0);
                float flicker = 0.7 + 0.3 * sin(_Time.y * _TwinkleSpeed + phase * 6.2831);

                star *= flicker;

                return baseCol * star;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float3 dir = normalize(i.dirWS); // 天空方向

                // 多层星空叠加（远近不同，密度不同）
                float3 col = 0;

                float density = _StarDensity;
                float size    = _StarSize;

                // 第 1 层：最远、最密的微小星星
                col += StarLayer(dir, density, size * 0.1, 0.0);

                // 第 2 层：中等大小
                col += StarLayer(dir, density * 0.7, size*0.4, 1.3);

                // 第 3 层：少量较大的亮星
                col += StarLayer(dir, density * 0.5, size*0.6, 2.7);

                // 提升亮度做 HDR，让 Bloom 生效
                col *= _StarIntensity;

                // 深色空间背景
                float3 bg = float3(0.0, 0.0, 0.01);
                col = bg + col;

                return float4(col, 1.0);
            }

            ENDHLSL
        }
    }
}

