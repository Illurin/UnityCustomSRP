#ifndef CUSTOM_SHADOW_CASTER_PASS_INCLUDED
#define CUSTOM_SHADOW_CASTER_PASS_INCLUDED

#include "LOD.hlsl"

struct Attributes
{
    float3 posL : POSITION;
    float2 texCoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posH : SV_POSITION;
    float2 texCoord : VAR_TEXCOORD;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

bool _ShadowPancaking;

Varyings vert(Attributes input)
{
    Varyings output;
    
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    float3 posW = TransformObjectToWorld(input.posL);
    output.posH = TransformWorldToHClip(posW);

    // Solve Unity shadow pancaking
    // by clamping the vertex positions to the near plane
    if (_ShadowPancaking)
    {
#if UNITY_REVERSED_Z
    output.posH.z =
        min(output.posH.z, output.posH.w * UNITY_NEAR_CLIP_VALUE);
#else
    output.posH.z =
        max(output.posH.z, output.posH.w * UNITY_NEAR_CLIP_VALUE);
#endif
    }

    output.texCoord = TransformBaseUV(input.texCoord);

    return output;
}

void frag(Varyings input)
{
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

    InputConfig config = GetInputConfig(input.posH, input.texCoord);

    // LOD cross fade
    ClipLOD(config.frag, unity_LODFade.x);

    float4 finalColor = GetBase(config);

#if defined(_SHADOWS_CLIP)
    clip(finalColor.a - GetCutoff(config));
#elif defined(_SHADOWS_DITHER)
    float dither = InterleavedGradientNoise(input.posH.xy, 0);
    clip(finalColor.a - dither);
#endif
}

#endif