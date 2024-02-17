Shader "Custom Render Pipeline/Flow/Directional Flow"
{
    Properties
    {
        _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BaseMap("Texture", 2D) = "white" {}
        
        [Toggle(_NORMAL_MAP)] _NormalMapToggle("Normal Map", Float) = 0
        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0, 1)) = 1

        [Toggle(_DERIV_HEIGHT_MAP)] _DerivHeightMapToggle("Deriv Height Map", Float) = 0
        [NoScaleOffset] _DerivHeightMap("Deriv (AG) Height (B)", 2D) = "black" {}
        _HeightScale("Height Scale (Constant)", Float) = 0.25
        _HeightScaleModulated("Height Scale (Modulated)", Float) = 0.75

        [NoScaleOffset] _FlowMap("Flow (RG direction, B speed)", 2D) = "black" {}

        _Tiling("Tiling", Float) = 1
        _Speed ("Speed", Float) = 1
        _FlowStrength("Flow Strength", Float) = 1
        
        _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0

        [Enum(Off, 0, On, 1)] _DepthWrite("Depth Write", Float) = 1

        [Toggle(_CLIPPING)] _Clipping("Alpha Clipping", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        
        [Toggle(_PREMULTIPLY_ALPHA)] _PremultiplyAlpha("Premultiply Alpha", Float) = 0

        [KeywordEnum(On, Clip, Dither, Off)] _Shadows("Shadows", Float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows", Float) = 1
    }
    SubShader
    {
        HLSLINCLUDE
        #include "../../ShaderLibrary/Common.hlsl"
        #include "../../ShaderLibrary/ComplexLitInput.hlsl"
        ENDHLSL

        Pass
        {
            Tags
            { "LightMode" = "CustomLit" }

            Blend [_SrcBlend] [_DstBlend], One OneMinusSrcAlpha
            ZWrite [_DepthWrite]

            HLSLPROGRAM

            #pragma target 3.5
            
            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTIPLY_ALPHA
            #pragma shader_feature _RECEIVE_SHADOWS
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _DERIV_HEIGHT_MAP
            
            #pragma multi_compile_instancing
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _OTHER_PCF3 _OTHER_PCF5 _OTHER_PCF7
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile _ _LIGHTS_PER_OBJECT

            #pragma vertex vert
            #pragma fragment frag

            #include "DirectionalFlowPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags
            { "LightMode" = "ShadowCaster" }

            ColorMask 0

            HLSLPROGRAM
            
            #pragma target 3.5

            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER

            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vert
            #pragma fragment frag

            #include "../ShadowCasterPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags
            { "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM

            #pragma target 3.5

            #pragma vertex vert
            #pragma fragment frag

            #include "../MetaPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "CustomShaderGUI"
}