Shader "Custom/MarsSphereRock"
{
    Properties
    {
        [Header(Height Blending)]
        _ColorLow ("Deep/Canyon Color", Color) = (0.3, 0.1, 0.05, 1) // 峡谷深色
        _ColorHigh ("Highland Color", Color) = (0.6, 0.3, 0.15, 1)   // 高地浅色
        _HeightMin ("Height Min (Radius)", Float) = 9.8              // 最低高度（球体半径）
        _HeightMax ("Height Max (Radius)", Float) = 10.2             // 最高高度
        _HeightNoiseStr ("Height Noise Strength", Range(0, 2)) = 0.5 // 混合噪点强度
        
        [Header(Base Textures)]
        _BaseMap ("Rock Texture (RGB)", 2D) = "gray" {}
        [Normal] _BumpMap ("Rock Normal", 2D) = "bump" {}
        _TriplanarScale ("Texture Scale", Float) = 1.0
        
        [Header(PBR)]
        _Smoothness ("Rock Smoothness", Range(0, 1)) = 0.2
        _Metallic ("Rock Metallic", Range(0, 1)) = 0.0

        [Header(Dynamic Dust)]
        _DustColor ("Dust Color", Color) = (0.8, 0.5, 0.3, 1)
        _DustSlopeThreshold ("Dust Slope Threshold", Range(0, 1)) = 0.6 // 斜率阈值
        _DustBlend ("Dust Softness", Range(0.01, 1)) = 0.2
        _DustSmoothness ("Dust Smoothness", Range(0, 1)) = 0.05
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry" }
        LOD 300

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _ColorLow;
            float4 _ColorHigh;
            float4 _DustColor;
            
            float _HeightMin;
            float _HeightMax;
            float _HeightNoiseStr;
            
            float _TriplanarScale;
            float _Smoothness;
            float _Metallic;
            
            float _DustSlopeThreshold;
            float _DustBlend;
            float _DustSmoothness;
        CBUFFER_END

        Texture2D _BaseMap; SamplerState sampler_BaseMap;
        Texture2D _BumpMap; SamplerState sampler_BumpMap;

        // --- 辅助：重映射函数 ---
        float remap(float value, float minOld, float maxOld, float minNew, float maxNew) {
            return minNew + (value - minOld) * (maxNew - minNew) / (maxOld - minOld);
        }

        // --- 三向颜色采样 ---
        float4 TriplanarSample(Texture2D tex, SamplerState smp, float3 positionWS, float3 normalWS, float scale)
        {
            float3 uvPos = positionWS * scale;
            float3 blend = abs(normalWS);
            blend /= (blend.x + blend.y + blend.z + 1e-4);
            
            float4 x = tex.Sample(smp, uvPos.zy);
            float4 y = tex.Sample(smp, uvPos.xz);
            float4 z = tex.Sample(smp, uvPos.xy);
            return x * blend.x + y * blend.y + z * blend.z;
        }

        // --- 三向法线采样 ---
        float3 TriplanarNormal(Texture2D tex, SamplerState smp, float3 positionWS, float3 normalWS, float scale)
        {
            float3 uvPos = positionWS * scale;
            float3 blend = abs(normalWS);
            blend /= (blend.x + blend.y + blend.z + 1e-4);

            float3 nX = UnpackNormal(tex.Sample(smp, uvPos.zy));
            float3 nY = UnpackNormal(tex.Sample(smp, uvPos.xz));
            float3 nZ = UnpackNormal(tex.Sample(smp, uvPos.xy));

            float3 axisSign = sign(normalWS);
            nX.z *= axisSign.x; nY.z *= axisSign.y; nZ.z *= axisSign.z;

            float3 worldNormalMod = 
                float3(0, nX.y, nX.x) * blend.x +
                float3(nY.x, 0, nY.y) * blend.y +
                float3(nZ.x, nZ.y, 0) * blend.z;

            return normalize(normalWS + worldNormalMod);
        }
        ENDHLSL

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 1. 基础几何数据
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = GetWorldSpaceViewDir(input.positionWS);
                
                // 计算球体中心（假设物体原点即为球心）
                float3 sphereCenter = TransformObjectToWorld(float3(0,0,0));
                
                // 计算当前像素相对于球心的距离（高度）和方向（球体法线）
                float3 vecToSurface = input.positionWS - sphereCenter;
                float distFromCenter = length(vecToSurface);
                float3 sphereUp = normalize(vecToSurface); // 这一点相对于球心的"正上方"

                // 2. 采样纹理 (Triplanar)
                float4 rockTex = TriplanarSample(_BaseMap, sampler_BaseMap, input.positionWS, normalWS, _TriplanarScale);
                
                // 3. 计算高度混合颜色 (Hypsometry)
                // 使用纹理的 R 通道作为噪点，打断完美的高度分层
                float heightNoise = (rockTex.r - 0.5) * _HeightNoiseStr; 
                float heightFactor = saturate((distFromCenter + heightNoise - _HeightMin) / (_HeightMax - _HeightMin));
                
                float3 baseRockColor = lerp(_ColorLow.rgb, _ColorHigh.rgb, heightFactor);
                // 叠加纹理细节（正片叠底或叠加）
                float3 finalAlbedo = baseRockColor * rockTex.rgb * 1.5; // *1.5 提亮一点

                // 4. 计算细节法线
                float3 blendedNormal = TriplanarNormal(_BumpMap, sampler_BumpMap, input.positionWS, normalWS, _TriplanarScale);
                
                // 5. 球体表面的尘埃逻辑
                // 计算"坡度"：当前表面法线 与 球体径向向量 的点积
                // dot接近1表示平地（平行于球面），dot接近0表示悬崖（垂直于球面）
                float slope = dot(blendedNormal, sphereUp);
                
                // 尘埃遮罩
                float dustMask = smoothstep(_DustSlopeThreshold - _DustBlend, _DustSlopeThreshold + _DustBlend, slope);

                // 混合尘埃
                finalAlbedo = lerp(finalAlbedo, _DustColor.rgb, dustMask);
                float finalSmoothness = lerp(_Smoothness, _DustSmoothness, dustMask);
                float finalMetallic = lerp(_Metallic, 0.0, dustMask);

                // 6. 输出 PBR
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = blendedNormal;
                inputData.viewDirectionWS = viewDirWS;
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                inputData.fogCoord = ComputeFogFactor(input.positionCS.z);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = finalAlbedo;
                surfaceData.metallic = finalMetallic;
                surfaceData.smoothness = finalSmoothness;
                surfaceData.occlusion = 1.0;
                surfaceData.alpha = 1.0;

                return UniversalFragmentPBR(inputData, surfaceData);
            }
            ENDHLSL
        }

        // ShadowCaster Pass (保持不变，为了完整性再次列出)
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            float3 _LightDirection;
            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS : SV_POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };
            Varyings ShadowPassVertex(Attributes input) {
                Varyings output; UNITY_SETUP_INSTANCE_ID(input); UNITY_TRANSFER_INSTANCE_ID(input, output);
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #if UNITY_REVERSED_Z
                output.positionCS.z = min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                output.positionCS.z = max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                return output;
            }
            half4 ShadowPassFragment(Varyings input) : SV_Target { return 0; }
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}
            ZWrite On ColorMask 0
            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS : SV_POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID UNITY_VERTEX_OUTPUT_STEREO };
            Varyings DepthOnlyVertex(Attributes input) {
                Varyings output = (Varyings)0; UNITY_SETUP_INSTANCE_ID(input); UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz); return output;
            }
            half4 DepthOnlyFragment(Varyings input) : SV_Target { return 0; }
            ENDHLSL
        }
    }
}