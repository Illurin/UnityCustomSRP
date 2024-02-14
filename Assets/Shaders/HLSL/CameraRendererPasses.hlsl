#ifndef CUSTOM_CAMERA_RENDERER_PASSES_INCLUDED
#define CUSTOM_CAMERA_RENDERER_PASSES_INCLUDED

struct Varyings
{
    float4 posH : SV_Position;
    float2 screenUV : VAR_SCREEN_UV;
};

Varyings DefaultPassVert(uint vertexID : SV_VertexID)
{
    Varyings output;

    // Draw a triangle covering the entire screen space
    output.posH = float4(
        vertexID <= 1 ? -1.0f : 3.0f,
        vertexID == 1 ? 3.0f : -1.0f,
        0.0f, 1.0f
    );
    output.screenUV = float2(
        vertexID <= 1 ? 0.0f : 2.0f,
        vertexID == 1 ? 2.0f : 0.0f
    );
    
    // X component indicates whether a manual flip is needed
    if (_ProjectionParams.x < 0.0f) {
        output.screenUV.y = 1.0f - output.screenUV.y;
    }
    return output;
}

TEXTURE2D(_SourceTexture);

float4 CopyPassFrag(Varyings input) : SV_TARGET
{
    return SAMPLE_TEXTURE2D_LOD(_SourceTexture, sampler_linear_clamp, input.screenUV, 0);
}

float CopyDepthPassFrag(Varyings input) : SV_DEPTH
{
    return SAMPLE_DEPTH_TEXTURE_LOD(_SourceTexture, sampler_point_clamp, input.screenUV, 0);
}

#endif