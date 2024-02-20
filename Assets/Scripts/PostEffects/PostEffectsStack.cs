using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Networking.Types;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using static PostEffectsSettings;

public partial class PostEffectsStack
{
    enum Pass
    {
        BloomAdd,
        BloomHorizontal,
        BloomPrefilter,
        BloomPrefilterFireflies,
        BloomScatter,
        BloomScatterFinal,
        BloomVertical,
        Copy,
        ColorGradingNone,
        ColorGradingACES,
        ColorGradingNeutral,
        ColorGradingReinhard,
        ColorGradingFinal,
        ColorGradingFinalWithLuma,
        FinalRescale,
        FXAA,
        FXAAWithLuma
    }

    //const string cmdName = "Post Effects";
    //CommandBuffer cmd = new CommandBuffer { name = cmdName };
    CommandBuffer cmd;

    ScriptableRenderContext context;
    Camera camera;

    PostEffectsSettings settings;

    int colorLUTResolution;

    // Shader property tags
    int postEffectsSourceId = Shader.PropertyToID("_PostEffectsSource"),
        postEffectsSource2Id = Shader.PropertyToID("_PostEffectsSource2"),

        // Bloom
        bloomPrefilterId = Shader.PropertyToID("_BloomPrefilter"),
        bloomResultId = Shader.PropertyToID("_BloomResult"),
        bloomBicubicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling"),
        bloomIntensityId = Shader.PropertyToID("_BloomIntensity"),
        bloomThresholdId = Shader.PropertyToID("_BloomThreshold"),

        // Color adjustments
        colorAdjustmentsId = Shader.PropertyToID("_ColorAdjustments"),
        colorFilterId = Shader.PropertyToID("_ColorFilter"),

        // White balance
        whiteBalanceId = Shader.PropertyToID("_WhiteBalance"),

        // Split toning
        splitToningShadowsId = Shader.PropertyToID("_SplitToningShadows"),
        splitToningHighlightsId = Shader.PropertyToID("_SplitToningHighlights"),

        // Channel mixer
        channelMixerRedId = Shader.PropertyToID("_ChannelMixerRed"),
        channelMixerGreenId = Shader.PropertyToID("_ChannelMixerGreen"),
        channelMixerBlueId = Shader.PropertyToID("_ChannelMixerBlue"),

        // Shadows midtones highlights
        smhShadowsId = Shader.PropertyToID("_SmhShadows"),
        smhMidtonesId = Shader.PropertyToID("_SmhMidtones"),
        smhHighlightsId = Shader.PropertyToID("_SmhHighlights"),
        smhRangeId = Shader.PropertyToID("_SmhRange"),

        // LUT
        colorGradingLUTId = Shader.PropertyToID("_ColorGradingLUT"),
        colorGradingLUTParametersId = Shader.PropertyToID("_ColorGradingLUTParameters"),
        colorGradingLUTInLogId = Shader.PropertyToID("_ColorGradingLUTInLogC"),

        // FXAA
        colorGradingResultId = Shader.PropertyToID("_ColorGradingResult"),
        fxaaConfigId = Shader.PropertyToID("_FXAAConfig"),

        // Final blend mode
        finalSrcBlendId = Shader.PropertyToID("_FinalSrcBlend"),
        finalDstBlendId = Shader.PropertyToID("_FinalDstBlend"),

        // Final rescale
        copyBicubicId = Shader.PropertyToID("_CopyBicubic"),
        finalResultId = Shader.PropertyToID("_FinalResult");

    // Shader keywords
    const string
        fxaaQualityLowKeyword = "_FXAA_QUALITY_LOW",
        fxaaQualityMediumKeyword = "_FXAA_QUALITY_MEDIUM";

    public bool IsActive => settings != null;

    CameraSettings.FinalBlendMode finalBlendMode;
    bool keepAlpha, useHDR;

    // Bloom properties
    const int maxBloomLevel = 16;
    int bloomTextureId;

    // Framebuffer properties
    Vector2Int framebufferSize;
    FramebufferSettings.BicubicRescalingMode bicubicRescaling;

    static Rect fullViewRect = new Rect(0.0f, 0.0f, 1.0f, 1.0f);

    // FXAA properties
    FramebufferSettings.FXAA fxaa;

    public PostEffectsStack()
    {
        // Assigns identifiers sequentially in the order
        bloomTextureId = Shader.PropertyToID("_BloomTexture0");
        for (int i = 1; i < maxBloomLevel * 2; ++i)
        {
            Shader.PropertyToID("_BloomTexture" + i);
        }
    }

    public void Setup(/*ScriptableRenderContext context, */Camera camera, Vector2Int framebufferSize,
                      PostEffectsSettings settings, bool keepAlpha, bool useHDR, int colorLUTResolution,
                      CameraSettings.FinalBlendMode finalBlendMode,
                      FramebufferSettings.BicubicRescalingMode bicubicRescaling,
                      FramebufferSettings.FXAA fxaa)
    {
        //this.context = context;
        this.camera = camera;
        this.framebufferSize = framebufferSize;
        this.settings = camera.cameraType <= CameraType.SceneView ? settings : null;
        this.keepAlpha = keepAlpha;
        this.useHDR = useHDR;
        this.colorLUTResolution = colorLUTResolution;
        this.finalBlendMode = finalBlendMode;
        this.bicubicRescaling = bicubicRescaling;
        this.fxaa = fxaa;
        ApplySceneViewState();
    }

    public void Render(RenderGraphContext context, int sourceId)
    {
        cmd = context.cmd;

        if (PerformBloom(sourceId))
        {
            PerformColorGradingAndToneMapping(bloomResultId);
            cmd.ReleaseTemporaryRT(bloomResultId);
        }
        else
        {
            PerformColorGradingAndToneMapping(sourceId);
        }
        context.renderContext.ExecuteCommandBuffer(cmd);
        cmd.Clear();
    }

    void Draw(RenderTargetIdentifier src, RenderTargetIdentifier dst, Pass pass)
    {
        // Draw from src to dst
        cmd.SetGlobalTexture(postEffectsSourceId, src);
        cmd.SetRenderTarget(dst, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cmd.DrawProcedural(Matrix4x4.identity, settings.Material, (int)pass,
                           MeshTopology.Triangles, 3);
    }

    // Post effects functions
    bool PerformBloom(int sourceId)
    {
        var bloomSettings = settings.Bloom;

        int width, height;
        if (bloomSettings.ignoreRenderScale)
        {
            width = camera.pixelWidth / 2;
            height = camera.pixelHeight / 2;
        }
        else
        {
            width = framebufferSize.x / 2;
            height = framebufferSize.y / 2;
        }

        // Skip bloom entirely
        if (bloomSettings.maxIterations == 0 || bloomSettings.intensity <= 0.0f ||
            height < bloomSettings.downscaleLimit * 2 || width < bloomSettings.downscaleLimit * 2)
        {
            Draw(sourceId, BuiltinRenderTextureType.CameraTarget, Pass.Copy);
            cmd.EndSample("Bloom");
            return false;
        }

        cmd.BeginSample("Bloom");

        // Calculate bloom threshold
        Vector4 threshold;
        threshold.x = Mathf.GammaToLinearSpace(bloomSettings.threshold);
        threshold.y = threshold.x * bloomSettings.thresholdKnee;
        threshold.z = 2.0f * threshold.y;
        threshold.w = 0.25f / (threshold.y + 0.00001f);
        threshold.y -= threshold.x;
        cmd.SetGlobalVector(bloomThresholdId, threshold);

        var format = useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
        // Copy the source to a pre-filter texture and use that for the start of blurring
        cmd.GetTemporaryRT(bloomPrefilterId, width, height, 0, FilterMode.Bilinear, format);
        Draw(sourceId, bloomPrefilterId,
             bloomSettings.fadeFireflies ? Pass.BloomPrefilterFireflies : Pass.BloomPrefilter);

        width /= 2; height /= 2;
        int srcId = bloomPrefilterId, dstId = bloomTextureId;

        // Perform blur
        int i;
        for (i = 0; i < bloomSettings.maxIterations; ++i)
        {
            if (height < bloomSettings.downscaleLimit || width < bloomSettings.downscaleLimit)
                break;

            // Bloom horizontal
            cmd.GetTemporaryRT(dstId, width, height, 0, FilterMode.Bilinear, format);
            Draw(srcId, dstId, Pass.BloomHorizontal);

            srcId = dstId;
            ++dstId;

            // Bloom vertical
            cmd.GetTemporaryRT(dstId, width, height, 0, FilterMode.Bilinear, format);
            Draw(srcId, dstId, Pass.BloomVertical);

            srcId = dstId;
            ++dstId;

            // Blur texture to another texture that has half the width and height
            width /= 2;
            height /= 2;
        }

        cmd.ReleaseTemporaryRT(bloomPrefilterId);

        // 2 different modes for combine pass
        Pass combinePass, finalPass;
        float intensity;
        if (bloomSettings.mode == BloomSettings.Mode.Additive)
        {
            combinePass = finalPass = Pass.BloomAdd;
            cmd.SetGlobalFloat(bloomIntensityId, 1.0f);
            intensity = bloomSettings.intensity;
        }
        else
        {
            combinePass = Pass.BloomScatter;
            finalPass = Pass.BloomScatterFinal;
            cmd.SetGlobalFloat(bloomIntensityId, bloomSettings.scatter);
            intensity = Mathf.Min(bloomSettings.intensity, 0.95f);
        }
        cmd.SetGlobalFloat(bloomBicubicUpsamplingId, bloomSettings.bicubicUpsampling ? 1.0f : 0.0f);

        if (i > 1)
        {
            // Perform bluring combine
            cmd.ReleaseTemporaryRT(srcId - 1);
            dstId -= 4;
            for (i -= 1; i > 0; --i)
            {
                cmd.SetGlobalTexture(postEffectsSource2Id, dstId + 1);
                Draw(srcId, dstId, combinePass);

                // Release useless textures
                cmd.ReleaseTemporaryRT(srcId);
                cmd.ReleaseTemporaryRT(dstId + 1);

                srcId = dstId;
                dstId -= 2;
            }
        }
        else
        {
            cmd.ReleaseTemporaryRT(bloomTextureId);
        }

        // Combine bloom with source texture to bloom result
        cmd.SetGlobalFloat(bloomIntensityId, intensity);
        cmd.SetGlobalTexture(postEffectsSource2Id, sourceId);
        cmd.GetTemporaryRT(bloomResultId, framebufferSize.x, framebufferSize.y, 0,
                           FilterMode.Bilinear, format);
        Draw(srcId, bloomResultId, finalPass);
        cmd.ReleaseTemporaryRT(srcId);

        cmd.EndSample("Bloom");

        return true;
    }

    void ConfigureColorAdjustments()
    {
        var colorAdjustments = settings.ColorAdjustments;
        cmd.SetGlobalVector(colorAdjustmentsId, new Vector4(
            Mathf.Pow(2.0f, colorAdjustments.postExposure), // Raise 2 to the power of the exposure value
            colorAdjustments.contrast * 0.01f + 1.0f,       // Convert contrast and saturation to the 0бл2 range
            colorAdjustments.hueShift * (1.0f / 360.0f),    // Convert hue shift to -1бл1
            colorAdjustments.saturation * 0.01f + 1.0f
        ));
        cmd.SetGlobalColor(colorFilterId, colorAdjustments.colorFilter.linear);
    }

    void ConfigureWhiteBalance()
    {
        var whiteBalance = settings.WhiteBalance;
        // LMS color space describes colors as the responses of
        // the three photoreceptor cone types in the human eye
        cmd.SetGlobalVector(whiteBalanceId, ColorUtils.ColorBalanceToLMSCoeffs(
            whiteBalance.temperature, whiteBalance.tint
        ));
    }

    void ConfigureSplitToning()
    {
        var splitToning = settings.SplitToning;
        var splitColor = splitToning.shadows;
        splitColor.a = splitToning.balance * 0.01f; // Scaled to the -1бл1 range
        cmd.SetGlobalColor(splitToningShadowsId, splitColor);
        cmd.SetGlobalColor(splitToningHighlightsId, splitToning.highlights);
    }

    void ConfigureChannelMixer()
    {
        ChannelMixerSettings channelMixer = settings.ChannelMixer;
        cmd.SetGlobalVector(channelMixerRedId, channelMixer.red);
        cmd.SetGlobalVector(channelMixerGreenId, channelMixer.green);
        cmd.SetGlobalVector(channelMixerBlueId, channelMixer.blue);
    }

    void ConfigureShadowsMidtonesHighlights()
    {
        var smh = settings.ShadowsMidtonesHighlights;
        cmd.SetGlobalColor(smhShadowsId, smh.shadows.linear);
        cmd.SetGlobalColor(smhMidtonesId, smh.midtones.linear);
        cmd.SetGlobalColor(smhHighlightsId, smh.highlights.linear);
        cmd.SetGlobalVector(smhRangeId, new Vector4(
            smh.shadowsStart, smh.shadowsEnd, smh.highlightsStart, smh.highLightsEnd
        ));
    }

    void ConfigureFXAA()
    {
        if (fxaa.quality == FramebufferSettings.FXAA.Quality.Low)
        {
            cmd.EnableShaderKeyword(fxaaQualityLowKeyword);
            cmd.DisableShaderKeyword(fxaaQualityMediumKeyword);
        }
        else if (fxaa.quality == FramebufferSettings.FXAA.Quality.Medium)
        {
            cmd.DisableShaderKeyword(fxaaQualityLowKeyword);
            cmd.EnableShaderKeyword(fxaaQualityMediumKeyword);
        }
        else
        {
            cmd.DisableShaderKeyword(fxaaQualityLowKeyword);
            cmd.DisableShaderKeyword(fxaaQualityMediumKeyword);
        }
        cmd.SetGlobalVector(fxaaConfigId, new Vector3(
            fxaa.fixedThreshold, fxaa.relativeThreshold, fxaa.subpixelBlending
        ));
    }

    void DrawFinal(RenderTargetIdentifier src, Pass pass)
    {
        cmd.SetGlobalFloat(finalSrcBlendId, (float)finalBlendMode.source);
        cmd.SetGlobalFloat(finalDstBlendId, (float)finalBlendMode.destination);

        var loadRenderBuffer = finalBlendMode.destination != BlendMode.Zero ||
                               camera.rect != fullViewRect;

        cmd.SetGlobalTexture(postEffectsSourceId, src);
        cmd.SetRenderTarget(
            BuiltinRenderTextureType.CameraTarget,
            loadRenderBuffer ? RenderBufferLoadAction.Load : RenderBufferLoadAction.DontCare,
            RenderBufferStoreAction.Store
        );
        cmd.SetViewport(camera.pixelRect);
        cmd.DrawProcedural(
            Matrix4x4.identity, settings.Material,
            (int)pass, MeshTopology.Triangles, 3
        );
    }

    void PerformColorGradingAndToneMapping(int sourceId)
    {
        ConfigureColorAdjustments();
        ConfigureWhiteBalance();
        ConfigureSplitToning();
        ConfigureChannelMixer();
        ConfigureShadowsMidtonesHighlights();

        var lutHeight = colorLUTResolution;
        var lutWidth = lutHeight * lutHeight;   // Use a wide 2D texture to simulate a 3D texture
        cmd.GetTemporaryRT(colorGradingLUTId, lutWidth, lutHeight, 0,
                           FilterMode.Bilinear, RenderTextureFormat.DefaultHDR);


        var mode = settings.ToneMapping.mode;
        var pass = Pass.ColorGradingNone + (int)mode;

        // Generate color grading LUT
        cmd.SetGlobalVector(colorGradingLUTParametersId, new Vector4(
            lutHeight, 0.5f / lutWidth, 0.5f / lutHeight, lutHeight / (lutHeight - 1.0f)
        ));
        cmd.SetGlobalFloat(
            colorGradingLUTInLogId, useHDR && pass != Pass.ColorGradingNone ? 1.0f : 0.0f
        );
        Draw(sourceId, colorGradingLUTId, pass);

        // Apply color grading LUT to source render target
        cmd.SetGlobalVector(colorGradingLUTParametersId, new Vector3(
            1.0f / lutWidth, 1.0f / lutHeight, lutHeight - 1.0f
        ));

        // Reset the final blend mode
        cmd.SetGlobalFloat(finalSrcBlendId, 1.0f);
        cmd.SetGlobalFloat(finalDstBlendId, 0.0f);
        if (fxaa.enabled)
        {
            // If FXAA is enabled, immediately perform color grading and
            // store the result in a new temporary LDR texture
            ConfigureFXAA();
            cmd.GetTemporaryRT(
                colorGradingResultId, framebufferSize.x, framebufferSize.y, 0,
                FilterMode.Bilinear, RenderTextureFormat.Default
            );
            Draw(sourceId, colorGradingResultId,
                 keepAlpha ? Pass.ColorGradingFinal : Pass.ColorGradingFinalWithLuma);
        }

        if (framebufferSize.x == camera.pixelWidth)
        {
            if (fxaa.enabled)
            {
                // Perform FXAA to camera target
                DrawFinal(colorGradingResultId, keepAlpha ? Pass.FXAA : Pass.FXAAWithLuma);
                cmd.ReleaseTemporaryRT(colorGradingResultId);
            }
            else
            {
                // Directly draw to camera target
                DrawFinal(sourceId, Pass.ColorGradingFinal);
            }
        }
        else
        {
            // Perform rescaling in LDR
            cmd.GetTemporaryRT(
                finalResultId, framebufferSize.x, framebufferSize.y, 0,
                FilterMode.Bilinear, RenderTextureFormat.Default
            );

            if (fxaa.enabled)
            {
                // Perform FXAA to final result
                Draw(colorGradingResultId, finalResultId,
                     keepAlpha ? Pass.FXAA : Pass.FXAAWithLuma);
                cmd.ReleaseTemporaryRT(colorGradingResultId);
            }
            else
            {
                // Directly draw to final result
                Draw(sourceId, finalResultId, Pass.ColorGradingFinal);
            }

            bool bicubicSampling =
                bicubicRescaling == FramebufferSettings.BicubicRescalingMode.UpAndDown ||
                bicubicRescaling == FramebufferSettings.BicubicRescalingMode.UpOnly &&
                framebufferSize.x < camera.pixelWidth;
            cmd.SetGlobalFloat(copyBicubicId, bicubicSampling ? 1.0f : 0.0f);
            DrawFinal(finalResultId, Pass.FinalRescale);
            cmd.ReleaseTemporaryRT(finalResultId);
        }

        cmd.ReleaseTemporaryRT(colorGradingLUTId);
    }

}