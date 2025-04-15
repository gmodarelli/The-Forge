const std = @import("std");
const zf = @import("ze_forge");
const zgpu = zf.IGraphics;
const zgpu_tides = zf.IGraphicsTides;

pub export const D3D12SDKVersion: u32 = 715;
pub export const D3D12SDKPath: [*:0]const u8 = ".\\";

pub fn main() !void {
    var renderer_desc = std.mem.zeroes(zgpu.RendererDesc);
    var renderer: [*c]zgpu.Renderer = null;
    zgpu_tides.initGPUConfigurationEx(renderer_desc.pExtendedSettings);
    defer zgpu_tides.exitGPUConfigurationEx();
    zgpu.initRenderer("ze_forge test", &renderer_desc, &renderer);
    defer zgpu.exitRenderer(renderer);
}
