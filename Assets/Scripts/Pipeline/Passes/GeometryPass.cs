using UnityEngine;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;

public class GeometryPass
{
    static readonly ProfilingSampler samplerOpaque = new("Opaque Geometry"),
                                     samplerTransparent = new("Transparent Geometry");

    static readonly ShaderTagId[] shaderTagIds = {
        new("SRPDefaultUnlit"),
        new("CustomLit")
    };

    RendererListHandle list;

    void Render(RenderGraphContext context)
    {
        context.cmd.DrawRendererList(list);
        context.renderContext.ExecuteCommandBuffer(context.cmd);
        context.cmd.Clear();
    }

    public static void Record(RenderGraph renderGraph, Camera camera, CullingResults cullingResults,
                              bool useLightsPerObject, int renderingLayerMask, bool opaque)
    {
        var sampler = opaque ? samplerOpaque : samplerTransparent;
        using var builder = renderGraph.AddRenderPass(sampler.name, out GeometryPass pass, sampler);

        // The renderer list description replaces the drawing, filtering, and sorting settings
        pass.list = builder.UseRendererList(renderGraph.CreateRendererList(
            new RendererListDesc(shaderTagIds, cullingResults, camera)
            {
                sortingCriteria = opaque ?
                    SortingCriteria.CommonOpaque : SortingCriteria.CommonTransparent,
                // Pass more per object data to shaders
                rendererConfiguration =
                    PerObjectData.ReflectionProbes |
                    PerObjectData.Lightmaps |
                    PerObjectData.ShadowMask |
                    PerObjectData.LightProbe |
                    PerObjectData.OcclusionProbe |
                    PerObjectData.LightProbeProxyVolume |
                    PerObjectData.OcclusionProbeProxyVolume |
                    (useLightsPerObject ?
                        PerObjectData.LightData | PerObjectData.LightIndices :
                        PerObjectData.None),
                renderQueueRange = opaque ?
                    RenderQueueRange.opaque : RenderQueueRange.transparent,
                layerMask = renderingLayerMask
                //renderingLayerMask = (uint)renderingLayerMask    // In Unity 2022
            }));

        builder.SetRenderFunc<GeometryPass>((pass, context) => pass.Render(context));
    }
}