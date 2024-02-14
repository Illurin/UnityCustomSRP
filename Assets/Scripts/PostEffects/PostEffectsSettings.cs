using System;
using UnityEngine;

[CreateAssetMenu(menuName = "Rendering/Custom Post Effects Settings")]
public class PostEffectsSettings : ScriptableObject
{
    [SerializeField]
    Shader shader = default;

    // Bloom configuration
    [System.Serializable]
    public struct BloomSettings
    {
        public bool ignoreRenderScale;

        public enum Mode { Additive, Scattering }

        [Range(0, 16)]
        public int maxIterations;

        [Min(1)]
        public int downscaleLimit;

        public bool bicubicUpsampling;

        [Min(0.0f)]
        public float intensity;

        [Min(0.0f)]
        public float threshold;

        [Range(0.0f, 1.0f)]
        public float thresholdKnee;

        public bool fadeFireflies;

        public Mode mode;

        [Range(0.05f, 0.95f)]
        public float scatter;
    }

    [SerializeField]
    BloomSettings bloom = new BloomSettings
    { maxIterations = 3, downscaleLimit = 1, bicubicUpsampling = true,
      intensity = 1.0f, threshold = 0.5f, thresholdKnee = 0.5f, fadeFireflies = true,
      mode = BloomSettings.Mode.Scattering, scatter = 0.7f };

    public BloomSettings Bloom => bloom;

    // Tone mapping configuration
    [System.Serializable]
    public struct ToneMappingSettings
    {
        public enum Mode { None, ACES, Neutral, Reinhard }

        public Mode mode;
    }

    [SerializeField]
    ToneMappingSettings toneMapping = default;

    public ToneMappingSettings ToneMapping => toneMapping;

    // Color adjustments configuration
    [Serializable]
    public struct ColorAdjustmentsSettings
    {
        public float postExposure;

        [Range(-100.0f, 100.0f)]
        public float contrast;

        [ColorUsage(false, true)]
        public Color colorFilter;

        [Range(-180.0f, 180.0f)]
        public float hueShift;

        [Range(-100.0f, 100.0f)]
        public float saturation;
    }

    [SerializeField]
    ColorAdjustmentsSettings colorAdjustments = new ColorAdjustmentsSettings
    { colorFilter = Color.white };

    public ColorAdjustmentsSettings ColorAdjustments => colorAdjustments;

    // White balance configuration
    [Serializable]
    public struct WhiteBalanceSettings
    {
        [Range(-100.0f, 100.0f)]
        public float temperature, tint;
    }

    [SerializeField]
    WhiteBalanceSettings whiteBalance = default;

    public WhiteBalanceSettings WhiteBalance => whiteBalance;

    // Split toning configuration
    [Serializable]
    public struct SplitToningSettings
    {
        [ColorUsage(false)]
        public Color shadows, highlights;

        [Range(-100.0f, 100.0f)]
        public float balance;
    }

    [SerializeField]
    SplitToningSettings splitToning = new SplitToningSettings
    { shadows = Color.gray, highlights = Color.gray };

    public SplitToningSettings SplitToning => splitToning;

    // Channel mixer configuration
    [Serializable]
    public struct ChannelMixerSettings
    {
        public Vector3 red, green, blue;
    }

    [SerializeField]
    ChannelMixerSettings channelMixer = new ChannelMixerSettings
    { red = Vector3.right, green = Vector3.up, blue = Vector3.forward };

    public ChannelMixerSettings ChannelMixer => channelMixer;

    // Shadows midtones highlights configuration
    [Serializable]
    public struct ShadowsMidtonesHighlightsSettings
    {
        [ColorUsage(false, true)]
        public Color shadows, midtones, highlights;

        [Range(0.0f, 2.0f)]
        public float shadowsStart, shadowsEnd, highlightsStart, highLightsEnd;
    }

    [SerializeField]
    ShadowsMidtonesHighlightsSettings
        shadowsMidtonesHighlights = new ShadowsMidtonesHighlightsSettings
        { shadows = Color.white, midtones = Color.white, highlights = Color.white,
          shadowsEnd = 0.3f, highlightsStart = 0.55f, highLightsEnd = 1.0f };

    public ShadowsMidtonesHighlightsSettings ShadowsMidtonesHighlights =>
        shadowsMidtonesHighlights;

    // Create a hidden material for rendering
    [System.NonSerialized]
    Material material;

    public Material Material
    {
        get
        {
            if (material == null && shader != null)
            {
                material = new Material(shader);
                material.hideFlags = HideFlags.HideAndDontSave;
            }
            return material;
        }
    }
}