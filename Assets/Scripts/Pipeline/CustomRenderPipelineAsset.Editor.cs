using UnityEngine;

partial class CustomRenderPipelineAsset
{

#if UNITY_EDITOR

    static string[] renderingLayerNames;

    static CustomRenderPipelineAsset()
    {
        renderingLayerNames = new string[32];
        for (int i = 0; i < renderingLayerNames.Length; i++)
        {
            renderingLayerNames[i] = "Layer " + (i + 1);
        }
    }

    // Override the default rendering layer labels
    public override string[] renderingLayerMaskNames => renderingLayerNames;

#endif

}