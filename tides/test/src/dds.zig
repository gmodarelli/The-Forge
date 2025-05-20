const std = @import("std");
const TinyImageFormat = @import("ze_forge").TinyImageFormat;

pub const DdsImage = struct {
    width: u32,
    height: u32,
    depth: u32,
    mip_levels: u32,
    array_size: u32,
    format: TinyImageFormat,
    data: []u8,
};

pub fn loadDdsImage(file_path: []const u8, allocator: std.mem.Allocator) !DdsImage {
    var dds_image: DdsImage = undefined;

    var file = std.fs.cwd().openFile(file_path, .{}) catch unreachable;
    defer file.close();

    const metadata = file.metadata() catch unreachable;
    const file_size = metadata.size();
    std.debug.assert(file_size > @sizeOf(u32) + @sizeOf(DDS_HEADER));

    // Read all file
    const file_data = allocator.alloc(u8, file_size) catch unreachable;
    defer allocator.free(file_data);
    const read_bytes = file.readAll(file_data) catch unreachable;
    std.debug.assert(read_bytes == file_size);

    // Create a stream
    var stream = std.io.StreamSource{ .buffer = std.io.fixedBufferStream(file_data) };
    var reader = stream.reader();

    // Check DDS_MAGIC
    const magic = reader.readInt(u32, .little) catch unreachable;
    std.debug.assert(magic == DDS_MAGIC);

    // Extract DDS_HEADER
    const header = reader.readStruct(DDS_HEADER) catch unreachable;
    std.debug.assert(header.dwSize == @as(u32, @intCast(@sizeOf(DDS_HEADER))));
    std.debug.assert(header.ddspf.dwSize == @as(u32, @intCast(@sizeOf(DDS_PIXELFORMAT))));

    // Esure DX10 extension
    std.debug.assert((header.ddspf.dwFlags & DDS_FOURCC) == DDS_FOURCC);
    const dxt10 = reader.readStruct(DDS_HEADER_DXT10) catch unreachable;

    const data_size = file_data.len - (@sizeOf(u32) + @sizeOf(DDS_HEADER) + @sizeOf(DDS_HEADER_DXT10));
    dds_image.data = allocator.alloc(u8, data_size) catch unreachable;
    reader.readNoEof(dds_image.data) catch unreachable;

    dds_image.width = @intCast(header.dwWidth);
    dds_image.height = @intCast(header.dwHeight);
    dds_image.mip_levels = if (header.dwMipMapCount == 0) 1 else header.dwMipMapCount;
    // NOTE: We don't support texture arrays for now
    std.debug.assert(dxt10.arraySize == 1);
    dds_image.array_size = @intCast(dxt10.arraySize);
    // NOTE: We only support TEXTURE2D for now
    std.debug.assert(dxt10.resourceDimension == 3);
    dds_image.depth = 1;

    dds_image.format = dxgiFormatToTinyImageFormat(dxt10.dxgiFormat);
    std.debug.assert(dds_image.format != .UNDEFINED);

    return dds_image;
}

const DDS_HEADER_FLAGS_TEXTURE: u32 = 0x00001007; // DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT
const DDS_HEADER_FLAGS_MIPMAP: u32 = 0x00020000; // DDSD_MIPMAPCOUNT
const DDS_HEADER_FLAGS_VOLUME: u32 = 0x00800000; // DDSD_DEPTH
const DDS_HEADER_FLAGS_PITCH: u32 = 0x00000008; // DDSD_PITCH
const DDS_HEADER_FLAGS_LINEARSIZE: u32 = 0x00080000; // DDSD_LINEARSIZE

const DDS_HEIGHT: u32 = 0x00000002; // DDSD_HEIGHT
const DDS_WIDTH: u32 = 0x00000004; // DDSD_WIDTH

const DDS_SURFACE_FLAGS_TEXTURE: u32 = 0x00001000; // DDSCAPS_TEXTURE
const DDS_SURFACE_FLAGS_MIPMAP: u32 = 0x00400008; // DDSCAPS_COMPLEX | DDSCAPS_MIPMAP
const DDS_SURFACE_FLAGS_CUBEMAP: u32 = 0x00000008; // DDSCAPS_COMPLEX

const DDS_CUBEMAP_POSITIVEX: u32 = 0x00000600; // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_POSITIVEX
const DDS_CUBEMAP_NEGATIVEX: u32 = 0x00000a00; // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_NEGATIVEX
const DDS_CUBEMAP_POSITIVEY: u32 = 0x00001200; // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_POSITIVEY
const DDS_CUBEMAP_NEGATIVEY: u32 = 0x00002200; // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_NEGATIVEY
const DDS_CUBEMAP_POSITIVEZ: u32 = 0x00004200; // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_POSITIVEZ
const DDS_CUBEMAP_NEGATIVEZ: u32 = 0x00008200; // DDSCAPS2_CUBEMAP | DDSCAPS2_CUBEMAP_NEGATIVEZ

const DDS_CUBEMAP_ALLFACES: u32 = (DDS_CUBEMAP_POSITIVEX | DDS_CUBEMAP_NEGATIVEX | DDS_CUBEMAP_POSITIVEY | DDS_CUBEMAP_NEGATIVEY | DDS_CUBEMAP_POSITIVEZ | DDS_CUBEMAP_NEGATIVEZ);

const DDS_CUBEMAP: u32 = 0x00000200; // DDSCAPS2_CUBEMAP

const DDS_FLAGS_VOLUME: u32 = 0x00200000; // DDSCAPS2_VOLUME

const DDS_MISC_FLAGS2_ALPHA_MODE_MASK: u32 = 0x7;

const DDS_MAGIC: u32 = 0x20534444; // "DDS "

const DDS_FOURCC: u32 = 0x00000004; // DDPF_FOURCC
const DDS_RGB: u32 = 0x00000040; // DDPF_RGB
const DDS_RGBA: u32 = 0x00000041; // DDPF_RGB | DDPF_ALPHAPIXELS
const DDS_LUMINANCE: u32 = 0x00020000; // DDPF_LUMINANCE
const DDS_LUMINANCEA: u32 = 0x00020001; // DDPF_LUMINANCE | DDPF_ALPHAPIXELS
const DDS_ALPHA: u32 = 0x00000002; // DDPF_ALPHA
const DDS_PAL8: u32 = 0x00000020; // DDPF_PALETTEINDEXED8
const DDS_BUMPDUDV: u32 = 0x00080000; // DDPF_BUMPDUDV

inline fn makeFourCC(ch0: u8, ch1: u8, ch2: u8, ch3: u8) u32 {
    return (@as(u32, @intCast(ch0))) | (@as(u32, @intCast(ch1)) << 8) | (@as(u32, @intCast(ch2)) << 16) | (@as(u32, @intCast(ch3)) << 24);
}

inline fn isBitMask(pixelFormat: DDS_PIXELFORMAT, r: u32, g: u32, b: u32, a: u32) bool {
    return (pixelFormat.dwRBitMask == r and pixelFormat.dwGBitMask == g and pixelFormat.dwBBitMask == b and pixelFormat.dwABitMask == a);
}

const DDS_ALPHA_MODE = enum(u32) {
    unknown,
    straight,
    premultiplied,
    @"opaque",
    custom,
};

const DDS_PIXELFORMAT = extern struct {
    dwSize: u32,
    dwFlags: u32,
    dwFourCC: u32,
    dwRGBBitCount: u32,
    dwRBitMask: u32,
    dwGBitMask: u32,
    dwBBitMask: u32,
    dwABitMask: u32,
};

const DDS_HEADER = extern struct {
    dwSize: u32,
    dwFlags: u32,
    dwHeight: u32,
    dwWidth: u32,
    dwPitchOrLinearSize: u32,
    dwDepth: u32, // only if DDS_HEADER_FLAGS_VOLUME is set in dwFlags
    dwMipMapCount: u32,
    dwReserved1: [11]u32,
    ddspf: DDS_PIXELFORMAT,
    dwCaps: u32,
    dwCaps2: u32,
    dwCaps3: u32,
    dwCaps4: u32,
    dwReserved2: u32,
};

pub const DDS_HEADER_DXT10 = extern struct {
    dxgiFormat: DXGI_FORMAT,
    resourceDimension: u32,
    miscFlag: u32, // see DDS_RESOURCE_MISC_FLAG
    arraySize: u32,
    miscFlags2: u32, // see DDS_MISC_FLAGS2
};

fn dxgiFormatToTinyImageFormat(dxgiFormat: DXGI_FORMAT) TinyImageFormat {
    // NOTE: We only support loading BC-encoded DDS textures

    return switch (dxgiFormat) {
        .BC1_UNORM => .DXBC1_RGBA_UNORM,
        .BC1_UNORM_SRGB => .DXBC1_RGBA_SRGB,
        .BC2_UNORM => .DXBC2_UNORM,
        .BC2_UNORM_SRGB => .DXBC2_SRGB,
        .BC3_UNORM => .DXBC3_UNORM,
        .BC3_UNORM_SRGB => .DXBC3_SRGB,
        .BC4_UNORM => .DXBC4_UNORM,
        .BC4_SNORM => .DXBC4_SNORM,
        .BC5_UNORM => .DXBC5_UNORM,
        .BC5_SNORM => .DXBC5_SNORM,
        .BC6H_UF16 => .DXBC6H_UFLOAT,
        .BC6H_SF16 => .DXBC6H_SFLOAT,
        .BC7_UNORM => .DXBC7_UNORM,
        .BC7_UNORM_SRGB => .DXBC7_SRGB,
        else => .UNDEFINED,
    };
}

const DXGI_FORMAT = enum(u32) {
    UNKNOWN = 0,
    R32G32B32A32_TYPELESS = 1,
    R32G32B32A32_FLOAT = 2,
    R32G32B32A32_UINT = 3,
    R32G32B32A32_SINT = 4,
    R32G32B32_TYPELESS = 5,
    R32G32B32_FLOAT = 6,
    R32G32B32_UINT = 7,
    R32G32B32_SINT = 8,
    R16G16B16A16_TYPELESS = 9,
    R16G16B16A16_FLOAT = 10,
    R16G16B16A16_UNORM = 11,
    R16G16B16A16_UINT = 12,
    R16G16B16A16_SNORM = 13,
    R16G16B16A16_SINT = 14,
    R32G32_TYPELESS = 15,
    R32G32_FLOAT = 16,
    R32G32_UINT = 17,
    R32G32_SINT = 18,
    R32G8X24_TYPELESS = 19,
    D32_FLOAT_S8X24_UINT = 20,
    R32_FLOAT_X8X24_TYPELESS = 21,
    X32_TYPELESS_G8X24_UINT = 22,
    R10G10B10A2_TYPELESS = 23,
    R10G10B10A2_UNORM = 24,
    R10G10B10A2_UINT = 25,
    R11G11B10_FLOAT = 26,
    R8G8B8A8_TYPELESS = 27,
    R8G8B8A8_UNORM = 28,
    R8G8B8A8_UNORM_SRGB = 29,
    R8G8B8A8_UINT = 30,
    R8G8B8A8_SNORM = 31,
    R8G8B8A8_SINT = 32,
    R16G16_TYPELESS = 33,
    R16G16_FLOAT = 34,
    R16G16_UNORM = 35,
    R16G16_UINT = 36,
    R16G16_SNORM = 37,
    R16G16_SINT = 38,
    R32_TYPELESS = 39,
    D32_FLOAT = 40,
    R32_FLOAT = 41,
    R32_UINT = 42,
    R32_SINT = 43,
    R24G8_TYPELESS = 44,
    D24_UNORM_S8_UINT = 45,
    R24_UNORM_X8_TYPELESS = 46,
    X24_TYPELESS_G8_UINT = 47,
    R8G8_TYPELESS = 48,
    R8G8_UNORM = 49,
    R8G8_UINT = 50,
    R8G8_SNORM = 51,
    R8G8_SINT = 52,
    R16_TYPELESS = 53,
    R16_FLOAT = 54,
    D16_UNORM = 55,
    R16_UNORM = 56,
    R16_UINT = 57,
    R16_SNORM = 58,
    R16_SINT = 59,
    R8_TYPELESS = 60,
    R8_UNORM = 61,
    R8_UINT = 62,
    R8_SNORM = 63,
    R8_SINT = 64,
    A8_UNORM = 65,
    R1_UNORM = 66,
    R9G9B9E5_SHAREDEXP = 67,
    R8G8_B8G8_UNORM = 68,
    G8R8_G8B8_UNORM = 69,
    BC1_TYPELESS = 70,
    BC1_UNORM = 71,
    BC1_UNORM_SRGB = 72,
    BC2_TYPELESS = 73,
    BC2_UNORM = 74,
    BC2_UNORM_SRGB = 75,
    BC3_TYPELESS = 76,
    BC3_UNORM = 77,
    BC3_UNORM_SRGB = 78,
    BC4_TYPELESS = 79,
    BC4_UNORM = 80,
    BC4_SNORM = 81,
    BC5_TYPELESS = 82,
    BC5_UNORM = 83,
    BC5_SNORM = 84,
    B5G6R5_UNORM = 85,
    B5G5R5A1_UNORM = 86,
    B8G8R8A8_UNORM = 87,
    B8G8R8X8_UNORM = 88,
    R10G10B10_XR_BIAS_A2_UNORM = 89,
    B8G8R8A8_TYPELESS = 90,
    B8G8R8A8_UNORM_SRGB = 91,
    B8G8R8X8_TYPELESS = 92,
    B8G8R8X8_UNORM_SRGB = 93,
    BC6H_TYPELESS = 94,
    BC6H_UF16 = 95,
    BC6H_SF16 = 96,
    BC7_TYPELESS = 97,
    BC7_UNORM = 98,
    BC7_UNORM_SRGB = 99,
    AYUV = 100,
    Y410 = 101,
    Y416 = 102,
    NV12 = 103,
    P010 = 104,
    P016 = 105,
    @"420_OPAQUE" = 106,
    YUY2 = 107,
    Y210 = 108,
    Y216 = 109,
    NV11 = 110,
    AI44 = 111,
    IA44 = 112,
    P8 = 113,
    A8P8 = 114,
    B4G4R4A4_UNORM = 115,
    P208 = 130,
    V208 = 131,
    V408 = 132,
    SAMPLER_FEEDBACK_MIN_MIP_OPAQUE,
    SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE,
    D3DFMT_R8G8B8, // Note: you will need to handle conversion of this legacy format yourself
    FORCE_DWORD = 0xffffffff
};