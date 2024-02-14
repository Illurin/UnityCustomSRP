#ifndef CUSTOM_COMPLEX_LIT_INPUT_INCLUDED
#define CUSTOM_COMPLEX_LIT_INPUT_INCLUDED

#include "InputConfig.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

// For GPU instancing
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _DepthWrite)
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
    UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// Input textures
TEXTURE2D(_BaseMap);
TEXTURE2D(_NormalMap);
TEXTURE2D(_MaskMap);
TEXTURE2D(_EmissionMap);
TEXTURE2D(_DetailMap);
TEXTURE2D(_DetailNormalMap);

// Input sampler
SAMPLER(sampler_BaseMap);
SAMPLER(sampler_DetailMap);

// Sample textures
float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = INPUT_PROP(_BaseMap_ST);
    return baseUV * baseST.xy + baseST.zw;
}

float2 TransformDetailUV(float2 detailUV)
{
    float4 detailST = INPUT_PROP(_DetailMap_ST);
    return detailUV * detailST.xy + detailST.zw;
}

float4 GetDetail(InputConfig input)
{
    if (input.useDetail)
    {
        float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, input.detailUV);
        return map * 2.0f - 1.0f;
    }
    return 0.0f;
}

float4 GetMask(InputConfig input)
{
    if (input.useMask)
    {
        return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, input.baseUV);
    }
    return 1.0f;
}

float4 GetBase(InputConfig input)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
    float4 baseColor = INPUT_PROP(_BaseColor);

    if (input.useDetail)
    {
        float detail = GetDetail(input).r * INPUT_PROP(_DetailAlbedo);
        float mask = GetMask(input).b;

        // Lerp detailed albedo in gamma space
        baseMap.rgb = lerp(sqrt(baseMap.rgb), detail < 0.0f ? 0.0f : 1.0f, abs(detail) * mask);
        baseMap.rgb *= baseMap.rgb;
    }

    return baseMap * baseColor;
}

float3 GetEmission(InputConfig input)
{
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, input.baseUV);
    float4 color = INPUT_PROP(_EmissionColor);
    return map.rgb * color.rgb;
}

float3 GetNormalTangentSpace(InputConfig input)
{
    // Sample normal map
    float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, input.baseUV);
    float scale = INPUT_PROP(_NormalScale);
    float3 normal = DecodeNormal(map, scale);

    if (input.useDetail)
    {
        // Sample detail normal map
        map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, input.detailUV);
        scale = INPUT_PROP(_DetailNormalScale) * GetMask(input).b;
        float3 detail = DecodeNormal(map, scale);

        // Combine both maps
        normal = BlendNormalRNM(normal, detail);

//      real3 BlendNormalRNM(real3 n1, real3 n2)
//      {
//          real3 t = n1.xyz + real3(0.0, 0.0, 1.0);
//          real3 u = n2.xyz * real3(-1.0, -1.0, 1.0);
//          real3 r = (t / t.z) * dot(t, u) - u;
//          return r;
//      }
    }

    return normal;
}

// Get material properties
float GetCutoff(InputConfig input)
{
    return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig input)
{
    float metallic = INPUT_PROP(_Metallic);
    metallic *= GetMask(input).r;
    return metallic;
}

float GetSmoothness(InputConfig input)
{
    float smoothness = INPUT_PROP(_Smoothness);
    smoothness *= GetMask(input).a;

    if (input.useDetail)
    {
        float detail = GetDetail(input).b * INPUT_PROP(_DetailSmoothness);
        float mask = GetMask(input).b;

        // Lerp detailed smoothness
        smoothness = lerp(smoothness, detail < 0.0f ? 0.0f : 1.0f, abs(detail) * mask);
    }

    return smoothness;
}

float GetFresnel(InputConfig input)
{
    return INPUT_PROP(_Fresnel);
}

float GetOcclusion(InputConfig input)
{
    float strength = INPUT_PROP(_Occlusion);
    float occlusion = GetMask(input).g;
    occlusion = lerp(occlusion, 1.0f, strength);
    return occlusion;
}

// Only write alpha when it is transparent
float GetFinalAlpha(float alpha)
{
    return INPUT_PROP(_DepthWrite) ? 1.0f : alpha;
}

#endif