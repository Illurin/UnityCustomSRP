#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

#include "InputConfig.hlsl"

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

// For GPU instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _DepthWrite)
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// Input textures
TEXTURE2D(_BaseMap);
TEXTURE2D(_EmissionMap);

// Input sampler
SAMPLER(sampler_BaseMap);

// Sample textures
float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float4 GetBase(InputConfig input)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
    float4 baseColor = INPUT_PROP(_BaseColor);
    return baseMap * baseColor;
}

float3 GetEmission(InputConfig input)
{
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, input.baseUV);
    float4 color = INPUT_PROP(_EmissionColor);
    return map.rgb * color.rgb;
}

// Get material properties
float GetCutoff(InputConfig input)
{
    return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig input)
{
    return INPUT_PROP(_Metallic);
}

float GetSmoothness(InputConfig input)
{
    return INPUT_PROP(_Smoothness);
}

float GetFresnel(InputConfig input)
{
    return INPUT_PROP(_Fresnel);
}

float GetOcclusion(InputConfig input)
{
    return 1.0f;
}

// Only write alpha when it is transparent
float GetFinalAlpha(float alpha)
{
    return INPUT_PROP(_DepthWrite) ? 1.0f : alpha;
}

#endif