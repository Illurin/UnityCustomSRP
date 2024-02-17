#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_OTHER_LIGHT_COUNT       64

#define MIN_REFLECTIVITY            0.04

#include "GI.hlsl"

CBUFFER_START(_CustomLight)

    // Directional lights
    int _DirectionalLightCount;
    float3 _DirectionalLightStrengths[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirectionsAndMasks[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];

    // Other lights
    int _OtherLightCount;
    float3 _OtherLightStrengths[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightPositions[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightDirectionsAndMasks[MAX_OTHER_LIGHT_COUNT];
    float2 _OtherLightSpotAngles[MAX_OTHER_LIGHT_COUNT];
    float4 _OtherLightShadowData[MAX_OTHER_LIGHT_COUNT];

CBUFFER_END

// Get shadow data functions
DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData)
{
    DirectionalShadowData data;
    data.strength = _DirectionalLightShadowData[lightIndex].x; // * shadowData.strength;
    data.tileIndex =
        _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
    return data;
}

OtherShadowData GetOtherShadowData(int lightIndex)
{
    OtherShadowData data;
    ZERO_INITIALIZE(OtherShadowData, data);
    data.strength = _OtherLightShadowData[lightIndex].x;
    data.tileIndex = _OtherLightShadowData[lightIndex].y;
    data.isPoint = _OtherLightShadowData[lightIndex].z == 1.0f;
    data.shadowMaskChannel = _OtherLightShadowData[lightIndex].w;
    return data;
}

// Get light information functions
int GetDirectionalLightCount()
{
    return _DirectionalLightCount;
}

int GetOtherLightCount()
{
    return _OtherLightCount;
}

Light GetDirectionalLight(int index, Surface surface, ShadowData shadowData)
{
    Light light;
    light.strength = _DirectionalLightStrengths[index];
    light.direction = _DirectionalLightDirectionsAndMasks[index].xyz;
    light.renderingLayerMask = asuint(_DirectionalLightDirectionsAndMasks[index].w);

    // Calculate shadow attenuation
    DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);
    light.attenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surface);

    return light;
}

Light GetOtherLight(int index, Surface surface, ShadowData shadowData)
{
    Light light;
    light.strength = _OtherLightStrengths[index];
    light.renderingLayerMask = asuint(_OtherLightDirectionsAndMasks[index].w);

    float3 position = _OtherLightPositions[index].xyz;
    float3 spotDirection = _OtherLightDirectionsAndMasks[index].xyz;

    // Calculate ray direction
    float3 ray = surface.posW - position;
    light.direction = normalize(ray);

    // Calculate light attenuation
    float distanceSqr = max(dot(ray, ray), 0.00001f);
    float rangeAttenuation = pow(
        saturate(1.0f - pow(distanceSqr * _OtherLightPositions[index].w, 2)), 2
    );
    float2 spotAngles = _OtherLightSpotAngles[index];
    float spotAttenuation = pow(
        saturate(dot(spotDirection, -light.direction) * spotAngles.x + spotAngles.y), 2
    );
    float lightAttenuation = spotAttenuation * rangeAttenuation / distanceSqr;

    // Calculate shadow attenuation
    OtherShadowData otherShadowData = GetOtherShadowData(index);
    otherShadowData.lightPosition = position;
    otherShadowData.lightDirection = light.direction;
    otherShadowData.spotDirection = spotDirection;
    float shadowAttenuation = GetOtherShadowAttenuation(otherShadowData, shadowData, surface);

    light.attenuation = lightAttenuation * shadowAttenuation;

    return light;
}

// Calculate lighting functions
bool RenderingLayersOverlap(Surface surface, Light light)
{
    return (surface.renderingLayerMask & light.renderingLayerMask) != 0;
}

float3 GetDirectLighting(Surface surface, BRDF brdf, Light light)
{
    float3 directBrdf = DirectBRDF(surface, brdf, light);
    return saturate(dot(surface.normal, -light.direction) * light.attenuation) * light.strength
                                                                               * directBrdf;
}

float3 GetLighting(Surface surface, BRDF brdf)
{
    // Get shadow data
    ShadowData shadowData = GetShadowData(surface);
    
    float3 lightingResult = 0.0f;

    // Calculate directional lighting
    for (int i = 0; i < GetDirectionalLightCount(); ++i)
    {
        Light light = GetDirectionalLight(i, surface, shadowData);
        if (RenderingLayersOverlap(surface, light))
            lightingResult += GetDirectLighting(surface, brdf, light);
    }

    // Calculate point and spot lighting
    for (int j = 0; j < GetOtherLightCount(); ++j)
    {
        Light light = GetOtherLight(j, surface, shadowData);
        if (RenderingLayersOverlap(surface, light))
            lightingResult += GetDirectLighting(surface, brdf, light);
    }

    return lightingResult;
}

float3 GetGILighting(Surface surface, BRDF brdf, GI gi)
{
    // Get shadow data
    ShadowData shadowData = GetShadowData(surface);
    shadowData.shadowMask = gi.shadowMask;

    // Debug shadow mask
    // return gi.shadowMask.shadows.rgb;                                                                                                                                                                              

    // Calculate indirect lighting
    float3 lightingResult = IndirectBRDF(surface, brdf, gi.diffuse, gi.specular);

    // Calculate directional lighting
    for (int i = 0; i < GetDirectionalLightCount(); ++i)
    {
        Light light = GetDirectionalLight(i, surface, shadowData);
        if (RenderingLayersOverlap(surface, light))
            lightingResult += GetDirectLighting(surface, brdf, light);
    }

    // Calculate point and spot lighting
#ifdef _LIGHTS_PER_OBJECT
    for (int j = 0; j < min(unity_LightData.y, 8); ++j) {
        // Find true light index
        int lightIndex = unity_LightIndices[(uint)j / 4][(uint)j % 4];

        Light light = GetOtherLight(lightIndex, surface, shadowData);
        if (RenderingLayersOverlap(surface, light))
            lightingResult += GetDirectLighting(surface, brdf, light);
    }
#else
    for (int j = 0; j < GetOtherLightCount(); ++j)
    {
        Light light = GetOtherLight(j, surface, shadowData);
        if (RenderingLayersOverlap(surface, light))
            lightingResult += GetDirectLighting(surface, brdf, light);
    }
#endif

    return lightingResult;
}

#endif