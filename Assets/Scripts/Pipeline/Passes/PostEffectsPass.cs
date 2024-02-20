using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public class PostEffectsPass
{
    static readonly ProfilingSampler sampler = new("Post Effects");

    PostEffectsStack postEffectsStack;

    void Render(RenderGraphContext context) =>
        postEffectsStack.Render(context, CameraRenderer.colorAttachmentId);

    public static void Record(RenderGraph renderGraph, PostEffectsStack postEffectsStack)
    {
        using RenderGraphBuilder builder =
            renderGraph.AddRenderPass(sampler.name, out PostEffectsPass pass, sampler);
        pass.postEffectsStack = postEffectsStack;
        builder.SetRenderFunc<PostEffectsPass>((pass, context) => pass.Render(context));
    }
}