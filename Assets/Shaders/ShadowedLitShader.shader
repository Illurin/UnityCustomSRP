Shader "Custom Render Pipeline/Shadowed Lit Shader"
{
    Properties
    {
        _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _BaseMap("Texture", 2D) = "white" {}

        _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        [NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
        [HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0

        [Enum(Off, 0, On, 1)] _DepthWrite("Depth Write", Float) = 1

        [Toggle(_CLIPPING)] _Clipping("Alpha Clipping", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        
        [Toggle(_PREMULTIPLY_ALPHA)] _PremultiplyAlpha("Premultiply Alpha", Float) = 0

        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
    }
    SubShader
    {
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/LitInput.hlsl"
        ENDHLSL

        Pass
        {
            Tags
            { "LightMode" = "CustomLit" }

            Blend [_SrcBlend] [_DstBlend], One OneMinusSrcAlpha
            ZWrite [_DepthWrite]

            HLSLPROGRAM
            
            // Turn off WebGL 1.0 and OpenGL ES 2.0 support
            #pragma target 3.5

            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTIPLY_ALPHA
            #pragma shader_feature _RECEIVE_SHADOWS

            #pragma multi_compile_instancing
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _OTHER_PCF3 _OTHER_PCF5 _OTHER_PCF7
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ _LIGHTS_PER_OBJECT

            #pragma vertex vert
            #pragma fragment frag

            #include "ShadowedLitPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags
            { "LightMode" = "ShadowCaster" }

            ColorMask 0

            HLSLPROGRAM
            
            // Turn off WebGL 1.0 and OpenGL ES 2.0 support
            #pragma target 3.5

            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER

            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "ShadowCasterPass.hlsl"

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

            #include "MetaPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "CustomShaderGUI"
}