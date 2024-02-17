#ifndef CUSTOM_FXAA_PASS_INCLUDED
#define CUSTOM_FXAA_PASS_INCLUDED

#include "PostEffectsPasses.hlsl"

// Edge quality
#if defined(_FXAA_QUALITY_LOW)
    #define EXTRA_EDGE_STEPS 3
    #define EDGE_STEP_SIZES 1.5, 2.0, 2.0
    #define LAST_EDGE_STEP_GUESS 8.0
#elif defined(_FXAA_QUALITY_MEDIUM)
    #define EXTRA_EDGE_STEPS 8
    #define EDGE_STEP_SIZES 1.5, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 4.0
    #define LAST_EDGE_STEP_GUESS 8.0
#else
    #define EXTRA_EDGE_STEPS 10
    #define EDGE_STEP_SIZES 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0
    #define LAST_EDGE_STEP_GUESS 8.0
#endif

static const float edgeStepSizes[EXTRA_EDGE_STEPS] = { EDGE_STEP_SIZES };

float3 _FXAAConfig;

struct LumaNeighborhood
{
    float m, n, e, s, w, ne, se, sw, nw;
    float highest, lowest, range;
};

struct FXAAEdge
{
    bool isHorizontal;
    float pixelStep;
    float lumaGradient, otherLuma;
};

float GetLuminance(float2 uv, float offsetU = 0.0f, float offsetV = 0.0f)
{
    uv += float2(offsetU, offsetV) * GetSourceTexelSize().xy;

#ifdef FXAA_ALPHA_CONTAINS_LUMA
    // Use luminance stored in alpha channel
    return GetSource(uv).a;
#else
    // Commonly use the green color channel to represent luminance
    return sqrt(GetSource(uv).g);
#endif
}

LumaNeighborhood GetLumaNeighborhood(float2 uv)
{
    // Sample the luminance of the pixels in the neighborhood of the source pixel
    LumaNeighborhood luma;
    luma.m = GetLuminance(uv);
    luma.n = GetLuminance(uv, 0.0f, 1.0f);
    luma.e = GetLuminance(uv, 1.0f, 0.0f);
    luma.s = GetLuminance(uv, 0.0f, -1.0f);
    luma.w = GetLuminance(uv, -1.0f, 0.0f);
    luma.ne = GetLuminance(uv, 1.0f, 1.0f);
    luma.se = GetLuminance(uv, 1.0f, -1.0f);
    luma.sw = GetLuminance(uv, -1.0f, -1.0f);
    luma.nw = GetLuminance(uv, -1.0f, 1.0f);

    // Determine the luma range in this neighborhood
    luma.highest = max(max(max(max(luma.m, luma.n), luma.e), luma.s), luma.w);
    luma.lowest = min(min(min(min(luma.m, luma.n), luma.e), luma.s), luma.w);
    luma.range = luma.highest - luma.lowest;

    return luma;
}

bool CanSkipFXAA(LumaNeighborhood luma)
{
    // X component: Fixed threshold
    // Y component: relative threshold, depending on the brightest luminance of each neighborhood
    return luma.range < max(_FXAAConfig.x, _FXAAConfig.y * luma.highest);
}

bool IsHorizontalEdge(LumaNeighborhood luma)
{
    // Compare the horizontal and vertical contrast in the neighborhood
    float horizontal =
        2.0f * abs(luma.n + luma.s - 2.0f * luma.m) +
        abs(luma.ne + luma.se - 2.0f * luma.e) +
        abs(luma.nw + luma.sw - 2.0f * luma.w);
    float vertical =
        2.0f * abs(luma.e + luma.w - 2.0f * luma.m) +
        abs(luma.ne + luma.nw - 2.0f * luma.n) +
        abs(luma.se + luma.sw - 2.0f * luma.s);
    return horizontal >= vertical;
}

FXAAEdge GetFXAAEdge(LumaNeighborhood luma)
{
    FXAAEdge edge;

    // Get the edge orientation
    edge.isHorizontal = IsHorizontalEdge(luma);
    
    // Get pixel step via edge orientation
    float lumaP, lumaN;
    if (edge.isHorizontal)
    {
    	edge.pixelStep = GetSourceTexelSize().y;
        lumaP = luma.n;
        lumaN = luma.s;
    }
    else
    {
    	edge.pixelStep = GetSourceTexelSize().x;
        lumaP = luma.e;
        lumaN = luma.w;
    }

    float gradientP = abs(lumaP - luma.m);
	float gradientN = abs(lumaN - luma.m);
    if (gradientP < gradientN)
    {
        // Blend in the negative direction
		edge.pixelStep = -edge.pixelStep;

        // Keep track of both this gradient and the luma on the other side of the edge
        edge.lumaGradient = gradientN;
        edge.otherLuma = lumaN;
	}
    else
    {
        edge.lumaGradient = gradientP;
        edge.otherLuma = lumaP;
    }
    
    return edge;
}

float GetSubpixelBlendFactor(LumaNeighborhood luma)
{
    float filter = 2.0f * (luma.n + luma.e + luma.s + luma.w);
    // The diagonal neighbors are less important than the direct neighbors
    filter += luma.ne + luma.nw + luma.se + luma.sw;
    filter *= 1.0f / 12.0f;

    // Use high-pass filter
    filter = abs(filter - luma.m);

    // Normalize the filter by dividing it by the luma range
    filter = saturate(filter / luma.range);

    // Modify the filter by applying the squared function to it
    filter = smoothstep(0.0f, 1.0f, filter);
    filter *= filter;

    // Apply subpixel blending factor
    return filter * _FXAAConfig.z;
}

float GetEdgeBlendFactor(LumaNeighborhood luma, FXAAEdge edge, float2 uv)
{
    // Determine the UV coordinates for sampling on the edge
    float2 edgeUV = uv;
    float2 uvStep = 0.0f;
    if (edge.isHorizontal)
    {
        edgeUV.y += 0.5f * edge.pixelStep;
        uvStep.x = GetSourceTexelSize().x;
    }
    else
    {
        edgeUV.x += 0.5f * edge.pixelStep;
        uvStep.y = GetSourceTexelSize().y;
    }

    // Determine the contrast between the sampled luma values
    // and the luma average on the originally detected edge
    float edgeLuma = 0.5f * (luma.m + edge.otherLuma);
    float gradientThreshold = 0.25f * edge.lumaGradient;

    // Start by going steps in the positive direction
    float2 uvP = edgeUV + uvStep;
    float lumaDeltaP  = GetLuminance(uvP) - edgeLuma;
    bool atEndP = abs(lumaDeltaP) >= gradientThreshold;
    int i;
    UNITY_UNROLL
    for (i = 0; i < EXTRA_EDGE_STEPS && !atEndP; ++i)
    {
        uvP += uvStep * edgeStepSizes[i];
        lumaDeltaP = GetLuminance(uvP) - edgeLuma;
        atEndP = abs(lumaDeltaP) >= gradientThreshold;
    }
    if (!atEndP)
    {
        // Guess the real distance if we didn't find it
        uvP += uvStep * LAST_EDGE_STEP_GUESS;
    }

    // Do the same in the negative direction
    float2 uvN = edgeUV - uvStep;
    float lumaDeltaN = GetLuminance(uvN) - edgeLuma;
    bool atEndN = abs(lumaDeltaN) >= gradientThreshold;
    UNITY_UNROLL
    for (i = 0; i < EXTRA_EDGE_STEPS && !atEndN; ++i)
    {
        uvN -= uvStep * edgeStepSizes[i];
        lumaDeltaN = GetLuminance(uvN) - edgeLuma;
        atEndN = abs(lumaDeltaN) >= gradientThreshold;
    }
    if (!atEndP)
    {
        uvN -= uvStep * LAST_EDGE_STEP_GUESS;
    }

    // Find the distance to the positive and negative end in UV space
    float distanceToEndP, distanceToEndN;
    if (edge.isHorizontal)
    {
        distanceToEndP = uvP.x - uv.x;
        distanceToEndN = uv.x - uvN.x;
    }
    else
    {
        distanceToEndP = uvP.y - uv.y;
        distanceToEndN = uv.y - uvN.y;
    }
    
    // Find the distance to the nearest end of the edge
    float distanceToNearestEnd;
    bool deltaSign;
    if (distanceToEndP <= distanceToEndN)
    {
    	distanceToNearestEnd = distanceToEndP;
        deltaSign = lumaDeltaP >= 0;
    }
    else
    {
    	distanceToNearestEnd = distanceToEndN;
        deltaSign = lumaDeltaN >= 0;
    }
    
    if (deltaSign == (luma.m - edgeLuma >= 0))
    {
        // If the final sign matches the sign of the original edge
        // then we're moving away from the edge, we should skip blending
        return 0.0f;
    }
    else
    {
        // Blend by a factor of 0.5 minus the relative distance
        // to the nearest end point along the edge
        return 0.5f - distanceToNearestEnd / (distanceToEndP + distanceToEndN);
    }
}

float4 FXAAPassFrag(Varyings input) : SV_TARGET
{
    LumaNeighborhood luma = GetLumaNeighborhood(input.screenUV);

    if (CanSkipFXAA(luma))
    {
        return GetSource(input.screenUV);
    }

    FXAAEdge edge = GetFXAAEdge(luma);

    // Apply both edge and subpixel blending
    float blendFactor = max(GetSubpixelBlendFactor(luma),
                            GetEdgeBlendFactor(luma, edge, input.screenUV));

    // Sample the image with an offset equal to
    // the pixel step scaled by the blend factor
    float2 blendUV = input.screenUV;
    if (edge.isHorizontal)
    {
        blendUV.y += blendFactor * edge.pixelStep;
    }
    else
    {
        blendUV.x += blendFactor * edge.pixelStep;
    }
    return GetSource(blendUV);
}

#endif