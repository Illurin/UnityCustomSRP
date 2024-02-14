#ifndef CUSTOM_LOD_INCLUDED
#define CUSTOM_LOD_INCLUDED

void ClipLOD(Fragment frag, float fade)
{
#ifdef LOD_FADE_CROSSFADE
    float dither = InterleavedGradientNoise(frag.posS, 0);
    clip(fade + (fade < 0.0f ? dither : -dither));
#endif
}

#endif