const std = @import("std");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");

pub fn main() !void {
    // Create a window
    zglfw.init() catch unreachable;
    defer zglfw.terminate();

    zglfw.windowHint(.client_api, .no_api);
    const window = zglfw.Window.create(1920, 1080, "Ze-Forge Test", null) catch unreachable;
    defer zglfw.Window.destroy(window);

    const gpu_desc = zf.GpuDesc{
        .graphics_root_signature_path = "shaders/GraphicsRootSignature.rs",
        .compute_root_signature_path = "shaders/ComputeRootSignature.rs",
        .hwnd = zglfw.getWin32Window(window).?,
    };
    zf.initializeGpu(gpu_desc, std.heap.page_allocator) catch unreachable;
    defer zf.shutdownGpu();

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        // render your things here
        _ = zf.frameStart();
        zf.frameSubmit();
    }
}
