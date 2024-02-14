#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#include "Surface.hlsl"
#include "Light.hlsl"

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

struct BRDF
{
    float3 diffuse;
    float3 specular;
    float roughness;
    float perceptualRoughness;
    float fresnel;
};

BRDF GetBRDF(Surface surface, bool applyAlphaToDiffuse = false)
{
    BRDF brdf;
    
    // Calculate diffuse
    float oneMinusReflectivity = (1.0f - MIN_REFLECTIVITY) * (1.0f - surface.metallic);
    brdf.diffuse = surface.color * oneMinusReflectivity;
    if (applyAlphaToDiffuse)
        brdf.diffuse *= surface.alpha;

    // Calculate specular
    brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);
    
    // Calculate roughness
    brdf.perceptualRoughness =
        PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);  // Defined in ImageBasedLighting.hlsl
    brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);

    // Calculate fresnel
    brdf.fresnel = saturate(surface.smoothness + 1.0f - oneMinusReflectivity);

    return brdf;
}

// Minimalist CookTorrance BRDF
float SpecularStrength(Surface surface, BRDF brdf, Light light)
{
    float3 h = normalize(-light.direction + surface.toEye);
    float nh2 = pow(saturate(dot(surface.normal, h)), 2);
    float lh2 = pow(saturate(dot(-light.direction, h)), 2);
    float r2 = pow(brdf.roughness, 2);
    float d2 = pow(nh2 * (r2 - 1.0f) + 1.00001f, 2);
    float normalization = brdf.roughness * 4.0f + 2.0f;
    return r2 / (d2 * max(0.1f, lh2) * normalization);
}

float3 DirectBRDF(Surface surface, BRDF brdf, Light light)
{
    return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

float3 IndirectBRDF(Surface surface, BRDF brdf, float3 diffuse, float3 specular)
{
    // A variant Schlick's approximation for Fresnel
    float fresnelStrength = surface.fresnelStrength *
                            Pow4(1.0f - saturate(dot(surface.normal, surface.toEye)));

    float3 reflection = specular * lerp(brdf.specular, brdf.fresnel, fresnelStrength);
    reflection /= brdf.roughness * brdf.roughness + 1.0f;
    return (diffuse * brdf.diffuse + reflection) * surface.occlusion;
}

#endif