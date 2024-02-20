using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public class SetupPass
{
    static readonly ProfilingSampler sampler = new("Setup");

    CameraRenderer renderer;

    void Render(RenderGraphContext context) => renderer.Setup();

    public static void Record(RenderGraph renderGraph, CameraRenderer renderer)
    {
        using var builder = renderGraph.AddRenderPass(sampler.name, out SetupPass pass, sampler);
        pass.renderer = renderer;
        builder.SetRenderFunc<SetupPass>((pass, context) => pass.Render(context));
    }
}