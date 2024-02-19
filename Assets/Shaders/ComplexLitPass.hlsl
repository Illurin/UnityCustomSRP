#ifndef CUSTOM_COMPLEX_LIT_PASS_INCLUDED
#define CUSTOM_COMPLEX_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Lighting.hlsl"
#include "../ShaderLibrary/LOD.hlsl"

struct Attributes
{
    float3 posL     : POSITION;
    float3 normalL  : NORMAL;
#ifdef _NORMAL_MAP
    float4 tangentL : TANGENT;
#endif
    float2 texCoord : TEXCOORD0;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posH     : SV_POSITION;
    float3 posW     : VAR_POSW;
    float3 normalW  : VAR_NORMAL;
#ifdef _NORMAL_MAP
    float4 tangentW : VAR_TANGENT;
#endif
    float2 baseUV   : VAR_BASE_UV;
#ifdef _DETAIL_MAP
    float2 detailUV : VAR_DETAIL_UV;
#endif
    GI_VARYINGS_DATA
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

#ifdef _NORMAL_MAP
    output.tangentW =
        float4(TransformObjectToWorldDir(input.tangentL.xyz), input.tangentL.w);
#endif

    output.baseUV = TransformBaseUV(input.texCoord);
#ifdef _DETAIL_MAP
    output.detailUV = TransformDetailUV(input.texCoord);
#endif

    TRANSFER_GI_DATA(input, output);

    return output;
}

float4 frag(Varyings input) : SV_TARGET
{
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

#ifdef _DETAIL_MAP
    InputConfig config = GetInputConfig(input.posH, input.baseUV, input.detailUV);
#else
    InputConfig config = GetInputConfig(input.posH, input.baseUV);
#endif

    // LOD cross fade
    ClipLOD(config.frag, unity_LODFade.x);

    float4 finalColor = GetBase(config);

#ifdef _CLIPPING
    clip(finalColor.a - GetCutoff(config));
#endif

    Surface surface;
    ZERO_INITIALIZE(Surface, surface);
    surface.albedo             = finalColor.rgb;
    surface.alpha              = finalColor.a;
    surface.posW               = input.posW;
    surface.depth              = -TransformWorldToView(input.posW).z;
    surface.toEye              = normalize(_WorldSpaceCameraPos - input.posW);
#ifdef _NORMAL_MAP
    surface.interpolatedNormal = normalize(input.normalW);
    surface.normal             = NormalTangentToWorld(GetNormalTangentSpace(config),
                                                      surface.interpolatedNormal, input.tangentW);
#else
    surface.normal             = normalize(input.normalW);
    surface.interpolatedNormal = surface.normal;
#endif
    surface.metallic           = GetMetallic(config);
    surface.occlusion          = GetOcclusion(config);
    surface.smoothness         = GetSmoothness(config);
    surface.fresnelStrength    = GetFresnel(config);
    surface.dither             = InterleavedGradientNoise(input.posH.xy, 0);
    surface.renderingLayerMask = asuint(unity_RenderingLayer.x);
    
#ifdef _PREMULTIPLY_ALPHA
    BRDF brdf = GetBRDF(surface, true);
#else
    BRDF brdf = GetBRDF(surface);
#endif

    // Calculate GI
    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
    finalColor.rgb = GetGILighting(surface, brdf, gi);

    // Calculate emission
    finalColor.rgb += GetEmission(config);

    return float4(finalColor.rgb, GetFinalAlpha(finalColor.a));
}

#endif