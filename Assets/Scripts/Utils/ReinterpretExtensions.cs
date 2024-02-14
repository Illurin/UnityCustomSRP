using System.Runtime.InteropServices;

public static class ReinterpretExtensions
{
    [StructLayout(LayoutKind.Explicit)]
    struct IntFloat
    {
        [FieldOffset(0)] public int intValue;
        [FieldOffset(0)] public float floatValue;
    }

    // There is no way to directly send an array of integers to the GPU,
    // so we have to reinterpret an int as float a without conversion
    public static float ReinterpretAsFloat(this int value)
    {
        IntFloat converter = default;
        converter.intValue = value;
        return converter.floatValue;
    }
}