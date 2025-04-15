const std = @import("std");
const zf = @import("ze_forge");

pub fn main() !void {
    const gpu_desc = zf.GpuDesc{
        .graphics_root_signature_path = "shaders/GraphicsRootSignature.rs",
        .compute_root_signature_path = "shaders/ComputeRootSignature.rs",
    };
    zf.initializeGpu(gpu_desc, std.heap.page_allocator) catch unreachable;
    defer zf.shutdownGpu();
}
