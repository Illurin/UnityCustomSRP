using System;
using UnityEngine;

[Serializable]
public struct FramebufferSettings
{
    public bool allowHDR;
    public bool copyColor, copyColorReflection;
    public bool copyDepth, copyDepthReflections;

    [Range(0.1f, 2.0f)]
    public float renderScale;

    public enum BicubicRescalingMode
    {
        Off,
        UpOnly,
        UpAndDown
    }

    public BicubicRescalingMode bicubicRescaling;
    [Serializable]
    public struct FXAA
    {
        public bool enabled;

        [Range(0.0312f, 0.0833f)]
        public float fixedThreshold;

        [Range(0.063f, 0.333f)]
        public float relativeThreshold;

        // Choose the amount of sub-pixel aliasing removal.
        // This can effect sharpness.
        //   1.00 - upper limit (softer)
        //   0.75 - default amount of filtering
        //   0.50 - lower limit (sharper, less sub-pixel aliasing removal)
        //   0.25 - almost off
        //   0.00 - completely off

        [Range(0.0f, 1.0f)]
        public float subpixelBlending;

        public enum Quality { Low, Medium, High }

        public Quality quality;
    }

    public FXAA fxaa;
}