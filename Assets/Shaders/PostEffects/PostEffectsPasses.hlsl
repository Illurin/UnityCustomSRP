#ifndef CUSTOM_POST_EFFECTS_PASSES_INCLUDED
#define CUSTOM_POST_EFFECTS_PASSES_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

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

float4 _PostEffectsSource_TexelSize;

float4 GetSourceTexelSize()
{
    return _PostEffectsSource_TexelSize;
}

TEXTURE2D(_PostEffectsSource);
TEXTURE2D(_PostEffectsSource2);

float4 GetSource(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_PostEffectsSource, sampler_linear_clamp, screenUV, 0);
}

float4 GetSource2(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_PostEffectsSource2, sampler_linear_clamp, screenUV, 0);
}

float4 GetSourceBicubic(float2 screenUV)
{
    // Defined in CoreRP/Filtering.hlsl
    return SampleTexture2DBicubic(
        TEXTURE2D_ARGS(_PostEffectsSource, sampler_linear_clamp), screenUV,
        GetSourceTexelSize().zwxy, 1.0f, 0.0f
    );
}

float4 CopyPassFrag(Varyings input) : SV_TARGET
{
    return GetSource(input.screenUV);
}

/* -------------------- Bloom Passes -------------------- */

float4 BloomHorizontalPassFrag(Varyings input) : SV_TARGET
{
    // Gaussian filtering core
    float offsets[] = {
        -4.0f, -3.0f, -2.0f, -1.0f, 0.0f, 1.0f, 2.0f, 3.0f, 4.0f
    };
    float weights[] = {
        0.01621622f, 0.05405405f, 0.12162162f, 0.19459459f, 0.22702703f,
        0.19459459f, 0.12162162f, 0.05405405f, 0.01621622f
    };

    float3 color = 0.0f;
    for (int i = 0; i < 9; ++i)
    {
        float offset = offsets[i] * GetSourceTexelSize().x * 2.0f;
        color += GetSource(input.screenUV + float2(offset, 0.0f)).rgb * weights[i];
    }
    return float4(color, 1.0f);
}

float4 BloomVerticalPassFrag(Varyings input) : SV_TARGET
{
    // Sample in between the Gaussian sampling points at appropriate offsets
    float offsets[] = {
        -3.23076923f, -1.38461538f, 0.0f, 1.38461538f, 3.23076923f
    };
    float weights[] = {
        0.07027027f, 0.31621622f, 0.22702703f, 0.31621622f, 0.07027027f
    };

    float3 color = 0.0f;
    for (int i = 0; i < 5; ++i)
    {
        float offset = offsets[i] * GetSourceTexelSize().y;
        color += GetSource(input.screenUV + float2(0.0f, offset)).rgb * weights[i];
    }
    return float4(color, 1.0f);
}

float4 _BloomThreshold;

float3 ApplyBloomThreshold(float3 color)
{
    float brightness = Max3(color.r, color.g, color.b);
    float soft = brightness + _BloomThreshold.y;
    soft = clamp(soft, 0.0f, _BloomThreshold.z);
    soft = soft * soft * _BloomThreshold.w;
    float contribution = max(soft, brightness - _BloomThreshold.x);
    contribution /= max(brightness, 0.00001f);
    return color * contribution;
}

float4 BloomPrefilterPassFrag(Varyings input) : SV_TARGET
{
    float3 color = ApplyBloomThreshold(GetSource(input.screenUV).rgb);
    return float4(color, 1.0f);
}

float4 BloomPrefilterFirefliesPassFrag(Varyings input) : SV_TARGET
{
    float3 color = 0.0f;
    float weightSum = 0.0f;

    // Use a large 6¡Á6 cross filter (with 5 samples)
    float2 offsets[] = {
        float2( 0.0f,  0.0f),
        float2(-1.0f, -1.0f), float2(-1.0f, 1.0f), float2(1.0f, -1.0f), float2(1.0f, 1.0f)//,
     // float2(-1.0f,  0.0f), float2( 1.0f, 0.0f), float2(0.0f, -1.0f), float2(0.0f, 1.0f)
    };

    // Spreads out the brightness of the fireflies across all other samples
    for (int i = 0; i < 5; i++)
    {
        float2 offset = offsets[i] * GetSourceTexelSize().xy * 2.0f;
        float3 source = GetSource(input.screenUV + offset).rgb;
        source = ApplyBloomThreshold(source);

        float weight = 1.0f / (Luminance(source) + 1.0f);   // Defined in CoreRP/Color.hlsl
        weightSum += weight;

        color += weight * source;
    }
    color /= weightSum;
    return float4(color, 1.0f);
}

bool _BloomBicubicUpsampling;
float _BloomIntensity;

float4 BloomAddPassFrag(Varyings input) : SV_TARGET
{
    float3 lowRes;
    if (_BloomBicubicUpsampling)
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    else
        lowRes = GetSource(input.screenUV).rgb;

    float4 highRes = GetSource2(input.screenUV);
    return float4(lowRes * _BloomIntensity + highRes.rgb, highRes.a);
}

float4 BloomScatterPassFrag(Varyings input) : SV_TARGET
{
    float3 lowRes;
    if (_BloomBicubicUpsampling)
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    else
        lowRes = GetSource(input.screenUV).rgb;

    float4 highRes = GetSource2(input.screenUV);
    return float4(lerp(highRes.rgb, lowRes, _BloomIntensity), highRes.a);
}

float4 BloomScatterFinalPassFrag(Varyings input) : SV_TARGET
{
    float3 lowRes;
    if (_BloomBicubicUpsampling)
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    else
        lowRes = GetSource(input.screenUV).rgb;

    float4 highRes = GetSource2(input.screenUV);

    // Add the missing light to the low-resolution pass
    lowRes += highRes.rgb - ApplyBloomThreshold(highRes.rgb);
    return float4(lerp(highRes.rgb, lowRes, _BloomIntensity), highRes.a);
}

/* -------------------- Color Grading Functions -------------------- */

// A variant for using ACES
float Luminance(float3 color, bool useACES)
{
    return useACES ? AcesLuminance(color) : Luminance(color);   // Defined in CoreRP/Color.hlsl
}

float4 _ColorAdjustments;
float3 _ColorFilter;

float3 ColorGradingPostExposure(float3 color)
{
    return color * _ColorAdjustments.x;
}

float3 ColorGradingContrast(float3 color, bool useACES)
{
    if (useACES)
    {
        color = ACES_to_ACEScc(unity_to_ACES(color));   // Defined in CoreRP/Color.hlsl
        color = (color - ACEScc_MIDGRAY) * _ColorAdjustments.y + ACEScc_MIDGRAY;
        return ACES_to_ACEScg(ACEScc_to_ACES(color));
    }

    // For best results this coversion is done in Log C
    // instead of linear color space
    color = LinearToLogC(color);    // Defined in CoreRP/Color.hlsl
    color = (color - ACEScc_MIDGRAY) * _ColorAdjustments.y + ACEScc_MIDGRAY;
    return LogCToLinear(color);
}

float3 ColorGradingColorFilter(float3 color)
{
    return color * _ColorFilter;
}

float3 ColorGradingHueShift(float3 color)
{
    color = RgbToHsv(color);    // Defined in CoreRP/Color.hlsl
    float hue = color.x + _ColorAdjustments.z;
    color.x = RotateHue(hue, 0.0f, 1.0f);
    return HsvToRgb(color);
}

float3 ColorGradingSaturation(float3 color, bool useACES)
{
    float luminance = Luminance(color, useACES);
    return (color - luminance) * _ColorAdjustments.w + luminance;
}

float3 _WhiteBalance;

float3 ColorGradingWhiteBalance(float3 color)
{
    color = LinearToLMS(color); // Defined in CoreRP/Color.hlsl
    color *= _WhiteBalance;
    return LMSToLinear(color);
}

float4 _SplitToningShadows;
float3 _SplitToningHighlights;

float3 ColorGradingSplitToning(float3 color, bool useACES)
{
    // Perform split-toning in approximate gamma space
    color = PositivePow(color, 1.0f / 2.2f);

    // Limit the tints to their respective regions
    float tints = saturate(Luminance(saturate(color), useACES) + _SplitToningShadows.w);
    float3 shadows = lerp(0.5f, _SplitToningShadows.rgb, 1.0f - tints);
    float3 highlights = lerp(0.5f, _SplitToningHighlights.rgb, tints);

    color = SoftLight(color, shadows);      // Defined in CoreRP/Color.hlsl
    color = SoftLight(color, highlights);
    return PositivePow(color, 2.2f);
}

float3 _ChannelMixerRed, _ChannelMixerGreen, _ChannelMixerBlue;

float3 ColorGradingChannelMixer(float3 color)
{
    return mul(float3x3(_ChannelMixerRed, _ChannelMixerGreen, _ChannelMixerBlue),
               color);
}

float3 _SmhShadows, _SmhMidtones, _SmhHighlights;
float4 _SmhRange;

float3 ColorGradingShadowsMidtonesHighlights(float3 color, bool useACES)
{
    float luminance = Luminance(color, useACES);
    float shadowsWeight = 1.0f - smoothstep(_SmhRange.x, _SmhRange.y, luminance);
    float highlightsWeight = smoothstep(_SmhRange.z, _SmhRange.w, luminance);
    float midtonesWeight = 1.0f - shadowsWeight - highlightsWeight;
    return
        color * _SmhShadows * shadowsWeight +
        color * _SmhMidtones * midtonesWeight +
        color * _SmhHighlights * highlightsWeight;
}

float3 ColorGrade(float3 color, bool useACES = false)
{
    color = min(color, 60.0f);  // Avoid precision limitations
    color = ColorGradingPostExposure(color);
    color = ColorGradingWhiteBalance(color);
    color = ColorGradingContrast(color, useACES);
    color = ColorGradingColorFilter(color);
    color = max(color, 0.0f);   // Avoid negative color components
    color = ColorGradingSplitToning(color, useACES);
    color = ColorGradingChannelMixer(color);
    color = max(color, 0.0f);
    color = ColorGradingShadowsMidtonesHighlights(color, useACES);
    color = ColorGradingHueShift(color);
    color = ColorGradingSaturation(color, useACES);
    return max(useACES ? ACEScg_to_ACES(color) : color, 0.0f);
}

/* -------------------- Color Grading Passes -------------------- */

float4 _ColorGradingLUTParameters;
bool _ColorGradingLUTInLogC;

float3 GetColorGradedLUT(float2 uv, bool useACES = false)
{
    float3 color = GetLutStripValue(uv, _ColorGradingLUTParameters);    // Defined in CoreRP/Color.hlsl
    // Use Log C space to extend the color range,
    // but it will waste almost half of the resolution
    return ColorGrade(_ColorGradingLUTInLogC ? LogCToLinear(color) : color, useACES);
}

float4 ColorGradingNonePassFrag(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    return float4(color, 1.0f);
}

float4 ColorGradingACESPassFrag(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    color = AcesTonemap(color);     // Defined in CoreRP/Color.hlsl
    return float4(color, 1.0f);
}

float4 ColorGradingNeutralPassFrag(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    color = NeutralTonemap(color);  // Defined in CoreRP/Color.hlsl
    return float4(color, 1.0f);
}

float4 ColorGradingReinhardPassFrag(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    color /= color + 1.0f;
    return float4(color, 1.0f);
}

TEXTURE2D(_ColorGradingLUT);

float3 ApplyColorGradingLUT(float3 color)
{
    // Defined in CoreRP/Color.hlsl, interpret the 2D LUT strip as a 3D texture
    return ApplyLut2D(
        TEXTURE2D_ARGS(_ColorGradingLUT, sampler_linear_clamp),
        saturate(_ColorGradingLUTInLogC ? LinearToLogC(color) : color),
        _ColorGradingLUTParameters.xyz
    );
}

float4 ColorGradingFinalPassFrag(Varyings input) : SV_TARGET
{
    float4 color = GetSource(input.screenUV);
    color.rgb = ApplyColorGradingLUT(color.rgb);
    return color;
}

float4 ColorGradingFinalWithLumaPassFrag(Varyings input) : SV_TARGET
{
    float4 color = GetSource(input.screenUV);
    color.rgb = ApplyColorGradingLUT(color.rgb);
    color.a = sqrt(Luminance(color.rgb));   // Store luminance in alpha channel
    return color;
}

bool _CopyBicubic;

float4 FinalRescalePassFrag(Varyings input) : SV_TARGET
{
    if (_CopyBicubic)
    {
        return GetSourceBicubic(input.screenUV);
    }
    else
    {
        return GetSource(input.screenUV);
    }
}

#endif