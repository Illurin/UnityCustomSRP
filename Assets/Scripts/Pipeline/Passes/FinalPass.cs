using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public class FinalPass
{
    static readonly ProfilingSampler sampler = new("Final");

    CameraRenderer renderer;

    CameraSettings.FinalBlendMode finalBlendMode;

    void Render(RenderGraphContext context)
    {
        renderer.DrawFinal(finalBlendMode);
        renderer.ExecuteCommands();
    }

    public static void Record(RenderGraph renderGraph, CameraRenderer renderer,
                              CameraSettings.FinalBlendMode finalBlendMode)
    {
        using var builder = renderGraph.AddRenderPass(sampler.name, out FinalPass pass, sampler);
        pass.renderer = renderer;
        pass.finalBlendMode = finalBlendMode;
        builder.SetRenderFunc<FinalPass>((pass, context) => pass.Render(context));
    }
}