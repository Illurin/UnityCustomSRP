using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

partial class CameraRenderer
{
    //partial void PrepareCommandBuffer();
    partial void DrawGizmosBeforeEffects();
    partial void DrawGizmosAfterEffects();
    public partial void DrawUnsupportedShaders();
    partial void PrepareForSceneWindow();

#if UNITY_EDITOR

    static ShaderTagId[] legacyShaderTagIds =
    {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLM"),
        new ShaderTagId("VertexLMRGBM")
    };

    // Error material
    static Material errorMaterial;

    //string sampleName;

    //partial void PrepareCommandBuffer()
    //{
    //    // Check GC alloc
    //    Profiler.BeginSample("Editor Only");
    //    cmd.name = sampleName = camera.name;
    //    Profiler.EndSample();
    //}

    public partial void DrawUnsupportedShaders()
    {
        // Prepare error material
        if (errorMaterial == null)
        {
            errorMaterial = new Material(Shader.Find("Hidden/InternalErrorShader"));
        }

        var drawingSettings = new DrawingSettings(legacyShaderTagIds[0], new SortingSettings(camera));
        for (int i = 1; i < legacyShaderTagIds.Length; ++i)
        {
            drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
        }

        drawingSettings.overrideMaterial = errorMaterial;

        var filteringSettings = FilteringSettings.defaultValue;

        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    partial void DrawGizmosBeforeEffects()
    {
        if (Handles.ShouldRenderGizmos())
        {
            // Make our gizmos depth-aware
            if (useIntermediateBuffer)
            {
                Draw(depthAttachmentId, BuiltinRenderTextureType.CameraTarget, true);
                ExecuteCommands();
            }
            context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
        }
    }

    partial void DrawGizmosAfterEffects()
    {
        if (Handles.ShouldRenderGizmos())
        {
            // Make our gizmos depth-aware
            if (postEffectsStack.IsActive)
            {
                Draw(depthAttachmentId, BuiltinRenderTextureType.CameraTarget, true);
                ExecuteCommands();
            }
            context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
        }
    }

    partial void PrepareForSceneWindow()
    {
        // Show UI in editor
        if (camera.cameraType == CameraType.SceneView)
        {
            // Emits UI geometry into the Scene view for rendering
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);

            // We don't want the configured render scale to affect scene windows
            useScaledRendering = false;
        }
    }

//#else

//    const string sampleName = cmdName;
    
#endif
}