#ifndef CUSTOM_SHADOWED_LIT_PASS_INCLUDED
#define CUSTOM_SHADOWED_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float3 posL     : POSITION;
    float3 normalL  : NORMAL;
    float2 texCoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posH     : SV_POSITION;
    float3 posW     : VAR_POSW;
    float3 normalW  : VAR_NORMAL;
    float2 texCoord : VAR_TEXCOORD;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings vert(Attributes input)
{
    Varyings output;
    
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    output.posW = TransformObjectToWorld(input.posL);
    output.posH = TransformWorldToHClip(output.posW);
    output.normalW = TransformObjectToWorldNormal(input.normalL);

    output.texCoord = TransformBaseUV(input.texCoord);

    return output;
}

float4 frag(Varyings input) : SV_TARGET
{
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

    InputConfig config = GetInputConfig(input.posH, input.texCoord);

    float4 finalColor = GetBase(config);

#ifdef _CLIPPING
    clip(finalColor.a - GetCutoff(config));
#endif

    Surface surface;
    ZERO_INITIALIZE(Surface, surface);
    surface.color              = finalColor.rgb;
    surface.alpha              = finalColor.a;
    surface.posW               = input.posW;
    surface.depth              = -TransformWorldToView(input.posW).z;
    surface.toEye              = normalize(_WorldSpaceCameraPos - input.posW);
    surface.normal             = normalize(input.normalW);
    surface.interpolatedNormal = surface.normal;
    surface.metallic           = GetMetallic(config);
    surface.occlusion          = GetOcclusion(config);
    surface.smoothness         = GetSmoothness(config);
    surface.dither             = InterleavedGradientNoise(input.posH.xy, 0);
    surface.renderingLayerMask = asuint(unity_RenderingLayer.x);
    
#ifdef _PREMULTIPLY_ALPHA
    BRDF brdf = GetBRDF(surface, true);
#else
    BRDF brdf = GetBRDF(surface);
#endif

    // Calculate lighting
    finalColor.rgb = GetLighting(surface, brdf);
    return float4(finalColor.rgb, GetFinalAlpha(finalColor.a));
}

#endif