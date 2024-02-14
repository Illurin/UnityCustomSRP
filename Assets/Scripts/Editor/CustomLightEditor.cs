using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

[CanEditMultipleObjects]
[CustomEditorForRenderPipeline(typeof(Light), typeof(CustomRenderPipelineAsset))]
public class CustomLightEditor : LightEditor
{
    // Our own version of light rendering Layer mask
    static GUIContent renderingLayerMaskLabel =
        new GUIContent("Rendering Layer Mask", "Functional version of above property.");

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        RenderingLayerMaskDrawer.Draw(
            settings.renderingLayerMask, renderingLayerMaskLabel
        );

        if (!settings.lightType.hasMultipleDifferentValues &&
            (LightType)settings.lightType.enumValueIndex == LightType.Spot)
        {
            // Add an inner-outer spot angle slider underneath the default inspector
            settings.DrawInnerAndOuterSpotAngle();
        }

        // Invoke to apply any changes made
        settings.ApplyModifiedProperties();

        // Warning for setting culling mask
        var light = target as Light;
        if (light.cullingMask != -1)
        {
            EditorGUILayout.HelpBox(
                light.type == LightType.Directional ?
                    "Culling Mask only affects shadows." :
                    "Culling Mask only affects shadow unless Use Lights Per Objects is on.",
                MessageType.Warning
            );
        }
    }
}
