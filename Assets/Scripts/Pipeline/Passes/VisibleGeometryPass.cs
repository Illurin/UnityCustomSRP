using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

public class VisibleGeometryPass
{
    static readonly ProfilingSampler sampler = new("Visible Geometry");

    CameraRenderer renderer;

	bool enableDynamicBatching, enableGPUInstancing, enableLightsPerObject;

	int renderingLayerMask;

	void Render(RenderGraphContext context) => renderer.DrawVisibleGeometry(
        enableDynamicBatching, enableGPUInstancing, enableLightsPerObject, renderingLayerMask);

	public static void Record(RenderGraph renderGraph, CameraRenderer renderer,
		                      bool enableDynamicBatching, bool enableGPUInstancing, bool enableLightsPerObject,
		                      int renderingLayerMask)
	{
		using var builder = renderGraph.AddRenderPass(sampler.name, out VisibleGeometryPass pass, sampler);
		pass.renderer = renderer;
		pass.enableDynamicBatching = enableDynamicBatching;
		pass.enableGPUInstancing = enableGPUInstancing;
		pass.enableLightsPerObject = enableLightsPerObject;
		pass.renderingLayerMask = renderingLayerMask;
		builder.SetRenderFunc<VisibleGeometryPass>((pass, context) => pass.Render(context));
	}
}