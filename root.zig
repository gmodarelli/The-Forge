const std = @import("std");
const IGraphics = @import("Common_3/Graphics/Interfaces/IGraphics.zig");
const IGraphicsTides = @import("Common_3/Graphics/Interfaces/IGraphicsTides.zig");
// pub const IRay = @import("Common_3/Graphics/Interfaces/IRay.zig");

pub export const D3D12SDKVersion: u32 = 715;
pub export const D3D12SDKPath: [*:0]const u8 = ".\\";

pub const GpuDesc = struct {
    graphics_root_signature_path: []const u8,
    compute_root_signature_path: []const u8,
};

pub const frames_in_flight_count: u32 = 2;

const Gpu = struct {
    allocator: std.mem.Allocator = undefined,

    renderer: [*c]IGraphics.Renderer = null,
    graphics_queue: [*c]IGraphics.Queue = null,
    cmd_pools: [frames_in_flight_count][*c]IGraphics.CmdPool = undefined,
    cmds: [frames_in_flight_count][*c]IGraphics.Cmd = undefined,
    fences: [frames_in_flight_count][*c]IGraphics.Fence = undefined,
    semaphores: [frames_in_flight_count][*c]IGraphics.Semaphore = undefined,

    image_acquired_semaphore: [*c]IGraphics.Semaphore = null,
    // swapchain: [*c]IGraphics.SwapChain = null,

    frame_started: bool = false,
    frame_index: u32 = 0,
};

var gpu: Gpu = undefined;

pub fn initializeGpu(gpu_desc: GpuDesc, allocator: std.mem.Allocator) !void {
    gpu.allocator = allocator;

    // Initialize renderer
    var renderer_desc = std.mem.zeroes(IGraphics.RendererDesc);
    renderer_desc.mShaderTarget = .SHADER_TARGET_6_8;
    IGraphicsTides.initGPUConfigurationEx(renderer_desc.pExtendedSettings);
    IGraphics.initRenderer("ze_forge test", &renderer_desc, &gpu.renderer);

    // Initialize graphics queue
    var queue_desc = std.mem.zeroes(IGraphics.QueueDesc);
    queue_desc.mType = .QUEUE_TYPE_GRAPHICS;
    queue_desc.mFlag = .QUEUE_FLAG_NONE;
    IGraphics.initQueue(gpu.renderer, &queue_desc, &gpu.graphics_queue);

    // Initialize command pools, commands and sync primitives
    var cmd_pool_desc = std.mem.zeroes(IGraphics.CmdPoolDesc);
    cmd_pool_desc.mTransient = false;
    cmd_pool_desc.pQueue = gpu.graphics_queue;

    for (0..frames_in_flight_count) |frame_index| {
        IGraphics.initCmdPool(gpu.renderer, &cmd_pool_desc, &gpu.cmd_pools[frame_index]);
        var cmd_desc = std.mem.zeroes(IGraphics.CmdDesc);
        cmd_desc.pPool = gpu.cmd_pools[frame_index];
        IGraphics.initCmd(gpu.renderer, &cmd_desc, &gpu.cmds[frame_index]);
        IGraphics.initFence(gpu.renderer, &gpu.fences[frame_index]);
        IGraphics.initSemaphore(gpu.renderer, &gpu.semaphores[frame_index]);
    }

    // Initialize image acquired semaphore
    IGraphics.initSemaphore(gpu.renderer, &gpu.image_acquired_semaphore);

    // Initialize default root signatures
    if (!IGraphicsTides.loadDefaultRootSignatures(gpu.renderer, @ptrCast(gpu_desc.graphics_root_signature_path), @ptrCast(gpu_desc.compute_root_signature_path))) {
        @panic("Failed to load default root signatures");
    }

    gpu.frame_started = false;
    gpu.frame_index = 0;
}

pub fn shutdownGpu() void {
    IGraphicsTides.releaseDefaultRootSignatures(gpu.renderer);
    IGraphics.exitSemaphore(gpu.renderer, gpu.image_acquired_semaphore);

    for (0..frames_in_flight_count) |frame_index| {
        IGraphics.exitCmdPool(gpu.renderer, gpu.cmd_pools[frame_index]);
        IGraphics.exitCmd(gpu.renderer, gpu.cmds[frame_index]);
        IGraphics.exitFence(gpu.renderer, gpu.fences[frame_index]);
        IGraphics.exitSemaphore(gpu.renderer, gpu.semaphores[frame_index]);
    }

    IGraphics.exitQueue(gpu.renderer, gpu.graphics_queue);
    IGraphicsTides.exitGPUConfigurationEx();
    IGraphics.exitRenderer(gpu.renderer);
}