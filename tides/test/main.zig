const std = @import("std");
const zf = @import("ze_forge");
const zgpu = zf.IGraphics;
const zgpu_tides = zf.IGraphicsTides;

pub export const D3D12SDKVersion: u32 = 715;
pub export const D3D12SDKPath: [*:0]const u8 = ".\\";

pub const Gpu = struct {
    pub const frames_in_flight_count: u32 = 2;
    allocator: std.mem.Allocator = undefined,

    renderer: [*c]zgpu.Renderer = null,
    graphics_queue: [*c]zgpu.Queue = null,
    cmd_pools: [frames_in_flight_count][*c]zgpu.CmdPool = undefined,
    cmds: [frames_in_flight_count][*c]zgpu.Cmd = undefined,
    fences: [frames_in_flight_count][*c]zgpu.Fence = undefined,
    semaphores: [frames_in_flight_count][*c]zgpu.Semaphore = undefined,

    // image_acquired_semaphore: [*c]zgpu.Semaphore = null,
    // swapchain: [*c]zgpu.SwapChain = null,

    frame_started: bool = false,
    frame_index: u32 = 0,

    pub fn init(self: *Gpu, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;

        // Initialize renderer
        var renderer_desc = std.mem.zeroes(zgpu.RendererDesc);
        renderer_desc.mShaderTarget = .SHADER_TARGET_6_8;
        zgpu_tides.initGPUConfigurationEx(renderer_desc.pExtendedSettings);
        zgpu.initRenderer("ze_forge test", &renderer_desc, &self.renderer);

        // Initialize graphics queue
        var queue_desc = std.mem.zeroes(zgpu.QueueDesc);
        queue_desc.mType = .QUEUE_TYPE_GRAPHICS;
        queue_desc.mFlag = .QUEUE_FLAG_NONE;
        zgpu.initQueue(self.renderer, &queue_desc, &self.graphics_queue);

        // Initialize command pools, commands and sync primitives
        var cmd_pool_desc = std.mem.zeroes(zgpu.CmdPoolDesc);
        cmd_pool_desc.mTransient = false;
        cmd_pool_desc.pQueue = self.graphics_queue;

        for (0..Gpu.frames_in_flight_count) |frame_index| {
            zgpu.initCmdPool(self.renderer, &cmd_pool_desc, &self.cmd_pools[frame_index]);
            var cmd_desc = std.mem.zeroes(zgpu.CmdDesc);
            cmd_desc.pPool = self.cmd_pools[frame_index];
            zgpu.initCmd(self.renderer, &cmd_desc, &self.cmds[frame_index]);
            zgpu.initFence(self.renderer, &self.fences[frame_index]);
            zgpu.initSemaphore(self.renderer, &self.semaphores[frame_index]);
        }

        self.frame_started = false;
        self.frame_index = 0;
    }

    pub fn exit(self: *Gpu) void {
        for (0..Gpu.frames_in_flight_count) |frame_index| {
            zgpu.exitCmdPool(self.renderer, self.cmd_pools[frame_index]);
            zgpu.exitCmd(self.renderer, self.cmds[frame_index]);
            zgpu.exitFence(self.renderer, self.fences[frame_index]);
            zgpu.exitSemaphore(self.renderer, self.semaphores[frame_index]);
        }

        zgpu.exitQueue(self.renderer, self.graphics_queue);
        zgpu_tides.exitGPUConfigurationEx();
        zgpu.exitRenderer(self.renderer);
    }
};

pub fn main() !void {
    var gpu = Gpu{};
    gpu.init(std.heap.page_allocator) catch unreachable;
    defer gpu.exit();
}
