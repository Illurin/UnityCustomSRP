Shader "Custom Render Pipeline/Unlit Shader"
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
    }
    SubShader
    {
        HLSLINCLUDE
        #include "HLSL/Common.hlsl"
        #include "HLSL/UnlitInput.hlsl"
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

            #include "HLSL/UnlitPass.hlsl"

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

            #include "HLSL/MetaPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "CustomShaderGUI"
}