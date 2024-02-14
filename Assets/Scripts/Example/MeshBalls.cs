using UnityEngine;
using UnityEngine.Rendering;

public class MeshBalls : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");
    static int metallicId = Shader.PropertyToID("_Metallic");
    static int smoothnessId = Shader.PropertyToID("_Smoothness");

    [SerializeField]
    Mesh mesh = default;

    [SerializeField]
    Material material = default;

    Matrix4x4[] matrices = new Matrix4x4[1023];
    Vector4[] baseColors = new Vector4[1023];
    float[] metallic = new float[1023];
    float[] smoothness = new float[1023];

    MaterialPropertyBlock block;

    // Provide Light probe proxy volume
    [SerializeField]
    LightProbeProxyVolume lightProbeVolume = null;

    void Awake()
    {
        // Get random properties
        for (int i = 0; i < matrices.Length; ++i)
        {
            matrices[i] = Matrix4x4.TRS(
                Random.insideUnitCircle * 10.0f,
                Quaternion.Euler(Random.value * 360.0f, Random.value * 360.0f, Random.value * 360.0f),
                Vector3.one * Random.Range(0.5f, 1.5f)
            );

            baseColors[i] = new Vector4(Random.value, Random.value, Random.value, Random.Range(0.5f, 1.0f));
            metallic[i] = Random.value < 0.25f ? 1f : 0f;
            smoothness[i] = Random.Range(0.05f, 0.95f);
        }
    }

    void Update()
    {
        // Instantiate mesh balls
        if (block == null)
        {
            block = new MaterialPropertyBlock();
            block.SetVectorArray(baseColorId, baseColors);
            block.SetFloatArray(metallicId, metallic);
            block.SetFloatArray(smoothnessId, smoothness);
        }

        if (!lightProbeVolume)
        {
            // Generate interpolated light probes
            var positions = new Vector3[1023];
            for (int i = 0; i < matrices.Length; ++i)
            {
                positions[i] = matrices[i].GetColumn(3);
            }

            var lightProbes = new SphericalHarmonicsL2[1023];
            var occlusionProbes = new Vector4[1023];
            LightProbes.CalculateInterpolatedLightAndOcclusionProbes(
                positions, lightProbes, occlusionProbes
            );
            block.CopySHCoefficientArraysFrom(lightProbes);
            block.CopyProbeOcclusionArrayFrom(occlusionProbes);
        }

        // Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block);
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block,
                                   ShadowCastingMode.On, true, 0, null,
                                   lightProbeVolume ? LightProbeUsage.UseProxyVolume : 
                                                      LightProbeUsage.CustomProvided,
                                   lightProbeVolume);
    }
}