using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor"),
               cutoffId = Shader.PropertyToID("_Cutoff"),
               metallicId = Shader.PropertyToID("_Metallic"),
               smoothnessId = Shader.PropertyToID("_Smoothness"),
               fresnelId = Shader.PropertyToID("_Fresnel"),
               emissionColorId = Shader.PropertyToID("_EmissionColor");

    static MaterialPropertyBlock block;

    [SerializeField]
    Color baseColor = Color.white;

    [SerializeField, Range(0.0f, 1.0f)]
    float alphaCutoff = 0.5f, metallic = 0.0f, smoothness = 0.5f, fresnel = 0.0f;

    [SerializeField, ColorUsage(false, true)]
    Color emissionColor = Color.black;

    // Invoke in the Unity editor when the component is loaded or changed
    void OnValidate()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
        }
        block.SetColor(baseColorId, baseColor);
        block.SetFloat(cutoffId, alphaCutoff);
        block.SetFloat(metallicId, metallic);
        block.SetFloat(smoothnessId, smoothness);
        block.SetFloat(fresnelId, fresnel);
        block.SetColor(emissionColorId, emissionColor);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }

    // Invoked in builds
    void Awake()
    {
        OnValidate();
    }
}
