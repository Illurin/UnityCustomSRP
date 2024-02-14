Shader "Hidden/Custom Render Pipeline/Camera Renderer"
{
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off
        
        HLSLINCLUDE
        #include "HLSL/Common.hlsl"
        #include "HLSL/CameraRendererPasses.hlsl"
        ENDHLSL

        Pass
        {
            Name "Copy"

            Blend [_CameraSrcBlend] [_CameraDstBlend]

            HLSLPROGRAM

            #pragma target 3.5

            #pragma vertex DefaultPassVert
            #pragma fragment CopyPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Copy Depth"

            ColorMask 0
            ZWrite On
            
            HLSLPROGRAM

            #pragma target 3.5

            #pragma vertex DefaultPassVert
            #pragma fragment CopyDepthPassFrag

            ENDHLSL
        }
    }
}