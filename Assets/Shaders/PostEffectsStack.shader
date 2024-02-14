Shader "Custom Render Pipeline/Post Effects Stack"
{
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off
        
        HLSLINCLUDE
        #include "HLSL/Common.hlsl"
        #include "HLSL/PostEffectsPasses.hlsl"
        ENDHLSL

        Pass
        {
            Name "Bloom Add"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomAddPassFrag

            ENDHLSL
        }
        
        Pass
        {
            Name "Bloom Horizontal"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomHorizontalPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Bloom Prefilter"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomPrefilterPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Bloom Prefilter Fireflies"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomPrefilterFirefliesPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Bloom Scatter"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomScatterPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Bloom Scatter Final"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomScatterFinalPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Bloom Vertical"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment BloomVerticalPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Copy"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment CopyPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Color Grading None"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment ColorGradingNonePassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Color Grading ACES"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment ColorGradingACESPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Color Grading Neutral"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment ColorGradingNeutralPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Color Grading Reinhard"
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment ColorGradingReinhardPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Color Grading Final"
            
            Blend [_FinalSrcBlend] [_FinalDstBlend]

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment ColorGradingFinalPassFrag

            ENDHLSL
        }

        Pass {
            Name "Color Grading Final With Luma"

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment ColorGradingFinalWithLumaPassFrag

            ENDHLSL
        }

        Pass
        {
            Name "Final Rescale"

            Blend [_FinalSrcBlend] [_FinalDstBlend]
            
            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex DefaultPassVert
            #pragma fragment FinalRescalePassFrag

            ENDHLSL
        }

        Pass
        {
            Name "FXAA"

            Blend [_FinalSrcBlend] [_FinalDstBlend]
            
            HLSLPROGRAM

            #pragma target 3.5

            #pragma multi_compile _ FXAA_QUALITY_MEDIUM FXAA_QUALITY_LOW

            #pragma vertex DefaultPassVert
            #pragma fragment FXAAPassFrag

            #include "HLSL/FXAAPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "FXAA With Luma"

            Blend [_FinalSrcBlend] [_FinalDstBlend]
            
            HLSLPROGRAM

            #pragma target 3.5

            #pragma multi_compile _ _FXAA_QUALITY_MEDIUM _FXAA_QUALITY_LOW

            #pragma vertex DefaultPassVert
            #pragma fragment FXAAPassFrag

            #define FXAA_ALPHA_CONTAINS_LUMA
            #include "HLSL/FXAAPass.hlsl"

            ENDHLSL
        }
    }

    CustomEditor "CustomShaderGUI"
}