#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

// For SRP batching
CBUFFER_START(UnityPerDraw)

    // Unity params
    float4x4 unity_ObjectToWorld;
    float4x4 unity_WorldToObject;
    float4   unity_LODFade;
    real4    unity_WorldTransformParams;
    float4   unity_RenderingLayer;

    // Lights per object
    real4    unity_LightData;
    real4    unity_LightIndices[2];

    float4   unity_LightmapST;
    float4   unity_DynamicLightmapST;

    // Spherical Harmonics Lighting
    float4   unity_SHAr;
    float4   unity_SHAg;
    float4   unity_SHAb;
    float4   unity_SHBr;
    float4   unity_SHBg;
    float4   unity_SHBb;
    float4   unity_SHC;

    // Light Probe Proxy Volume
    float4   unity_ProbeVolumeParams;
    float4x4 unity_ProbeVolumeWorldToObject;
    float4   unity_ProbeVolumeSizeInv;
    float4   unity_ProbeVolumeMin;

    // Occlusion Probes
    float4   unity_ProbesOcclusion;

    // Reflection Probes
    float4   unity_SpecCube0_HDR;

CBUFFER_END

// Projection params
float3 _WorldSpaceCameraPos;
float4 unity_OrthoParams;
float4 _ProjectionParams;
float4 _ScreenParams;
float4 _ZBufferParams;

// Define matrices
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;                          // In Unity 2022
float4x4 unity_MatrixVP;
float4x4 unity_prev_MatrixM;                        // In Unity 2022
float4x4 unity_prev_MatrixIM;                       // In Unity 2022
float4x4 glstate_matrix_projection;

#define UNITY_MATRIX_M        unity_ObjectToWorld
#define UNITY_MATRIX_I_M      unity_WorldToObject
#define UNITY_MATRIX_V        unity_MatrixV
#define UNITY_MATRIX_I_V      unity_MatrixInvV      // In Unity 2022
#define UNITY_MATRIX_VP       unity_MatrixVP
#define UNITY_PREV_MATRIX_M   unity_prev_MatrixM    // In Unity 2022
#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM   // In Unity 2022
#define UNITY_PREV_MATRIX_M   unity_prev_MatrixM
#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM
#define UNITY_MATRIX_P        glstate_matrix_projection

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

SAMPLER(sampler_linear_clamp);
SAMPLER(sampler_point_clamp);

bool IsOrthographicCamera()
{
    return unity_OrthoParams.w;
}

float OrthographicDepthBufferToLinear(float rawDepth)
{
#if UNITY_REVERSED_Z
    rawDepth = 1.0f - rawDepth;
#endif
    // Scale the depth by the camera's near¨Cfar range and then add the near plane distance
    return (_ProjectionParams.z - _ProjectionParams.y) * rawDepth + _ProjectionParams.y;
}

#include "Fragment.hlsl"

// Unity use RGB or DXT5(BC3) for normal map
float3 DecodeNormal(float4 sample, float scale)
{
#ifdef UNITY_NO_DXT5nm
    return normalize(UnpackNormalRGB(sample, scale));
#else
    return normalize(UnpackNormalmapRGorAG(sample, scale));
#endif
}

float3 NormalTangentToWorld(float3 normalT, float3 normalW, float4 tangentW)
{
    float3x3 tangentToWorld =
        CreateTangentToWorld(normalW, tangentW.xyz, tangentW.w);
    return TransformTangentToWorld(normalT, tangentToWorld);
}

#endif