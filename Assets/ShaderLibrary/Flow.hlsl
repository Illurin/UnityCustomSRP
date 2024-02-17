#ifndef CUSTOM_FLOW_INCLUDED
#define CUSTOM_FLOW_INCLUDED

float3 FlowUVW(float2 uv, float2 flowVector, float2 jump,
               float flowOffset, float tiling, float time, bool flowB)
{
    // Use phase offset to blend two waves
    float phaseOffset = flowB ? 0.5f : 0.0f;

    // Only using the fractional part of the time for the animation
    float progress = frac(time + phaseOffset);

    float3 uvw;

    // Distort UV with flow direction
    uvw.xy = uv - flowVector * (progress + flowOffset);
    uvw.xy *= tiling;
    uvw.xy += phaseOffset;

    // Add jump offset to the UV, multiplied by the integer portion of the time
    uvw.xy += (time - progress) * jump;

    // Blend weight with sawtooth wave
    uvw.z = 1.0f - abs(1.0f - 2.0f * progress);

    return uvw;
}

float3 DirectionalFlowUVW(float2 uv, float2 flowVector, float tiling, float time)
{
    // Use 2D rotation matrix to rotate the texture
    float2 dir = normalize(flowVector.xy);
	uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);

    // Flow through time
    uv.y -= time;
    return float3(uv * tiling, 1.0f);
}

#endif