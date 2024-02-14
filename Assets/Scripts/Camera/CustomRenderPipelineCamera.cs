using UnityEngine;

[DisallowMultipleComponent, RequireComponent(typeof(Camera))]
public class CustomRenderPipelineCamera : MonoBehaviour
{
    [SerializeField]
    CameraSettings settings = default;

    public CameraSettings Settings => settings ?? (settings = new CameraSettings());

 // public CameraSettings Settings
 // {
 //     get
 //     {
 //         if (settings == null)
 //         {
 //             settings = new CameraSettings();
 //         }
 //         return settings;
 //     }
 // }
}