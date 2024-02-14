#ifndef CUSTOM_INPUT_CONFIG_INCLUDED
#define CUSTOM_INPUT_CONFIG_INCLUDED

struct InputConfig
{
    Fragment frag;

    // Vertex color
    float4 color;

    // Base map
    float2 baseUV;

    // Complex map
    float2 detailUV;
    bool useMask;
    bool useDetail;

    // Filpbook
    float3 flipbookUVB;
    bool flipbookBlending;

    // Particles
    bool nearFade;
    bool softParticles;
};

InputConfig GetInputConfig(float4 posH, float2 baseUV, float2 detailUV = 0.0f)
{
    InputConfig input;
    input.frag = GetFragment(posH);
    input.color = 1.0f;
    input.baseUV = baseUV;

#ifdef _MASK_MAP
    input.useMask = true;
#else
    input.useMask = false;
#endif
    
#ifdef _DETAIL_MAP
    input.detailUV = detailUV;
    input.useDetail = true;
#else
    input.detailUV = 0.0f;
    input.useDetail = false;
#endif

    input.flipbookUVB = 0.0f;
    input.flipbookBlending = false;

    input.nearFade = false;
    input.softParticles = false;

    return input;
}

#endif