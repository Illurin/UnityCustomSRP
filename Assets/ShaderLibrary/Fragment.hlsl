#ifndef CUSTOM_FRAGMENT_INCLUDED
#define CUSTOM_FRAGMENT_INCLUDED

TEXTURE2D(_CameraColorTexture);
TEXTURE2D(_CameraDepthTexture);

float4 _FramebufferSize;

struct Fragment
{
    float2 posS;
    float2 screenUV;
    float  depth;
    float  bufferDepth;
};

Fragment GetFragment(float4 posH)
{
    Fragment frag;
    frag.posS = posH.xy;
    frag.screenUV = frag.posS * _FramebufferSize.xy;
    frag.depth = IsOrthographicCamera() ?
                 OrthographicDepthBufferToLinear(posH.z) :
                 posH.w;
    frag.bufferDepth =
        SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampler_point_clamp, frag.screenUV, 0);
    // Reconstruct view-space depth
    frag.bufferDepth = IsOrthographicCamera() ?
                       OrthographicDepthBufferToLinear(frag.bufferDepth) :
                       LinearEyeDepth(frag.bufferDepth, _ZBufferParams);
    return frag;
}

float4 GetFramebufferColor(Fragment frag, float2 uvOffset = float2(0.0f, 0.0f))
{
    float2 uv = frag.screenUV + uvOffset;
    return SAMPLE_TEXTURE2D_LOD(_CameraColorTexture, sampler_linear_clamp, uv, 0);
}

#endif