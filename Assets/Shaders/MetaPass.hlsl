#ifndef CUSTOM_META_PASS_INCLUDED
#define CUSTOM_META_PASS_INCLUDED

#include "../ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float3 posL       : POSITION;
    float2 texCoord   : TEXCOORD0;
    float2 lightMapUV : TEXCOORD1;
};

struct Varyings
{
    float4 posH     : SV_POSITION;
    float2 texCoord : VAR_TEXCOORD;
};
                                              
bool4 unity_MetaFragmentControl;
float unity_OneOverOutputBoost;
float unity_MaxOutputValue;

Varyings vert(Attributes input)
{
    Varyings output;

    input.posL.xy = input.lightMapUV * unity_LightmapST.xy
                  + unity_LightmapST.zw;
    input.posL.z = input.posL.z > 0.0f ? FLT_MIN : 0.0f;
    output.posH = TransformWorldToHClip(input.posL);

    output.texCoord = TransformBaseUV(input.texCoord);

    return output;
}

float4 frag(Varyings input) : SV_TARGET
{
    InputConfig config = GetInputConfig(input.posH, input.texCoord);

    float4 finalColor = GetBase(config);

    Surface surface;
    ZERO_INITIALIZE(Surface, surface);
    surface.color      = finalColor.rgb;
    surface.metallic   = GetMetallic(config);
    surface.smoothness = GetSmoothness(config);

    BRDF brdf = GetBRDF(surface);

    // Calculate meta data
    float4 meta = 0.0f;
    if (unity_MetaFragmentControl.x)
    {
        // Diffuse reflectivity is requested
        meta = float4(brdf.diffuse, 1.0f);
        meta.rgb += brdf.specular * brdf.roughness * 0.5f;
        meta.rgb = min(
            PositivePow(meta.rgb, unity_OneOverOutputBoost), unity_MaxOutputValue
        );
    }
    else if (unity_MetaFragmentControl.y)
    {
        // Baking of emission
        meta = float4(GetEmission(config), 1.0f);
    }

    return meta;
}

#endif