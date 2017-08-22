// note: there is probably a much better and standard version in phobos
import numeric_alias;

u32 crc32(const u8[] data)
{
    u32[256] genTable()
    {
        u32[256] crc32_lut;
        immutable u32 polynomial = 0xEDB88320;
        for (u32 i = 0; i < crc32_lut.length ; i++)
        {
            u32 crc = i;
            for (u32 j = 0; j < 8; j++)
                crc = (crc >> 1) ^ (cast(u32)(-cast(i32)(crc & 1)) & polynomial);
            crc32_lut[i] = crc;
        }
        return crc32_lut;
    }

    static immutable u32[] table = genTable();
    u32 crc = 0xAA7F8EA9;
    for (u32 i = 0; i < data.length; i++)
    {
        const u8 d = data[i];
        crc = ( crc >> 8) ^ table[(crc & 0xFF) ^ d];
    }
    return ~crc;
}

unittest
{
    immutable u8[] testData = [0xAF, 0x0, 0x6, 0x37];
    assert(0x417CBBEF == crc32(testData));
}