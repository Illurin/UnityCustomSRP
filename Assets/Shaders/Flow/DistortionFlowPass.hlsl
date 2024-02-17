#ifndef CUSTOM_DISTORTION_FLOW_PASS_INCLUDED
#define CUSTOM_DISTORTION_FLOW_PASS_INCLUDED

#include "../../ShaderLibrary/Lighting.hlsl"
#include "../../ShaderLibrary/Flow.hlsl"

struct Attributes
{
    float3 posL     : Position;
    float3 normalL  : NORMAL;
#if defined(_NORMAL_MAP) || defined(_DERIV_HEIGHT_MAP)
    float4 tangentL : TANGENT;
#endif
    float2 texCoord : TexCoord0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 posH     : SV_Position;
    float3 posW     : VAR_POSW;
    float3 normalW  : VAR_NORMAL;
#if defined(_NORMAL_MAP) || defined(_DERIV_HEIGHT_MAP)
    float4 tangentW : VAR_TANGENT;
#endif
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

#if defined(_NORMAL_MAP) || defined(_DERIV_HEIGHT_MAP)
    output.tangentW =
        float4(TransformObjectToWorldDir(input.tangentL.xyz), input.tangentL.w);
#endif

    output.texCoord = TransformBaseUV(input.texCoord);

    return output;
}

float4 _Time;

TEXTURE2D(_FlowMap);
TEXTURE2D(_DerivHeightMap);
SAMPLER(sampler_FlowMap);
SAMPLER(sampler_DerivHeightMap);

float _HeightScale, _HeightScaleModulated;
float _UJump, _VJump, _Tiling, _Speed, _FlowStrength, _FlowOffset;

float3 UnpackDerivativeHeight(float4 textureData)
{
    float3 data = textureData.agb;
    data.xy = data.xy * 2.0f - 1.0f;
    return data;
}

float4 frag(Varyings input) : SV_Target
{
    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

    // Sample flow map
    float3 flow = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, input.texCoord).rgb;
    flow.xy = flow.xy * 2.0f - 1.0f;
    flow *= _FlowStrength;
    float noise = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, input.texCoord).a;
    float time = _Time.y * _Speed + noise;

    // Get flow uvw
    float2 jump = float2(_UJump, _VJump);
    float3 uvwA = FlowUVW(input.texCoord, flow.xy, jump, _FlowOffset, _Tiling, time, false);
    float3 uvwB = FlowUVW(input.texCoord, flow.xy, jump, _FlowOffset, _Tiling, time, true);
    
    // Get final color
    InputConfig configA = GetInputConfig(input.posH, uvwA.xy);
    InputConfig configB = GetInputConfig(input.posH, uvwB.xy);

    float4 baseA = GetBase(configA) * uvwA.z;
    float4 baseB = GetBase(configB) * uvwB.z;

    float4 finalColor = baseA + baseB;

#ifdef _CLIPPING
    clip(finalColor.a - GetCutoff(configA));
#endif

    // Set surface structure
    Surface surface;
    ZERO_INITIALIZE(Surface, surface);
    surface.color              = finalColor.rgb;
    surface.alpha              = finalColor.a;
    surface.posW               = input.posW;
    surface.depth              = -TransformWorldToView(input.posW).z;
    surface.toEye              = normalize(_WorldSpaceCameraPos - input.posW);
    surface.metallic           = GetMetallic(configA);
    surface.occlusion          = 1.0f;
    surface.smoothness         = GetSmoothness(configA);
    surface.renderingLayerMask = asuint(unity_RenderingLayer.x);
    surface.interpolatedNormal = normalize(input.normalW);

#if defined(_DERIV_HEIGHT_MAP)
    // Make the height scale variable, based on the flow speed
    float finalHeightScale = flow.z * _HeightScaleModulated + _HeightScale;
    // Get derivative height
    float3 dhA = finalHeightScale *
        UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_DerivHeightMap, uvwA.xy)) * uvwA.z;
    float3 dhB = finalHeightScale *
        UnpackDerivativeHeight(SAMPLE_TEXTURE2D(_DerivHeightMap, sampler_DerivHeightMap, uvwB.xy)) * uvwB.z;
    float3 blendNormal = normalize(float3(-(dhA.xy + dhB.xy), 1.0f));
    surface.normal = NormalTangentToWorld(blendNormal, surface.interpolatedNormal, input.tangentW);
#elif defined(_NORMAL_MAP)
    // Blend normal map
    float3 normalA = GetNormalTangentSpace(configA);
    float3 normalB = GetNormalTangentSpace(configB);
    float3 blendNormal = normalize(normalA + normalB);
    surface.normal = NormalTangentToWorld(blendNormal, surface.interpolatedNormal, input.tangentW);
#else
    surface.normal = normalize(input.normalW);
    surface.interpolatedNormal = surface.normal;
#endif

#ifdef _PREMULTIPLY_ALPHA
    BRDF brdf = GetBRDF(surface, true);
#else
    BRDF brdf = GetBRDF(surface);
#endif

    // Calculate GI
    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
    finalColor.rgb = GetGILighting(surface, brdf, gi);

    return float4(finalColor.rgb, GetFinalAlpha(finalColor.a));
}

#endif