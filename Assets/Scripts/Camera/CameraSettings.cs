using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
public class CameraSettings
{
    [Serializable]
    public struct FinalBlendMode
    {
        public BlendMode source, destination;
    }

    public enum RenderScaleMode
    {
        Inherit,
        Multiply,
        Override
    }

    public RenderScaleMode renderScaleMode = RenderScaleMode.Inherit;

    [Range(0.1f, 2.0f)]
    public float renderScale = 1.0f;
    public const float renderScaleMin = 0.1f, renderScaleMax = 2.0f;

    public bool copyColor = true;
    public bool copyDepth = true;

    [RenderingLayerMaskField]
    public int renderingLayerMask = -1;
    public bool maskLights = false;

    public bool overridePostEffects = false;
    public PostEffectsSettings postFXSettings = default;

    public bool allowFXAA = false;
    public bool keepAlpha = false;

    public FinalBlendMode finalBlendMode = new FinalBlendMode
    {
        source = BlendMode.One,
        destination = BlendMode.Zero
    };

    // Give a public method that has a render scale parameter and return the final scale
    public float GetRenderScale(float scale)
    {
        return
            renderScaleMode == RenderScaleMode.Inherit ? scale :
            renderScaleMode == RenderScaleMode.Override ? renderScale :
            scale * renderScale;
    }
}