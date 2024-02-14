using UnityEditor;
using UnityEngine;

partial class PostEffectsStack
{
    partial void ApplySceneViewState();

#if UNITY_EDITOR

    partial void ApplySceneViewState()
    {
        // Check if the currently drawing scene view's state has image effects disabled
        if (camera.cameraType == CameraType.SceneView &&
            !SceneView.currentDrawingSceneView.sceneViewState.showImageEffects)
        {
            settings = null;
        }
    }

#endif
}