using UnityEngine;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public class SkyboxPass
{
    static readonly ProfilingSampler sampler = new("Skybox");

    Camera camera;

    void Render(RenderGraphContext context)
    {
        context.renderContext.ExecuteCommandBuffer(context.cmd);
        context.cmd.Clear();
        context.renderContext.DrawSkybox(camera);
    }

    public static void Record(RenderGraph renderGraph, Camera camera)
    {
        if (camera.clearFlags == CameraClearFlags.Skybox)
        {
            using var builder = renderGraph.AddRenderPass(sampler.name, out SkyboxPass pass, sampler);
            pass.camera = camera;
            builder.SetRenderFunc<SkyboxPass>((pass, context) => pass.Render(context));
        }
    }
}