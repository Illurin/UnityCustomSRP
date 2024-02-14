#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

struct Attributes
{
    float3 posL : Position;
    float2 texCoord : TexCoord0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posH : SV_Position;
    float2 texCoord : VAR_TEXCOORD;
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

    output.texCoord = TransformBaseUV(input.texCoord);

    return output;
}

float4 frag(Varyings input) : SV_Target
{
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

    InputConfig config = GetInputConfig(input.posH, input.texCoord);
    float4 finalColor = GetBase(config);

#ifdef _CLIPPING
    clip(finalColor.a - GetCutoff(config));
#endif

    return float4(finalColor.rgb, GetFinalAlpha(finalColor.a));
}

#endif