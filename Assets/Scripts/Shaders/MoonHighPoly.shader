Shader "Custom/URP_MoonSurface_Optimized"
{
    Properties
    {
        [Header(Base Settings)]
        _BaseColor ("Base Color", Color) = (0.8, 0.8, 0.8, 1)
        _MainTex ("Albedo Map", 2D) = "white" {}
        
        [Header(Surface Detail)]
        _DetailTex ("Detail Noise (Gray 0.5 neutral)", 2D) = "gray" {}
        _DetailStrength ("Detail Strength", Range(0, 5)) = 1.0
        _DetailTiling ("Detail Tiling", Float) = 20.0
        
        [Header(Normal Settings)]
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Strength", Range(0, 5)) = 1.0

        [Header(Lighting Control)]
        // 控制坑洞在亮部是否清晰
        _NormalLightContrast ("Normal Detail Contrast", Range(1, 10)) = 1.0 
        // 控制月球明暗交界线的锐利程度
        _TerminatorSharpness ("Terminator Sharpness", Range(0.01, 1.0)) = 0.1
        // 控制明暗交界线的位置偏移
        _TerminatorLocation ("Terminator Location", Range(-1, 1)) = 0.0
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
            
            // 启用 URP 核心功能：阴影、级联阴影、法线贴图宏
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _NORMALMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _MainTex_ST;
                float4 _DetailTex_ST; // 即使不用Offset，保留它是好习惯
                float _DetailStrength;
                float _DetailTiling;
                float _BumpScale;
                float _TerminatorSharpness;
                float _TerminatorLocation;
                float _NormalLightContrast;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_DetailTex); SAMPLER(sampler_DetailTex);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);

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
                float3 normalWS   : TEXCOORD1;     // 几何法线 (Vertex Normal)
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
                
                // 传递几何法线，用于计算宏观的明暗交界线
                OUT.normalWS = normalInput.normalWS; 
                
                OUT.tangentWS = float4(normalInput.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // ---------------------------------------------------------
                // 1. 数据准备
                // ---------------------------------------------------------
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 lightDir = normalize(mainLight.direction);
                
                // 构建 TBN 矩阵
                float3 bitangent = cross(IN.normalWS, IN.tangentWS.xyz) * IN.tangentWS.w;
                float3x3 TBN = float3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);
                
                // 获取法线贴图并转换到世界空间
                #if defined(_NORMALMAP)
                    float3 sampledNormal = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv), _BumpScale);
                    float3 normalPixel = normalize(mul(sampledNormal, TBN));
                #else
                    float3 normalPixel = normalize(IN.normalWS);
                #endif
                
                float3 normalGeo = normalize(IN.normalWS); // 几何法线

                // ---------------------------------------------------------
                // 2. 纹理混合 (优化后的 Overlay 逻辑)
                // ---------------------------------------------------------
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                
                // 计算 Detail UV
                float2 detailUV = IN.uv * _DetailTiling;
                float detailGray = SAMPLE_TEXTURE2D(_DetailTex, sampler_DetailTex, detailUV).r;
                
                // 核心修复：更自然的混合公式
                // 假设 DetailTex 中性灰是 0.5。
                // 公式: base * (detail * 2) -> 0.5 时不变，>0.5 变亮，<0.5 变暗
                float detailInfluence = detailGray * 2.0;
                // 应用强度
                detailInfluence = lerp(1.0, detailInfluence, _DetailStrength);
                
                float3 albedo = _BaseColor.rgb * baseMap.rgb * detailInfluence;

                // ---------------------------------------------------------
                // 3. 光照计算逻辑 (核心修复)
                // ---------------------------------------------------------
                
                // A. 宏观明暗交界线 (Terminator)
                // 使用【几何法线】计算大范围的明暗，防止法线贴图在阴影边缘产生噪点
                float geoNdotL = dot(normalGeo, lightDir);
                // 使用 smoothstep 制作锐利但平滑的过渡
                float terminatorMask = smoothstep(_TerminatorLocation - _TerminatorSharpness, _TerminatorLocation + _TerminatorSharpness, geoNdotL);

                // B. 表面细节光照 (Surface Detail)
                // 使用【像素法线(法线贴图)】计算表面的坑洞起伏
                float pixelNdotL = dot(normalPixel, lightDir);
                // 映射到 0~1，防止背光面出现奇怪负值
                float detailShading = saturate(pixelNdotL);
                
                // 增强对比度：让坑洞更深
                // pow(x, >1) 会让暗部更暗，亮部保持
                detailShading = pow(detailShading, _NormalLightContrast);

                // C. 组合光照
                // 最终亮度 = (细节光照) * (宏观阴影遮罩) * (Unity实时阴影)
                float lightIntensity = detailShading * terminatorMask * mainLight.shadowAttenuation;

                // ---------------------------------------------------------
                // 4. 合成输出
                // ---------------------------------------------------------
                float3 finalColor = albedo * lightIntensity * mainLight.color;

                // 添加微弱的环境光，防止背光面死黑（模拟地球反光或星光）
                float3 ambient = albedo * 0.05; // 基础环境光强度

                return float4(finalColor + ambient, 1.0);
            }
            ENDHLSL
        }
        
        // ShadowCaster Pass 是必须的，否则物体无法投射阴影
        Pass 
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings { float4 positionCS : SV_POSITION; };
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target { return 0; }
            ENDHLSL
        }
    }
}