using System;
using UnityEngine;
using UnityEngine.Rendering;

public class Shadows
{
    const string cmdName = "Shadows";
    CommandBuffer cmd = new CommandBuffer { name = cmdName };

    ScriptableRenderContext context;
    CullingResults cullingResults;
    ShadowSettings settings;

    // Restrictions
    const int maxShadowedDirectionalLightCount = 4, maxShadowedOtherLightCount = 16;
    const int maxCascades = 4;

    // Shadowed light data
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float nearPlaneOffset;
    }

    struct ShadowedOtherLight
    {
        public int visibleLightIndex;
        public float slopeScaleBias;
        public float normalBias;
        public bool isPoint;
    }

    int shadowedDirectionalLightCount, shadowedOtherLightCount;

    ShadowedDirectionalLight[] shadowedDirectionalLights =
        new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];
    ShadowedOtherLight[] shadowedOtherLights =
        new ShadowedOtherLight[maxShadowedOtherLightCount];

    // Shadow atlas properties
    static int shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize"),

               dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
               dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),

               otherShadowAtlasId = Shader.PropertyToID("_OtherShadowAtlas"),
               otherShadowMatricesId = Shader.PropertyToID("_OtherShadowMatrices"),
               otherShadowTilesId = Shader.PropertyToID("_OtherShadowTiles");

    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades],
                       otherShadowMatrices = new Matrix4x4[maxShadowedOtherLightCount];

    Vector4 atlasSizes; // xy for directional shadow atlas, zw for other shadow altas
                        // Store the atlas size in its 1st component and texel size in its 2nd component

    // Cascade properties
    static int cascadeCountId = Shader.PropertyToID("_CascadeCount"),
               cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
               cascadeDataId = Shader.PropertyToID("_CascadeData"),
               shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade"),
               shadowPancakingId = Shader.PropertyToID("_ShadowPancaking");

    static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades],
                     cascadeData = new Vector4[maxCascades],
                     otherShadowTiles = new Vector4[maxShadowedOtherLightCount];

    // Shadow mask properties
    bool useShadowMask;

    // Shader variants
    static string[] directionalFilterKeywords = {
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    static string[] otherFilterKeywords = {
        "_OTHER_PCF3",
        "_OTHER_PCF5",
        "_OTHER_PCF7",
    };

    static string[] cascadeBlendKeywords = {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };

    static string[] shadowMaskKeywords = {
        "_SHADOW_MASK_ALWAYS",
        "_SHADOW_MASK_DISTANCE"
    };

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults,
                      ShadowSettings settings)
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
        shadowedDirectionalLightCount = shadowedOtherLightCount = 0;
        useShadowMask = false;
    }

    void ExecuteCommands()
    {
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
    }

    public Vector4 ReserveDirectionalShadows(Light light, int visibleLightIndex)
    {
        // The light doesn't cast any shadow
        if (shadowedDirectionalLightCount >= maxShadowedDirectionalLightCount ||
            light.shadows == LightShadows.None || light.shadowStrength < 0.0f)
        {
            return new Vector4(0.0f, 0.0f, 0.0f, -1.0f);
        }

        // Make sure if use shadow mask
        int maskChannel = -1;
        LightBakingOutput lightBaking = light.bakingOutput;
        if (lightBaking.lightmapBakeType == LightmapBakeType.Mixed &&
            lightBaking.mixedLightingMode == MixedLightingMode.Shadowmask)
        {
            useShadowMask = true;
            maskChannel = lightBaking.occlusionMaskChannel;
        }

        // Only use baked shadow
        if (!cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            return new Vector4(-light.shadowStrength,   // Avoid sampling the shadow map
                               0.0f, 0.0f, maskChannel);
        }
        
        shadowedDirectionalLights[shadowedDirectionalLightCount] =
            new ShadowedDirectionalLight
            { visibleLightIndex = visibleLightIndex,
              slopeScaleBias = light.shadowBias,
              nearPlaneOffset = light.shadowNearPlane };

        // Provide the shadow strength and the shadow tile offset
        return new Vector4(light.shadowStrength,
                           settings.directional.cascadeCount * shadowedDirectionalLightCount++,
                           light.shadowNormalBias, maskChannel);
    }

    public Vector4 ReserveOtherShadows(Light light, int visibleLightIndex)
    {
        // The light doesn't cast any shadow
        if (light.shadows == LightShadows.None || light.shadowStrength < 0.0f)
        {
            return new Vector4(0.0f, 0.0f, 0.0f, -1.0f);
        }

        // Make sure if use shadow mask
        float maskChannel = -1.0f;

        LightBakingOutput lightBaking = light.bakingOutput;
        if (lightBaking.lightmapBakeType == LightmapBakeType.Mixed &&
            lightBaking.mixedLightingMode == MixedLightingMode.Shadowmask)
        {
            useShadowMask = true;
            maskChannel = lightBaking.occlusionMaskChannel;
        }

        //  If point light is used, the new light count would be six greater than the current count
        bool isPoint = light.type == LightType.Point;
        int newLightCount = shadowedOtherLightCount + (isPoint ? 6 : 1);

        // Only use baked shadow
        if (newLightCount > maxShadowedOtherLightCount ||
            !cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            return new Vector4(-light.shadowStrength, 0.0f, 0.0f, maskChannel);
        }
        
        shadowedOtherLights[shadowedOtherLightCount] = new ShadowedOtherLight
        {
            visibleLightIndex = visibleLightIndex,
            slopeScaleBias = light.shadowBias,
            normalBias = light.shadowNormalBias,
            isPoint = isPoint
        };

        var result = new Vector4(light.shadowStrength, shadowedOtherLightCount,
                                 isPoint ? 1.0f : 0.0f, maskChannel);
        shadowedOtherLightCount = newLightCount;
        return result;
    }

    public void Render()
    {
        if (shadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();
        }
        else
        {
            // Get a 1¡Á1 dummy texture when no shadows are needed, avoiding extra shader variants
            cmd.GetTemporaryRT(
                dirShadowAtlasId, 1, 1,
                32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
            );
        }

        if (shadowedOtherLightCount > 0)
        {
            RenderOtherShadows();
        }
        else
        {
            // Simply use the directional shadow atlas as the dummy
            cmd.SetGlobalTexture(otherShadowAtlasId, dirShadowAtlasId);
        }

        cmd.BeginSample(cmdName);

        // Set shadow mask
        SetKeywords(shadowMaskKeywords, useShadowMask ?
                    QualitySettings.shadowmaskMode == ShadowmaskMode.Shadowmask ? 0 : 1
                    : -1);

        // If we don't have directional light, we still need to set cascade fade
        cmd.SetGlobalInt(cascadeCountId, shadowedDirectionalLightCount > 0 ?
                                         settings.directional.cascadeCount : 0);

        // Avoid divisions in the shader
        var cascadeFade = 1.0f - settings.directional.cascadeFade;
        cmd.SetGlobalVector(shadowDistanceFadeId,
                            new Vector3(1.0f / settings.maxDistance,
                                        1.0f / settings.distanceFade,
                                        1.0f / (1.0f - cascadeFade * cascadeFade)));

        cmd.SetGlobalVector(shadowAtlasSizeId, atlasSizes);
        cmd.EndSample(cmdName);
        ExecuteCommands();
    }
    void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        // Calculate texel size for different cascade
        float texelSize = 2.0f * cullingSphere.w / tileSize;

        // Increase the normal bias to match the PCF filter size
        float filterSize = texelSize * ((float)settings.directional.filterMode + 1.0f);
        cullingSphere.w -= filterSize;

        // Store the squared radius
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[index] = cullingSphere;

        cascadeData[index] = new Vector4(1.0f / cullingSphere.w, filterSize * 1.4142136f);
    }

    void SetOtherTileData(int index, Vector2 offset, float scale, float bias)
    {
        float border = atlasSizes.w * 0.5f;
        var data = Vector4.zero;
        data.x = offset.x * scale + border; // Tile bounds offset
        data.y = offset.y * scale + border;
        data.z = scale - border - border;   // Tile bounds scale
        data.w = bias;                      // Normal bias
        otherShadowTiles[index] = data;
    }

    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        Vector2 offset = new Vector2(index % split, index / split);
        cmd.SetViewport(new Rect(
            offset.x * tileSize, offset.y * tileSize, tileSize, tileSize
        ));
        return offset;
    }

    void RenderDirectionalShadows(int index, int split, int tileSize)
    {
        var light = shadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(
            cullingResults, light.visibleLightIndex
        // , BatchCullingProjectionType.Orthographic     // In Unity 2022
        );
        shadowSettings.useRenderingLayerMaskTest = true;

        var cascadeCount = settings.directional.cascadeCount;
        var tileOffset = index * cascadeCount;
        var cascadeRatios = settings.directional.CascadeRatios;

        // Make sure that shadow casters in the transition region never get culled
        var cullingFactor = Mathf.Max(0.0f, 0.8f - settings.directional.cascadeFade);

        float tileScale = 1.0f / split;

        for (int i = 0; i < cascadeCount; ++i)
        {
            // Calculate view and projection matrices
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, cascadeRatios, tileSize, light.nearPlaneOffset,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );

            // Cull unnecessary shadow casters from larger cascades
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;

            shadowSettings.splitData = splitData;
            cmd.SetViewProjectionMatrices(viewMatrix, projectionMatrix);

            // The cascades of all lights are equivalent
            if (index == 0)
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }

            // Set shadow tile
            var tileIndex = tileOffset + i;
            var offset = SetTileViewport(tileIndex, split, tileSize);

            // Set shadow drawing parameters
            cmd.SetGlobalDepthBias(0.0f, light.slopeScaleBias);

            ExecuteCommands();

            // Draw shadows
            context.DrawShadows(ref shadowSettings);
            cmd.SetGlobalDepthBias(0.0f, 0.0f);

            // Calculate shadow matrix
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,
                                                                offset, tileScale);
        }
    }

    void RenderDirectionalShadows() 
    {
        // Use a square render texture for shadow map
        var atlasSize = (int)settings.directional.atlasSize;
        atlasSizes.x = atlasSize;
        atlasSizes.y = 1.0f / atlasSize;

        cmd.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize,
                           32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);

        // Instruct the GPU to render to this texture
        cmd.SetRenderTarget(dirShadowAtlasId,
                            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cmd.ClearRenderTarget(true, false, Color.clear);

        // Split shadow atlas
        var tileCount = shadowedDirectionalLightCount * settings.directional.cascadeCount;
        var split = tileCount <= 1 ? 1 : tileCount <= 4 ? 2 : 4;
        var tileSize = atlasSize / split;

        // Render shadows
        cmd.BeginSample(cmdName);
        ExecuteCommands();

        // Enable clamping for shadow pancaking
        cmd.SetGlobalFloat(shadowPancakingId, 1.0f);

        for (int i = 0; i < shadowedDirectionalLightCount; ++i)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }

        // Set shadow matrices
        cmd.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);

        // Set cascade properties
        cmd.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        cmd.SetGlobalVectorArray(cascadeDataId, cascadeData);

        SetKeywords(directionalFilterKeywords, (int)settings.directional.filterMode - 1);
        SetKeywords(cascadeBlendKeywords, (int)settings.directional.cascadeBlend - 1);

        cmd.EndSample(cmdName);
        ExecuteCommands();
    }

    void RenderPointShadows(int index, int split, int tileSize)
    {
        var light = shadowedOtherLights[index];
        var shadowSettings = new ShadowDrawingSettings(
            cullingResults, light.visibleLightIndex
        // , BatchCullingProjectionType.Perspective     // In Unity 2022
        );
        shadowSettings.useRenderingLayerMaskTest = true;

        // Calculate fixed normal bias
        float texelSize = 2.0f / tileSize;
        float filterSize = texelSize * ((float)settings.other.filterMode + 1.0f);
        float bias = light.normalBias * filterSize * 1.4142136f;

        float tileScale = 1.0f / split;

        for (int i = 0; i < 6; ++i)
        {
            // Calculate fov bias
            float fovBias =
                Mathf.Atan(1.0f + bias + filterSize) * Mathf.Rad2Deg * 2.0f - 90.0f;

            // Calculate view and projection matrices
            cullingResults.ComputePointShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, (CubemapFace)i, fovBias,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            // Filp the geometry faces
            viewMatrix.m11 = -viewMatrix.m11;
            viewMatrix.m12 = -viewMatrix.m12;
            viewMatrix.m13 = -viewMatrix.m13;

            shadowSettings.splitData = splitData;
            cmd.SetViewProjectionMatrices(viewMatrix, projectionMatrix);

            // Set shadow tile
            int tileIndex = index + i;
            var offset = SetTileViewport(tileIndex, split, tileSize);

            // Set shadow drawing parameters
            cmd.SetGlobalDepthBias(0.0f, light.slopeScaleBias);

            ExecuteCommands();

            // Draw shadows
            context.DrawShadows(ref shadowSettings);
            cmd.SetGlobalDepthBias(0.0f, 0.0f);

            SetOtherTileData(tileIndex, offset, tileScale, bias);

            // Calculate shadow matrix
            otherShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,
                                                                  offset, tileScale);
        }
    }

    void RenderSpotShadows(int index, int split, int tileSize)
    {
        var light = shadowedOtherLights[index];
        var shadowSettings = new ShadowDrawingSettings(
            cullingResults, light.visibleLightIndex
        // , BatchCullingProjectionType.Perspective     // In Unity 2022
        );
        shadowSettings.useRenderingLayerMaskTest = true;

        // Calculate view and projection matrices
        cullingResults.ComputeSpotShadowMatricesAndCullingPrimitives(
            light.visibleLightIndex,
            out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
            out ShadowSplitData splitData
        );

        shadowSettings.splitData = splitData;
        cmd.SetViewProjectionMatrices(viewMatrix, projectionMatrix);

        // Set shadow tile
        var offset = SetTileViewport(index, split, tileSize);

        // Set shadow drawing parameters
        cmd.SetGlobalDepthBias(0.0f, light.slopeScaleBias);

        ExecuteCommands();

        // Draw shadows
        context.DrawShadows(ref shadowSettings);
        cmd.SetGlobalDepthBias(0.0f, 0.0f);

        // Calculate fixed normal bias
        float texelSize = 2.0f / (tileSize * projectionMatrix.m00); // World-space texel size
        float filterSize = texelSize * ((float)settings.other.filterMode + 1.0f);
        float bias = light.normalBias * filterSize * 1.4142136f;

        float tileScale = 1.0f / split;
        SetOtherTileData(index, offset, tileScale, bias);

        // Calculate shadow matrix
        otherShadowMatrices[index] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix,
                                                          offset, tileScale);
    }

    void RenderOtherShadows()
    {
        // Use a square render texture for shadow map
        var atlasSize = (int)settings.other.atlasSize;
        atlasSizes.z = atlasSize;
        atlasSizes.w = 1.0f / atlasSize;

        cmd.GetTemporaryRT(otherShadowAtlasId, atlasSize, atlasSize,
                           32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);

        // Instruct the GPU to render to this texture
        cmd.SetRenderTarget(otherShadowAtlasId,
                            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cmd.ClearRenderTarget(true, false, Color.clear);

        // Split shadow atlas
        var tileCount = shadowedOtherLightCount;
        var split = tileCount <= 1 ? 1 : tileCount <= 4 ? 2 : 4;
        var tileSize = atlasSize / split;

        // Render shadows
        cmd.BeginSample(cmdName);
        ExecuteCommands();

        // Turn off clamping, for pancaking isn't appropriate
        cmd.SetGlobalFloat(shadowPancakingId, 0.0f);

        for (int i = 0; i < shadowedOtherLightCount;)
        {
            if (shadowedOtherLights[i].isPoint)
            {
                RenderPointShadows(i, split, tileSize);
                i += 6;
            }
            else
            {
                RenderSpotShadows(i, split, tileSize);
                i += 1;
            }
        }

        // Set shadow matrices and tile data
        cmd.SetGlobalMatrixArray(otherShadowMatricesId, otherShadowMatrices);
        cmd.SetGlobalVectorArray(otherShadowTilesId, otherShadowTiles);

        SetKeywords(otherFilterKeywords, (int)settings.other.filterMode - 1);

        cmd.EndSample(cmdName);
        ExecuteCommands();
    }

    public void Cleanup()
    {
        cmd.ReleaseTemporaryRT(dirShadowAtlasId);
        if (shadowedOtherLightCount > 0)
        {
            cmd.ReleaseTemporaryRT(otherShadowAtlasId);
        }
        ExecuteCommands();
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, float scale)
    {
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }

        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);

        return m;
    }

    void SetKeywords(string[] keywords, int enabledIndex)
    {
        // int enabledIndex = (int)settings.directional.filterMode - 1;
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                cmd.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                cmd.DisableShaderKeyword(keywords[i]);
            }
        }
    }
}