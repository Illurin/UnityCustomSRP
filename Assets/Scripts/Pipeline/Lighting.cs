using System;
using Unity.Collections;
using UnityEditor.Rendering.LookDev;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    const string cmdName = "Lighting";
    CommandBuffer cmd = new CommandBuffer { name = cmdName };

    const int maxDirLightCount = 4, maxOtherLightCount = 64;

    // Shader property ids
    static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
               dirLightStrengthsId = Shader.PropertyToID("_DirectionalLightStrengths"),
               dirLightDirectionsAndMasksId = Shader.PropertyToID("_DirectionalLightDirectionsAndMasks"),
               dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData"),

               otherLightCountId = Shader.PropertyToID("_OtherLightCount"),
               otherLightStrengthsId = Shader.PropertyToID("_OtherLightStrengths"),
               otherLightPositionsId = Shader.PropertyToID("_OtherLightPositions"),
               otherLightDirectionsAndMasksId = Shader.PropertyToID("_OtherLightDirectionsAndMasks"),
               otherLightSpotAnglesId = Shader.PropertyToID("_OtherLightSpotAngles"),
               otherLightShadowDataId = Shader.PropertyToID("_OtherLightShadowData");

    // Light properties
    static Vector4[] dirLightStrengths = new Vector4[maxDirLightCount],
                     dirLightDirectionsAndMasks = new Vector4[maxDirLightCount],
                     dirLightShadowData = new Vector4[maxDirLightCount],

                     otherLightStrengths = new Vector4[maxOtherLightCount],
                     otherLightPositions = new Vector4[maxOtherLightCount],
                     otherLightDirectionsAndMasks = new Vector4[maxOtherLightCount],
                     otherLightSpotAngles = new Vector4[maxOtherLightCount],
                     otherLightShadowData = new Vector4[maxOtherLightCount];

    // For visible lights
    CullingResults cullingResults;

    // Shadows instance
    Shadows shadows = new Shadows();

    // Shader variant for lights per object
    static string lightsPerObjectKeyword = "_LIGHTS_PER_OBJECT";

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults,
                      ShadowSettings shadowSettings, bool useLightsPerObject, int renderingLayerMask)
    {
        this.cullingResults = cullingResults;
        
        cmd.BeginSample(cmdName);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        shadows.Setup(context, cullingResults, shadowSettings);
        SetupLights(useLightsPerObject, renderingLayerMask);
        shadows.Render();

        cmd.EndSample(cmdName);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
    }

    void SetupLights(bool useLightsPerObject, int renderingLayerMask)
    {
        var visibleLights = cullingResults.visibleLights;
        int dirLightCount = 0, otherLightCount = 0;

        // If use lights per object, allocate light index map
        var indexMap = useLightsPerObject ? cullingResults.GetLightIndexMap(Allocator.Temp)
                                          : default;

        int i;
        for (i = 0; i < visibleLights.Length; ++i)
        {
            int newIndex = -1;
            var light = visibleLights[i];

            if ((light.light.renderingLayerMask & renderingLayerMask) != 0)
            {
                switch (light.lightType)
                {
                    case LightType.Directional:
                        if (dirLightCount < maxDirLightCount)
                        {
                            SetupDirectionalLight(dirLightCount++, i, ref light);
                        }
                        break;

                    case LightType.Point:
                        if (otherLightCount < maxOtherLightCount)
                        {
                            newIndex = otherLightCount;
                            SetupPointLight(otherLightCount++, i, ref light);
                        }
                        break;

                    case LightType.Spot:
                        if (otherLightCount < maxOtherLightCount)
                        {
                            newIndex = otherLightCount;
                            SetupSpotLight(otherLightCount++, i, ref light);
                        }
                        break;
                }
            }

            // Set the new index only if we retrieved the map
            if (useLightsPerObject)
            {
                indexMap[i] = newIndex;
            }
        }

        if (useLightsPerObject)
        {
            for (; i < indexMap.Length; ++i)
            {
                indexMap[i] = -1;
            }

            // Send the adjusted index map back to Unity
            cullingResults.SetLightIndexMap(indexMap);

            // Deallocate the index map
            indexMap.Dispose();

            Shader.EnableKeyword(lightsPerObjectKeyword);
        }
        else 
        {
            Shader.DisableKeyword(lightsPerObjectKeyword);
        }

        // Send light properties to the shader
        cmd.SetGlobalInt(dirLightCountId, dirLightCount);
        if (dirLightCount > 0)
        {
            cmd.SetGlobalVectorArray(dirLightStrengthsId, dirLightStrengths);
            cmd.SetGlobalVectorArray(dirLightDirectionsAndMasksId, dirLightDirectionsAndMasks);
            cmd.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
        }

        cmd.SetGlobalInt(otherLightCountId, otherLightCount);
        if (otherLightCount > 0)
        {
            cmd.SetGlobalVectorArray(otherLightStrengthsId, otherLightStrengths);
            cmd.SetGlobalVectorArray(otherLightPositionsId, otherLightPositions);
            cmd.SetGlobalVectorArray(otherLightDirectionsAndMasksId, otherLightDirectionsAndMasks);
            cmd.SetGlobalVectorArray(otherLightSpotAnglesId, otherLightSpotAngles);
            cmd.SetGlobalVectorArray(otherLightShadowDataId, otherLightShadowData);
        }
    }

    void SetupDirectionalLight(int index, int visibleLightIndex, ref VisibleLight visibleLight)
    {
        var light = visibleLight.light;
        dirLightStrengths[index] = visibleLight.finalColor;
        dirLightDirectionsAndMasks[index] = visibleLight.localToWorldMatrix.GetColumn(2);
        dirLightDirectionsAndMasks[index].w = light.renderingLayerMask.ReinterpretAsFloat();
        dirLightShadowData[index] = shadows.ReserveDirectionalShadows(light, visibleLightIndex);
    }

    void SetupPointLight(int index, int visibleLightIndex, ref VisibleLight visibleLight)
    {
        var light = visibleLight.light;
        otherLightStrengths[index] = visibleLight.finalColor;
        // xyz for position, w for range attenuation
        var position = visibleLight.localToWorldMatrix.GetColumn(3);
        position.w = 1.0f / Mathf.Max(visibleLight.range * visibleLight.range, 0.00001f);
        otherLightPositions[index] = position;
        otherLightSpotAngles[index] = new Vector4(0.0f, 1.0f);
        otherLightDirectionsAndMasks[index].w = light.renderingLayerMask.ReinterpretAsFloat();

        otherLightShadowData[index] = shadows.ReserveOtherShadows(light, visibleLightIndex);
    }

    void SetupSpotLight(int index, int visibleLightIndex, ref VisibleLight visibleLight)
    {
        var light = visibleLight.light;
        otherLightStrengths[index] = visibleLight.finalColor;
        // xyz for position, w for range attenuation
        Vector4 position = visibleLight.localToWorldMatrix.GetColumn(3);
        position.w = 1.0f / Mathf.Max(visibleLight.range * visibleLight.range, 0.00001f);
        otherLightPositions[index] = position;
        otherLightDirectionsAndMasks[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        otherLightDirectionsAndMasks[index].w = light.renderingLayerMask.ReinterpretAsFloat();

        // Calculate spot angle attenuation
        var innerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * light.innerSpotAngle);
        var outerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * visibleLight.spotAngle);
        var angleRangeInv = 1.0f / Mathf.Max(innerCos - outerCos, 0.001f);
        otherLightSpotAngles[index] = new Vector4(angleRangeInv, -outerCos * angleRangeInv);
        
        otherLightShadowData[index] = shadows.ReserveOtherShadows(light, visibleLightIndex);
    }

    public void Cleanup()
    {
        shadows.Cleanup();
    }
}