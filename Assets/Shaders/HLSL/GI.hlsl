#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#ifdef LIGHTMAP_ON
    #define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1;
    #define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;
    #define TRANSFER_GI_DATA(input, output) output.lightMapUV = input.lightMapUV;
    #define GI_FRAGMENT_DATA(input) input.lightMapUV
#else 
    #define GI_ATTRIBUTE_DATA
    #define GI_VARYINGS_DATA
    #define TRANSFER_GI_DATA(input, output)
    #define GI_FRAGMENT_DATA(input) 0.0f
#endif

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

#include "BRDF.hlsl"
#include "Shadows.hlsl"

// Lightmap
TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

// Light Probe Proxy Volume
TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

// Shadow mask
TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

// Environment map
TEXTURECUBE(unity_SpecCube0);
SAMPLER(samplerunity_SpecCube0);

struct GI
{
    float3 diffuse;
    float3 specular;
    ShadowMask shadowMask;
};

float3 SampleLightMap(float2 lightMapUV)
{
#ifdef LIGHTMAP_ON
    return SampleSingleLightmap(
           TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap),
           lightMapUV, unity_LightmapST,
    #ifdef UNITY_LIGHTMAP_FULL_HDR
           false,
    #else
           true,
    #endif
           float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0f, 0.0f)
    );
#else
    return 0.0f;
#endif
}

float3 SampleLightProbe(Surface surface)
{
#ifdef LIGHTMAP_ON
    return 0.0f;
#else
    if (unity_ProbeVolumeParams.x)
    {
        // Sample light probe proxy volume
        return SampleProbeVolumeSH4(
            TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
            surface.posW, surface.normal,
            unity_ProbeVolumeWorldToObject,
            unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
            unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
        );
    }
    else
    {
        // Calculate light probe lighting
        float4 coefficients[7];
        coefficients[0] = unity_SHAr;
        coefficients[1] = unity_SHAg;
        coefficients[2] = unity_SHAb;
        coefficients[3] = unity_SHBr;
        coefficients[4] = unity_SHBg;
        coefficients[5] = unity_SHBb;
        coefficients[6] = unity_SHC;
        return max(0.0f, SampleSH9(coefficients, surface.normal));
    }
#endif
}

float4 SampleBakedShadows(float2 lightMapUV, Surface surface)
{
#ifdef LIGHTMAP_ON
    return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
#else
    if (unity_ProbeVolumeParams.x)
    {
        // Sample light probe proxy volume for occlusion
        return SampleProbeOcclusion(
            TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
            surface.posW,  unity_ProbeVolumeWorldToObject,
            unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
            unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
        );
    }
    else
    {
        // Return probes occlusion
        return unity_ProbesOcclusion;
    }
#endif
}

float3 SampleEnvironment(Surface surface, BRDF brdf)
{
    float3 uvw = reflect(-surface.toEye, surface.normal);
    float mip = PerceptualRoughnessToMipmapLevel(brdf.perceptualRoughness); // Defined in ImageBasedLighting.hlsl
    float4 environment = SAMPLE_TEXTURECUBE_LOD(
        unity_SpecCube0, samplerunity_SpecCube0, uvw, mip
    );
    return DecodeHDREnvironment(environment, unity_SpecCube0_HDR);;
}

GI GetGI(float2 lightMapUV, Surface surface, BRDF brdf)
{
    GI gi;
    ZERO_INITIALIZE(GI, gi);

    gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surface);
    gi.specular = SampleEnvironment(surface, brdf);

    float2 shadowMaskUV = lightMapUV * unity_LightmapST.xy + unity_LightmapST.zw;

#if defined(_SHADOW_MASK_ALWAYS)
    gi.shadowMask.always = true;
    gi.shadowMask.shadows = SampleBakedShadows(shadowMaskUV, surface);
#elif defined(_SHADOW_MASK_DISTANCE)
    gi.shadowMask.distance = true;
    gi.shadowMask.shadows = SampleBakedShadows(shadowMaskUV, surface);
#else
    gi.shadowMask.distance = false;
    gi.shadowMask.shadows = 1.0f;
#endif

    return gi;
}

#endif