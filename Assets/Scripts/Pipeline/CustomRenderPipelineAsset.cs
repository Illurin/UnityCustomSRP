using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;

public partial class CustomRenderPipeline : RenderPipeline
{
    CameraRenderer renderer;

    FramebufferSettings framebufferSettings;

    bool enableDynamicBatching, enableGPUInstancing, useLightsPerObject;
    ShadowSettings shadowSettings;

    PostEffectsSettings postEffectsSettings;

    int colorLUTResolution;

    // Upgrade to render graph API
    readonly RenderGraph renderGraph = new("Custom SRP Render Graph");

    public CustomRenderPipeline(FramebufferSettings framebufferSettings,
                                bool enableDynamicBatching, bool enableGPUInstancing, bool enableSRPBatcher,
                                bool useLightsPerObject, ShadowSettings shadowSettings,
                                PostEffectsSettings postEffectsSettings, int colorLUTResolution,
                                Shader cameraRendererShader)
    {
        this.framebufferSettings = framebufferSettings;
        this.enableDynamicBatching = enableDynamicBatching;
        this.enableGPUInstancing = enableGPUInstancing;
        GraphicsSettings.useScriptableRenderPipelineBatching = enableSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        this.useLightsPerObject = useLightsPerObject;
        this.shadowSettings = shadowSettings;
        this.postEffectsSettings = postEffectsSettings;
        this.colorLUTResolution = colorLUTResolution;

        InitializeForEditor();

        renderer = new CameraRenderer(cameraRendererShader);
    }

    protected override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    { }

    protected override void Render(ScriptableRenderContext renderContext, List<Camera> cameras)
    {
        foreach (var camera in cameras)
        {
            renderer.Render(renderGraph, renderContext, camera, framebufferSettings,
                            enableDynamicBatching, enableGPUInstancing, useLightsPerObject,
                            shadowSettings, postEffectsSettings, colorLUTResolution);
        }
        renderGraph.EndFrame();
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        DisposeForEditor();
        renderer.Dispose();
        renderGraph.Cleanup();
    }
}

[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline Asset")]
public partial class CustomRenderPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    FramebufferSettings framebufferSettings = new FramebufferSettings
    {
        allowHDR = true,
        renderScale = 1f,
        fxaa = new FramebufferSettings.FXAA
        { 
            fixedThreshold = 0.0833f,
            relativeThreshold = 0.166f,
            subpixelBlending = 0.75f
        }
    };

    [SerializeField]
    bool enableDynamicBatching = true, enableGPUInstancing = true, enableSRPBatcher = true,
         useLightsPerObject = true;

    [SerializeField]
    ShadowSettings shadowSettings = default;

    [SerializeField]
    PostEffectsSettings postEffectsSettings = default;

    // Color LUT configuration
    public enum ColorLUTResolution { _16 = 16, _32 = 32, _64 = 64 }

    [SerializeField]
    ColorLUTResolution colorLUTResolution = ColorLUTResolution._32;

    [SerializeField]
    Shader cameraRendererShader = default;

    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderPipeline(framebufferSettings, enableDynamicBatching, enableGPUInstancing, enableSRPBatcher,
                                        useLightsPerObject, shadowSettings, postEffectsSettings,
                                        (int)colorLUTResolution, cameraRendererShader);
    }
}