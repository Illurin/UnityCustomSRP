#ifndef CUSTOM_UNLIT_INPUT_INCLUDED
#define CUSTOM_UNLIT_INPUT_INCLUDED

#include "InputConfig.hlsl"

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

// For SRP batching
// CBUFFER_START(UnityPerMaterial)
//     float4 _BaseColor;
//     float4 _BaseMap_ST;
// CBUFFER_END

// For GPU instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _DepthWrite)
    UNITY_DEFINE_INSTANCED_PROP(float, _NearFadeDistance)
    UNITY_DEFINE_INSTANCED_PROP(float, _NearFadeRange)
    UNITY_DEFINE_INSTANCED_PROP(float, _SoftParticlesDistance)
    UNITY_DEFINE_INSTANCED_PROP(float, _SoftParticlesRange)
    UNITY_DEFINE_INSTANCED_PROP(float, _DistortionStrength)
    UNITY_DEFINE_INSTANCED_PROP(float, _DistortionBlend)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// Input textures
TEXTURE2D(_BaseMap);
TEXTURE2D(_DistortionMap);

// Input sampler
SAMPLER(sampler_BaseMap);
SAMPLER(sampler_DistortionMap);

// Sample textures
float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float4 GetBase(InputConfig input)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
    if (input.flipbookBlending)
    {
        baseMap = lerp(
            baseMap, SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.flipbookUVB.xy),
            input.flipbookUVB.z
        );
    }
    if (input.nearFade)
    {
        float nearAttenuation = (input.frag.depth - INPUT_PROP(_NearFadeDistance)) /
                                INPUT_PROP(_NearFadeRange);
        baseMap.a *= saturate(nearAttenuation);
    }
    if (input.softParticles)
    {
        float depthDelta = input.frag.bufferDepth - input.frag.depth;
        float nearAttenuation = (depthDelta - INPUT_PROP(_SoftParticlesDistance)) /
                                INPUT_PROP(_SoftParticlesRange);
        baseMap.a *= saturate(nearAttenuation);
    }
    float4 baseColor = INPUT_PROP(_BaseColor);
    return baseMap * baseColor * input.color;
}

float4 GetMask(InputConfig input)
{
    return 0.0f;
}

float3 GetEmission(InputConfig input)
{
    return 0.0f;
}

float2 GetDistortion(InputConfig input)
{
    float4 rawMap = SAMPLE_TEXTURE2D(_DistortionMap, sampler_DistortionMap, input.baseUV);
    if (input.flipbookBlending)
    {
        rawMap = lerp(
            rawMap, SAMPLE_TEXTURE2D(_DistortionMap, sampler_DistortionMap, input.flipbookUVB.xy),
            input.flipbookUVB.z
        );
    }
    return DecodeNormal(rawMap, INPUT_PROP(_DistortionStrength)).xy;
}

// Get material properties
float GetCutoff(InputConfig input)
{
    return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig input)
{
    return 0.0f;
}

float GetSmoothness(InputConfig input)
{
    return 0.0f;
}

float GetFresnel(InputConfig input)
{
    return 0.0f;
}

float GetOcclusion(InputConfig input)
{
    return 0.0f;
}

float GetDistortionBlend(InputConfig input)
{
    return INPUT_PROP(_DistortionBlend);
}

// Only write alpha when it is transparent
float GetFinalAlpha(float alpha)
{
    return INPUT_PROP(_DepthWrite) ? 1.0f : alpha;
}

#endif