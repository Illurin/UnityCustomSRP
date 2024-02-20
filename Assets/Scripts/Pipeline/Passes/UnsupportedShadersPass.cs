using System.Diagnostics;
using UnityEngine;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RendererUtils;

public class UnsupportedShadersPass
{
#if UNITY_EDITOR
    static readonly ProfilingSampler sampler = new("Unsupported Shaders");

    RendererListHandle list;

    static ShaderTagId[] legacyShaderTagIds =
    {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLM"),
        new ShaderTagId("VertexLMRGBM")
    };

    static Material errorMaterial;

    void Render(RenderGraphContext context) 
    {
        context.cmd.DrawRendererList(list);
        context.renderContext.ExecuteCommandBuffer(context.cmd);
        context.cmd.Clear();
    }
#endif

    // The code should be included only if compiling for the editor
    [Conditional("UNITY_EDITOR")]
    public static void Record(RenderGraph renderGraph, Camera camera, CullingResults cullingResults)
    {
#if UNITY_EDITOR
        using var builder = renderGraph.AddRenderPass(sampler.name, out UnsupportedShadersPass pass, sampler);

        if (errorMaterial == null)
        {
            errorMaterial = new(Shader.Find("Hidden/InternalErrorShader"));
        }

        // The renderer list description replaces the drawing, filtering, and sorting settings
        pass.list = builder.UseRendererList(renderGraph.CreateRendererList(
            new RendererListDesc(legacyShaderTagIds, cullingResults, camera)
            {
                overrideMaterial = errorMaterial,
                renderQueueRange = RenderQueueRange.all
            }));
    
        builder.SetRenderFunc<UnsupportedShadersPass>((pass, context) => pass.Render(context));
#endif
    }
}