#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface
{
    // Color properties
    float3 color;
    float alpha;

    // Transform properties
    float3 posW;
    float depth;
    float3 toEye;
    float3 normal;
    float3 interpolatedNormal;

    // Material properties
    float metallic;
    float occlusion;
    float smoothness;
    float fresnelStrength;
    float dither;

    // Masks
    uint renderingLayerMask;
};

#endif