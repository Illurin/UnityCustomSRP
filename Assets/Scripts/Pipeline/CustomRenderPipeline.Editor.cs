using Unity.Collections;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using LightType = UnityEngine.LightType;

public partial class CustomRenderPipeline
{
    partial void InitializeForEditor();
    partial void DisposeForEditor();

#if UNITY_EDITOR

    partial void InitializeForEditor()
    {
        Lightmapping.SetDelegate(lightsDelegate);
    }

    // Clean up and reset the delegate when our pipeline gets disposed
    partial void DisposeForEditor()
    {
        Lightmapping.ResetDelegate();
    }

    static Lightmapping.RequestLightsDelegate lightsDelegate =
        (Light[] lights, NativeArray<LightDataGI> output) =>
        {
            var lightData = new LightDataGI();
            for (int i = 0; i < lights.Length; ++i)
            {
                var light = lights[i];
                switch (light.type)
                {
                    case LightType.Directional:
                        var directionalLight = new DirectionalLight();
                        LightmapperUtils.Extract(light, ref directionalLight);
                        lightData.Init(ref directionalLight);
                        break;

                    case LightType.Point:
                        var pointLight = new DirectionalLight();
                        LightmapperUtils.Extract(light, ref pointLight);
                        lightData.Init(ref pointLight);
                        break;

                    case LightType.Spot:
                        var spotLight = new SpotLight();
                        LightmapperUtils.Extract(light, ref spotLight);
                        spotLight.innerConeAngle = light.innerSpotAngle * Mathf.Deg2Rad;     // In Unity 2022
                        spotLight.angularFalloff = AngularFalloffType.AnalyticAndInnerAngle; // In Unity 2022
                        lightData.Init(ref spotLight);
                        break;

                    case LightType.Area:
                        var areaLight = new RectangleLight();
                        LightmapperUtils.Extract(light, ref areaLight);
                        areaLight.mode = LightMode.Baked;   // Don't support realtime area lights
                        lightData.Init(ref areaLight);
                        break;

                    default:
                        lightData.InitNoBake(light.GetInstanceID());
                        break;
                }

                // Set the falloff type of the light data to for all lights
                lightData.falloff = FalloffType.InverseSquared;
                output[i] = lightData;
            }
        };

#endif

}