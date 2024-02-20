using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    ScriptableRenderContext context;
    public Camera camera;

    //const string cmdName = "Render Camera";
    //CommandBuffer cmd = new CommandBuffer() { name = cmdName };
    CommandBuffer cmd;

    CullingResults cullingResults;

    // Shader tag ids
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"),
                       litShaderTagId = new ShaderTagId("CustomLit");

    public static int framebufferSizeId = Shader.PropertyToID("_FramebufferSize"),
                      colorAttachmentId = Shader.PropertyToID("_CameraColorAttachment"),
                      depthAttachmentId = Shader.PropertyToID("_CameraDepthAttachment"),
                      colorTextureId = Shader.PropertyToID("_CameraColorTexture"),
                      depthTextureId = Shader.PropertyToID("_CameraDepthTexture"),
                      sourceTextureId = Shader.PropertyToID("_SourceTexture"),
                      srcBlendId = Shader.PropertyToID("_CameraSrcBlend"),
                      dstBlendId = Shader.PropertyToID("_CameraDstBlend");

    // Lighting
    Lighting lighting = new Lighting();

    // Post processing
    PostEffectsStack postEffectsStack = new PostEffectsStack();

    // Camera settings
    static CameraSettings defaultCameraSettings = new CameraSettings();

    // Material for camera renderer shader
    Material material;

    // Default missing texture
    Texture2D missingTexture;

    // Settings
    bool useHDR, useScaledRendering;
    public bool useColorTexture, useDepthTexture, useIntermediateBuffer;
    static bool copyTextureSupported =
        SystemInfo.copyTextureSupport > CopyTextureSupport.None;    // "false" for WebGL 2.0

    Vector2Int framebufferSize;

    static Rect fullViewRect = new Rect(0.0f, 0.0f, 1.0f, 1.0f);

    public CameraRenderer(Shader shader)
    {
        // Prepare default material
        material = CoreUtils.CreateEngineMaterial(shader);

        // Prepare missing texture
        missingTexture = new Texture2D(1, 1)
        {
            hideFlags = HideFlags.HideAndDontSave,
            name = "Missing"
        };
        missingTexture.SetPixel(0, 0, Color.white * 0.5f);
        missingTexture.Apply(true, true);
    }

    public void Dispose()
    {
        // The method either regularly or immediately destroys the material and texture,
        // depending on whether Unity is in play mode or not
        CoreUtils.Destroy(material);
        CoreUtils.Destroy(missingTexture);
    }

    public void Render(RenderGraph renderGraph, ScriptableRenderContext renderContext, Camera camera, FramebufferSettings framebufferSettings,
                       bool enableDynamicBatching, bool enableGPUInstancing, bool useLightsPerObject,
                       ShadowSettings shadowSettings, PostEffectsSettings postEffectsSettings, int colorLUTResolution)
    {
        context = renderContext;
        this.camera = camera;


        // Get camera settings and sampler
        ProfilingSampler cameraSampler;
        CameraSettings cameraSettings;
        if (camera.TryGetComponent(out CustomRenderPipelineCamera cameraComponent))
        {
            cameraSampler = cameraComponent.Sampler;
            cameraSettings = cameraComponent.Settings;
        }
        else
        {
            cameraSampler = ProfilingSampler.Get(camera.cameraType);
            cameraSettings = defaultCameraSettings;
        }
        //var cameraComponent = camera.GetComponent<CustomRenderPipelineCamera>();
        //var cameraSettings = cameraComponent ? cameraComponent.Settings : defaultCameraSettings;

        if (cameraSettings.overridePostEffects)
        {
            postEffectsSettings = cameraSettings.postFXSettings;
        }

        // Determine whether scaled rendering should be used
        var renderScale = cameraSettings.GetRenderScale(framebufferSettings.renderScale);
        useScaledRendering = renderScale < 0.99f || renderScale > 1.01f;

        //PrepareCommandBuffer();
        PrepareForSceneWindow();

        // Get the real framebuffer size
        if (useScaledRendering)
        {
            renderScale = Mathf.Clamp(renderScale, 0.1f, 2.0f);
            framebufferSize.x = (int)(camera.pixelWidth * renderScale);
            framebufferSize.y = (int)(camera.pixelHeight * renderScale);
        }
        else
        {
            framebufferSize.x = camera.pixelWidth;
            framebufferSize.y = camera.pixelHeight;
        }

        if (!Cull(shadowSettings.maxDistance))
            return;

        // Setup post effects stack
        framebufferSettings.fxaa.enabled &= cameraSettings.allowFXAA;
        postEffectsStack.Setup(/*context, */camera, framebufferSize, postEffectsSettings,
                               cameraSettings.keepAlpha, useHDR,
                               colorLUTResolution, cameraSettings.finalBlendMode,
                               framebufferSettings.bicubicRescaling,
                               framebufferSettings.fxaa);

        // Get framebuffer settings
        useHDR = framebufferSettings.allowHDR && camera.allowHDR;

        if (camera.cameraType == CameraType.Reflection)
        {
            useColorTexture = framebufferSettings.copyColorReflection;
            useDepthTexture = framebufferSettings.copyDepthReflections;
        }
        else
        {
            useColorTexture = framebufferSettings.copyColor && cameraSettings.copyColor;
            useDepthTexture = framebufferSettings.copyDepth && cameraSettings.copyDepth;
        }

        useIntermediateBuffer = useScaledRendering || useColorTexture || useDepthTexture ||
                                postEffectsStack.IsActive;

        //cmd.BeginSample(cmdName);
        //ExecuteCommands();

        // Setup lighting and shadows
        //lighting.Setup(context, cullingResults, shadowSettings, useLightsPerObject,
        //               cameraSettings.maskLights ? cameraSettings.renderingLayerMask : -1);
        //cmd.EndSample(cmdName);

        // Regular rendering
        //Setup();

        //DrawVisibleGeometry(enableDynamicBatching, enableGPUInstancing, useLightsPerObject,
        //                    cameraSettings.renderingLayerMask);
        //DrawUnsupportedShaders();

        //DrawGizmosBeforeEffects();

        //if (postEffectsStack.IsActive)
        //{
        //    postEffectsStack.Render(colorAttachmentId);
        //}
        //else if (useIntermediateBuffer)
        //{
        //    // Avoid ignoring the viewport and final blend modes
        //    DrawFinal(cameraSettings.finalBlendMode);
        //    ExecuteCommands();
        //}

        //DrawGizmosAfterEffects();

        // Record and execute render graph
        var renderGraphParameters = new RenderGraphParameters
        {
            commandBuffer = CommandBufferPool.Get(),
            currentFrameIndex = Time.frameCount,
            executionName = cameraSampler.name,
            scriptableRenderContext = context
        };
        // Set the buffer to the same used for the render graph
        cmd = renderGraphParameters.commandBuffer;

        // What's used will be disposed of implicitly when the code execution leaves that scope
        using (renderGraph.RecordAndExecute(renderGraphParameters))
        {
            // Add an extra profiling scope at the top level of our render graph
            using var _ = new RenderGraphProfilingScope(renderGraph, cameraSampler);
            
            // Add passes here
            LightingPass.Record(renderGraph, lighting,
                                cullingResults, shadowSettings, useLightsPerObject,
                                cameraSettings.maskLights ? cameraSettings.renderingLayerMask : -1);

            SetupPass.Record(renderGraph, this);

            VisibleGeometryPass.Record(renderGraph, this,
                                       enableDynamicBatching, enableGPUInstancing, useLightsPerObject,
                                       cameraSettings.renderingLayerMask);

            UnsupportedShadersPass.Record(renderGraph, this);

            if (postEffectsStack.IsActive)
            {
                PostEffectsPass.Record(renderGraph, postEffectsStack);
            }
            else if (useIntermediateBuffer)
            {
                FinalPass.Record(renderGraph, this, cameraSettings.finalBlendMode);
            }

            GizmosPass.Record(renderGraph, this);
        }

        Cleanup();
        Submit();
        CommandBufferPool.Release(renderGraphParameters.commandBuffer);
    }

    public void Setup()
    {
        context.SetupCameraProperties(camera);

        CameraClearFlags clearFlags = camera.clearFlags;

        // Setup intermediate buffer
        if (useIntermediateBuffer)
        {
            // When a stack is active, always clear depth and color
            if (clearFlags > CameraClearFlags.Color)
            {
                clearFlags = CameraClearFlags.Color;
            }

            // Use separated buffers as intermediate render targets for the camera
            cmd.GetTemporaryRT(
                colorAttachmentId, framebufferSize.x, framebufferSize.y, 0,
                FilterMode.Bilinear, useHDR ?
                    RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default
            );
            cmd.GetTemporaryRT(
                depthAttachmentId, framebufferSize.x, framebufferSize.y, 32,
                FilterMode.Point, RenderTextureFormat.Depth
            );
            cmd.SetRenderTarget(
                colorAttachmentId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                depthAttachmentId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
            );
        }

        cmd.ClearRenderTarget(clearFlags <= CameraClearFlags.Depth,
                              clearFlags <= CameraClearFlags.Color,
                              clearFlags == CameraClearFlags.Color ? 
                              camera.backgroundColor.linear : Color.clear);

        //cmd.BeginSample(sampleName);
        cmd.SetGlobalTexture(colorTextureId, missingTexture);
        cmd.SetGlobalTexture(depthTextureId, missingTexture);
        cmd.SetGlobalVector(framebufferSizeId, new Vector4(
            1.0f / framebufferSize.x, 1.0f / framebufferSize.y,
            framebufferSize.x, framebufferSize.y
        ));
        ExecuteCommands();
    }

    void Cleanup()
    {
        lighting.Cleanup();
        if (useIntermediateBuffer)
        {
            cmd.ReleaseTemporaryRT(colorAttachmentId);
            cmd.ReleaseTemporaryRT(depthAttachmentId);

            if (useColorTexture)
                cmd.ReleaseTemporaryRT(colorTextureId);

            if (useDepthTexture)
                cmd.ReleaseTemporaryRT(depthTextureId);
        }
    }

    public void DrawVisibleGeometry(bool enableDynamicBatching, bool enableGPUInstancing, bool useLightsPerObject, int renderingLayerMask)
    {
        ExecuteCommands();

        // Draw opaque geometries
        var sortingSettings = new SortingSettings(camera);
        sortingSettings.criteria = SortingCriteria.CommonOpaque;

        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
        drawingSettings.SetShaderPassName(1, litShaderTagId);
        drawingSettings.enableDynamicBatching = enableDynamicBatching;
        drawingSettings.enableInstancing = enableGPUInstancing;

        // Pass more per object data to shaders
        PerObjectData lightsPerObjectFlags = useLightsPerObject ?
                                             PerObjectData.LightData | PerObjectData.LightIndices :
                                             PerObjectData.None;

        drawingSettings.perObjectData = PerObjectData.Lightmaps | PerObjectData.ShadowMask |
                                        PerObjectData.LightProbe | PerObjectData.LightProbeProxyVolume |
                                        PerObjectData.OcclusionProbe | PerObjectData.OcclusionProbeProxyVolume |
                                        PerObjectData.ReflectionProbes | lightsPerObjectFlags;

        // Set allowed material render queue range
        var filteringSettings = new FilteringSettings(
            RenderQueueRange.opaque, renderingLayerMask: (uint)renderingLayerMask
        );

        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        context.DrawSkybox(camera);

        if (useColorTexture || useDepthTexture)
        {
            CopyAttachments();
        }

        // Draw transparent geometries
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;

        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    public void Draw(RenderTargetIdentifier src, RenderTargetIdentifier dst, bool isDepth = false)
    {
        // Perform a final copy to the camera's target
        cmd.SetGlobalTexture(sourceTextureId, src);
        cmd.SetRenderTarget(dst, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cmd.DrawProcedural(Matrix4x4.identity, material, isDepth ? 1 : 0, MeshTopology.Triangles, 3);
    }

    public void DrawFinal(CameraSettings.FinalBlendMode finalBlendMode)
    {
        // Set final blend modes
        cmd.SetGlobalFloat(srcBlendId, (float)finalBlendMode.source);
        cmd.SetGlobalFloat(dstBlendId, (float)finalBlendMode.destination);

        var loadRenderBuffer = finalBlendMode.destination != BlendMode.Zero ||
                               camera.rect != fullViewRect;

        cmd.SetGlobalTexture(sourceTextureId, colorAttachmentId);
        cmd.SetRenderTarget(
            BuiltinRenderTextureType.CameraTarget,
            loadRenderBuffer ? RenderBufferLoadAction.Load : RenderBufferLoadAction.DontCare,
            RenderBufferStoreAction.Store
        );
        cmd.SetViewport(camera.pixelRect);
        cmd.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3);

        // Set the blend mode back to one-zero afterwards to not affect other copy actions
        cmd.SetGlobalFloat(srcBlendId, 1.0f);
        cmd.SetGlobalFloat(dstBlendId, 0.0f);
    }

    void Submit()
    {
        //cmd.EndSample(sampleName);
        ExecuteCommands();
        context.Submit();
    }

    public void ExecuteCommands()
    {
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
    }

    bool Cull(float maxShadowDistance)
    {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            // The shadow distance is set via the culling parameters
            p.shadowDistance = maxShadowDistance;

            // Get culling results
            cullingResults = context.Cull(ref p);
            return true;
        }
        return false;
    }

    void CopyAttachments()
    {
        if (useColorTexture)
        {
            cmd.GetTemporaryRT(
                colorTextureId, framebufferSize.x, framebufferSize.y,
                0, FilterMode.Bilinear, useHDR ?
                    RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default
            );

            // Copy the depth depth via if supported, otherwise fall back to using shader to draw
            if (copyTextureSupported)
            {
                cmd.CopyTexture(colorAttachmentId, colorTextureId);
            }
            else
            {
                Draw(colorAttachmentId, colorTextureId);
            }
        }
        if (useDepthTexture)
        {
            cmd.GetTemporaryRT(
                depthTextureId, framebufferSize.x, framebufferSize.y, 32,
                FilterMode.Point, RenderTextureFormat.Depth
            );

            if (copyTextureSupported)
            {
                cmd.CopyTexture(depthAttachmentId, depthTextureId);
            }
            else
            {
                Draw(depthAttachmentId, depthTextureId, true);
            }

            // Set back to correct render target
            if (!copyTextureSupported)
            {
                cmd.SetRenderTarget(
                    colorAttachmentId, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store,
                    depthAttachmentId, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store
                );
            }
            ExecuteCommands();
        }
    }
}