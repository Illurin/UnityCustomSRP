#ifndef CUSTOM_PARTICLE_UNLIT_PASS_INCLUDED
#define CUSTOM_PARTICLE_UNLIT_PASS_INCLUDED

struct Attributes
{
    float3 posL : Position;
    float4 color : COLOR;
#ifdef _FLIPBOOK_BLENDING
    float4 texCoord : TEXCOORD0;
    float flipbookBlend : TEXCOORD1;
#else
    float2 texCoord : TexCoord0;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posH : SV_Position;
#ifdef _VERTEX_COLORS
    float4 color : VAR_COLOR;
#endif
    float2 texCoord : VAR_TEXCOORD;
#ifdef _FLIPBOOK_BLENDING
    float3 flipbookUVB : VAR_FLIPBOOK;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings vert(Attributes input)
{
    Varyings output;
    
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    float3 posW = TransformObjectToWorld(input.posL);
    output.posH = TransformWorldToHClip(posW);

#ifdef _VERTEX_COLORS
    output.color = input.color;
#endif

    output.texCoord = TransformBaseUV(input.texCoord.xy);

#ifdef _FLIPBOOK_BLENDING
    output.flipbookUVB.xy = TransformBaseUV(input.texCoord.zw);
    output.flipbookUVB.z = input.flipbookBlend;
#endif

    return output;
}

float4 frag(Varyings input) : SV_Target
{
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

    InputConfig config = GetInputConfig(input.posH, input.texCoord);
#ifdef _VERTEX_COLORS
    config.color = input.color;
#endif
#ifdef _FLIPBOOK_BLENDING
    config.flipbookUVB = input.flipbookUVB;
    config.flipbookBlending = true;
#endif
#ifdef _NEAR_FADE
    config.nearFade = true;
#endif
#ifdef _SOFT_PARTICLES
    config.softParticles = true;
#endif

    float4 finalColor = GetBase(config);

#ifdef _CLIPPING
    clip(finalColor.a - GetCutoff(config));
#endif
    
#ifdef _DISTORTION
    float2 distortion = GetDistortion(config) * finalColor.a;
    finalColor.rgb = lerp(
        GetFramebufferColor(config.frag, distortion).rgb, finalColor.rgb,
        saturate(finalColor.a - GetDistortionBlend(config))
    );
#endif

    return float4(finalColor.rgb, GetFinalAlpha(finalColor.a));
}

#endif