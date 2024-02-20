using System.Diagnostics;
using UnityEditor;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public class GizmosPass
{
#if UNITY_EDITOR
    static readonly ProfilingSampler sampler = new("Gizmos");

    CameraRenderer renderer;

    void Render(RenderGraphContext context)
    {
        // Make our gizmos depth-aware
        if (renderer.useIntermediateBuffer)
        {
            renderer.Draw(CameraRenderer.depthAttachmentId, BuiltinRenderTextureType.CameraTarget, true);
            renderer.ExecuteCommands();
        }
        context.renderContext.DrawGizmos(renderer.camera, GizmoSubset.PreImageEffects);
        context.renderContext.DrawGizmos(renderer.camera, GizmoSubset.PostImageEffects);
    }
#endif

    // The code should be included only if compiling for the editor
    [Conditional("UNITY_EDITOR")]
    public static void Record(RenderGraph renderGraph, CameraRenderer renderer)
    {
#if UNITY_EDITOR
        if (Handles.ShouldRenderGizmos())
        {
            // Set the renderer and provide a function that invokes the imaginary interface method
            using var builder = renderGraph.AddRenderPass(sampler.name, out GizmosPass pass, sampler);
            pass.renderer = renderer;
            builder.SetRenderFunc<GizmosPass>((pass, context) => pass.Render(context));
        }
#endif
    }
}