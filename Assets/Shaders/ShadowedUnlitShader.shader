Shader "Custom Render Pipeline/Shadowed Unlit Shader"
{
    Properties
    {
        _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _BaseMap("Texture", 2D) = "white" {}

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0

        [Enum(Off, 0, On, 1)] _DepthWrite("Depth Write", Float) = 1

        [Toggle(_CLIPPING)] _Clipping("Alpha Clipping", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        [KeywordEnum(On, Clip, Dither, Off)]
        _Shadows ("Shadows", Float) = 0
    }
    SubShader
    {
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/UnlitInput.hlsl"
        ENDHLSL

        Pass
        {
            Blend [_SrcBlend] [_DstBlend], One OneMinusSrcAlpha
            ZWrite [_DepthWrite]

            HLSLPROGRAM
            
            #pragma shader_feature _CLIPPING

            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "UnlitPass.hlsl"

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