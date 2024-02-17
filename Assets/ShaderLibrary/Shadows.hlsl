#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_SHADOWED_OTHER_LIGHT_COUNT       16
#define MAX_CASCADE_COUNT                    4

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

// Define PCF properties
#if defined(_DIRECTIONAL_PCF3)
    #define DIRECTIONAL_FILTER_SAMPLES 4
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
    #define DIRECTIONAL_FILTER_SAMPLES 9
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
    #define DIRECTIONAL_FILTER_SAMPLES 16
    #define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#if defined(_OTHER_PCF3)
    #define OTHER_FILTER_SAMPLES 4
    #define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_OTHER_PCF5)
    #define OTHER_FILTER_SAMPLES 9
    #define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_OTHER_PCF7)
    #define OTHER_FILTER_SAMPLES 16
    #define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

// Define shadowmask properties
#if defined(_SHADOW_MASK_ALWAYS) || defined(_SHADOW_MASK_DISTANCE)
    #define SHADOWS_SHADOWMASK
#endif

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

#include "Surface.hlsl"

// Shadow atlases
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
TEXTURE2D_SHADOW(_OtherShadowAtlas);

// Shadow samplers
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

// Shadow buffer data
CBUFFER_START(_CustomShadows)

    float4 _ShadowAtlasSize;

    float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT *
                                        MAX_CASCADE_COUNT];
    int _CascadeCount;
    float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4 _CascadeData[MAX_CASCADE_COUNT];
    float3 _ShadowDistanceFade;
    
    float4x4 _OtherShadowMatrices[MAX_SHADOWED_OTHER_LIGHT_COUNT];
    float4 _OtherShadowTiles[MAX_SHADOWED_OTHER_LIGHT_COUNT];

CBUFFER_END

struct DirectionalShadowData
{
    float strength;
    int   tileIndex;
    float normalBias;
    int   shadowMaskChannel;
};

struct OtherShadowData
{
    float  strength;
    int    tileIndex;
    bool   isPoint;
    int    shadowMaskChannel;
    float3 lightPosition;
    float3 lightDirection;
    float3 spotDirection;
};

struct ShadowMask
{
    bool   always;
    bool   distance;
    float4 shadows;
};

struct ShadowData
{
    int        cascadeIndex;
    float      cascadeBlend;
    float      strength;
    ShadowMask shadowMask;
};

// Plane normals for point light shadow plane
static const float3 pointShadowPlanes[6] = {
    float3(-1.0f, 0.0f,  0.0f), // +X
    float3(1.0f,  0.0f,  0.0f), // -X
    float3(0.0f, -1.0f,  0.0f), // +Y
    float3(0.0f,  1.0f,  0.0f), // -Y
    float3(0.0f,  0.0f, -1.0f), // +Z
    float3(0.0f,  0.0f,  1.0f)  // -Z
};

float FadedShadowStrength(float distance, float scale, float fade)
{
    return saturate((1.0f - distance * scale) * fade);
}

ShadowData GetShadowData(Surface surface)
{
    ShadowData data;
    data.cascadeBlend = 1.0f;
    data.shadowMask.always = false;
    data.shadowMask.distance = false;
    data.shadowMask.shadows = 1.0f;

    // Make the shadow transition smoother by linearly fading
    data.strength = FadedShadowStrength(surface.depth, _ShadowDistanceFade.x,
                                                       _ShadowDistanceFade.y);
    
    int i;
    for (i = 0; i < _CascadeCount; ++i)
    {
        float4 sphere = _CascadeCullingSpheres[i];

        // Calculate the square distance
        float3 distance = surface.posW - sphere.xyz;
        float squaredDistance = dot(distance, distance);
        if (squaredDistance < sphere.w)
        {
            // Calculate the faded shadow strength for the cascade
            float fade = FadedShadowStrength(
                squaredDistance, _CascadeData[i].x, _ShadowDistanceFade.z
            );
            if (i == _CascadeCount - 1)
            {
                data.strength *= fade;
            }
            else
            {
                data.cascadeBlend = fade;
            }
            break;
        }
    }

    // When there aren't any cascades, so they shouldn't affect the global shadow
    if (i == _CascadeCount && _CascadeCount > 0)
        data.strength = 0.0f;

#ifdef _CASCADE_BLEND_DITHER
    // Jump to the next cascade if the blend value is less than the dither value
    else if (data.cascadeBlend < surface.dither) {
        i += 1;
    }
#endif

#ifndef _CASCADE_BLEND_SOFT
    data.cascadeBlend = 1.0f;
#endif

    data.cascadeIndex = i;

    return data;
}

float SampleDirectionalShadowAtlas(float3 shadowPos)
{
    // Sample shadowmap and return single float value with the shadow term in 0~1 range
    return SAMPLE_TEXTURE2D_SHADOW(
        _DirectionalShadowAtlas, SHADOW_SAMPLER, shadowPos
    );
}

float SampleOtherShadowAtlas(float3 shadowPos, float3 bounds)
{
    // Clamp shadow position to tile edge
    shadowPos.xy = clamp(shadowPos.xy, bounds.xy, bounds.xy + bounds.z);

    return SAMPLE_TEXTURE2D_SHADOW(
        _OtherShadowAtlas, SHADOW_SAMPLER, shadowPos
    );
}

float FilterDirectionalShadow(float3 shadowPos)
{
#ifdef DIRECTIONAL_FILTER_SETUP
    // Setup filter samples
    real weights[DIRECTIONAL_FILTER_SAMPLES];
    real2 positions[DIRECTIONAL_FILTER_SAMPLES];
    float4 size = _ShadowAtlasSize.yyxx;

    // SampleShadow_ComputeSamples_Tent(real4 shadowMapTexture_TexelSize, real2 coord,
    //                                  out real fetchesWeights[n], out real2 fetchesUV[n])
    DIRECTIONAL_FILTER_SETUP(size, shadowPos.xy, weights, positions);

    // Implement PCF
    float shadow = 0.0f;
    for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; ++i)
    {
        shadow += weights[i] * SampleDirectionalShadowAtlas(
                               float3(positions[i], shadowPos.z));
    }
    return shadow;
#else
    return SampleDirectionalShadowAtlas(shadowPos);
#endif
}

float FilterOtherShadow(float3 shadowPos, float3 bounds)
{
#ifdef OTHER_FILTER_SETUP
    real weights[OTHER_FILTER_SAMPLES];
    real2 positions[OTHER_FILTER_SAMPLES];
    float4 size = _ShadowAtlasSize.wwzz;

    OTHER_FILTER_SETUP(size, shadowPos.xy, weights, positions);

    // Implement PCF
    float shadow = 0.0f;
    for (int i = 0; i < OTHER_FILTER_SAMPLES; ++i)
    {
        shadow += weights[i] * SampleOtherShadowAtlas(
                               float3(positions[i], shadowPos.z), bounds);
    }
    return shadow;
#else
    return SampleOtherShadowAtlas(shadowPos, bounds);
#endif
}

float GetCascadedShadow(DirectionalShadowData directional, ShadowData global, Surface surface)
{
    // Apply normal bias by texel size
    float3 normalBias = directional.normalBias *
                        surface.interpolatedNormal * _CascadeData[global.cascadeIndex].y;

    float3 shadowPos = mul(_DirectionalShadowMatrices[directional.tileIndex],
                           float4(surface.posW + normalBias, 1.0f)).xyz;
    float shadow = FilterDirectionalShadow(shadowPos);

    // Calculate cascade blend
    if (global.cascadeBlend < 1.0f)
    {
        // Sample from the next cascade
        normalBias = surface.interpolatedNormal *
                     (directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
        shadowPos = mul(_DirectionalShadowMatrices[directional.tileIndex + 1],
                        float4(surface.posW + normalBias, 1.0f)).xyz;

        // Interpolate between both values
        shadow = lerp(FilterDirectionalShadow(shadowPos), shadow, global.cascadeBlend);
    }
    
    return shadow;
}

float GetOtherShadow(OtherShadowData other, ShadowData global, Surface surface)
{
    // Adjust tile index and light plane
    float tileIndex = other.tileIndex;
    float3 lightPlane = other.spotDirection;
    if (other.isPoint)
    {
        float faceOffset = CubeMapFaceID(other.lightDirection);    // Find the face offset
        tileIndex += faceOffset;
        lightPlane = pointShadowPlanes[faceOffset];
    }

    float4 tileData = _OtherShadowTiles[tileIndex];

    // Scale normal bias with distance from the light plane
    float3 surfaceToLight = other.lightPosition - surface.posW;
    float distanceToLightPlane = dot(surfaceToLight, lightPlane);

    // Apply normal bias by texel size
    float3 normalBias = surface.interpolatedNormal * (distanceToLightPlane * tileData.w);

    float4 shadowPos = mul(_OtherShadowMatrices[tileIndex],
                           float4(surface.posW + normalBias, 1.0f));

    // Execute perspective division
    return FilterOtherShadow(shadowPos.xyz / shadowPos.w, tileData.xyz);
}

float GetBakedShadow(ShadowMask mask, int channel)
{
    float shadow = 1.0f;
    if (mask.always || mask.distance)
    {
        if (channel >= 0)
        {
            shadow = mask.shadows[channel];
        }
    }
    return shadow;
}

// Lerp baked shadow to shadow strength
float GetBakedShadow(ShadowMask mask, int channel, float strength)
{
    if (mask.always || mask.distance)
    {
        return lerp(1.0f, GetBakedShadow(mask, channel), strength);
    }
    return 1.0f;
}

float MixBakedAndRealtimeShadows(ShadowData global, float shadow, int shadowMaskChannel, float strength)
{
    float baked = GetBakedShadow(global.shadowMask, shadowMaskChannel);

    // Always shadowmask
    if (global.shadowMask.always) {
        shadow = lerp(1.0f, shadow, global.strength);
        shadow = min(baked, shadow);
        return lerp(1.0f, shadow, strength);
    }
    // Distance shadowmask
    if (global.shadowMask.distance)
    {
        shadow = lerp(baked, shadow, global.strength);
        return lerp(1.0f, shadow, strength);
    }
    return lerp(1.0f, shadow, strength * global.strength);
}

float GetDirectionalShadowAttenuation(DirectionalShadowData directional,
                                      ShadowData global, Surface surface)
{
#ifndef _RECEIVE_SHADOWS
    return 1.0f;
#endif

    float shadow = 0.0f;
    if (directional.strength * global.strength <= 0.0f)
    {
        // Return the modulated baked shadow only
        shadow = GetBakedShadow(global.shadowMask, directional.shadowMaskChannel,
                                abs(directional.strength));
    }
    else
    {
        // Mix baked and realtime shadows
        shadow = GetCascadedShadow(directional, global, surface);
        shadow = MixBakedAndRealtimeShadows(global, shadow, directional.shadowMaskChannel,
                                            directional.strength);
    }
    
    return shadow;
}

float GetOtherShadowAttenuation(OtherShadowData other,
                                ShadowData global, Surface surface)
{
#ifndef _RECEIVE_SHADOWS
    return 1.0f;
#endif
    
    float shadow = 0.0f;
    if (other.strength * global.strength <= 0.0f)
    {
        shadow = GetBakedShadow(global.shadowMask, other.shadowMaskChannel,
                                abs(other.strength));
    }
    else
    {
        shadow = GetOtherShadow(other, global, surface);
        shadow = MixBakedAndRealtimeShadows(global, shadow, other.shadowMaskChannel,
                                            other.strength);
    }

    return shadow;
}

#endif