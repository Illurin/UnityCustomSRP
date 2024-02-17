#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

struct Light
{
    float3 strength;
    float3 direction;
    float  attenuation;
    uint   renderingLayerMask;
};

#endif