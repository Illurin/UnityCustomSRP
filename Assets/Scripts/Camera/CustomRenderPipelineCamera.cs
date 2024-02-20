using UnityEngine;
using UnityEngine.Rendering;

[DisallowMultipleComponent, RequireComponent(typeof(Camera))]
public class CustomRenderPipelineCamera : MonoBehaviour
{
    [SerializeField]
    CameraSettings settings = default;

    // Cache both the camera name and the profiling sampler
    ProfilingSampler sampler;
    public ProfilingSampler Sampler => sampler ??= new(GetComponent<Camera>().name);


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

    // Update the sampler when our component is enabled
#if UNITY_EDITOR || DEVELOPMENT_BUILD
	void OnEnable() => sampler = null;
#endif
}