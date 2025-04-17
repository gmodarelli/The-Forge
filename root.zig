const std = @import("std");
const IGraphics = @import("Common_3/Graphics/Interfaces/IGraphics.zig");
const IGraphicsTides = @import("Common_3/Graphics/Interfaces/IGraphicsTides.zig");
// pub const IRay = @import("Common_3/Graphics/Interfaces/IRay.zig");

const Pool = @import("zpool").Pool;

pub export const D3D12SDKVersion: u32 = 715;
pub export const D3D12SDKPath: [*:0]const u8 = ".\\";

pub const GpuDesc = struct {
    graphics_root_signature_path: []const u8,
    compute_root_signature_path: []const u8,
    hwnd: std.os.windows.HWND,
};

pub const ShaderStageLoadDesc = struct {
    path: []const u8,
    entry: []const u8,
};

pub const ShaderLoadDesc = struct {
    vertex: ?ShaderStageLoadDesc,
    pixel: ?ShaderStageLoadDesc,
    compute: ?ShaderStageLoadDesc,
};

const ShaderPool = Pool(8, 8, [*c]IGraphics.Shader, struct {
    ptr: [*c]IGraphics.Shader,
    // TODO: Store BinaryShaderDesc to allow for shader recompilation
});
pub const ShaderHandle = ShaderPool.Handle;

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
    swap_chain: [*c]IGraphics.SwapChain = null,

    linear_repeat_sampler: [*c]IGraphics.Sampler = null,
    linear_clamp_sampler: [*c]IGraphics.Sampler = null,

    frame_started: bool = false,
    frame_index: u32 = 0,

    hwnd: std.os.windows.HWND,

    // Resources
    shaders: ShaderPool = undefined,
};

var gpu: Gpu = undefined;

pub fn initializeGpu(gpu_desc: GpuDesc, allocator: std.mem.Allocator) !void {
    gpu.allocator = allocator;

    gpu.shaders = ShaderPool.initMaxCapacity(gpu.allocator) catch unreachable;

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

    // Static samplers
    var sampler_desc = std.mem.zeroes(IGraphics.SamplerDesc);
    sampler_desc.mMinFilter = IGraphics.FilterType.FILTER_LINEAR;
    sampler_desc.mMagFilter = IGraphics.FilterType.FILTER_LINEAR;
    sampler_desc.mMipMapMode = IGraphics.MipMapMode.MIPMAP_MODE_LINEAR;
    sampler_desc.mAddressU = IGraphics.AddressMode.ADDRESS_MODE_REPEAT;
    sampler_desc.mAddressV = IGraphics.AddressMode.ADDRESS_MODE_REPEAT;
    sampler_desc.mAddressW = IGraphics.AddressMode.ADDRESS_MODE_REPEAT;
    IGraphics.addSampler(gpu.renderer, &sampler_desc, &gpu.linear_repeat_sampler);

    sampler_desc.mAddressW = IGraphics.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_desc.mAddressV = IGraphics.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_desc.mAddressU = IGraphics.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
    IGraphics.addSampler(gpu.renderer, &sampler_desc, &gpu.linear_clamp_sampler);

    gpu.frame_started = false;
    gpu.frame_index = 0;

    gpu.hwnd = gpu_desc.hwnd;

    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .RESIZE = true, .RENDERTARGET = true } };
    onLoad(reload_desc);
}

pub fn shutdownGpu() void {
    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .RESIZE = true, .RENDERTARGET = true } };
    onUnload(reload_desc);

    gpu.shaders.deinit();

    IGraphics.removeSampler(gpu.renderer, gpu.linear_clamp_sampler);
    IGraphics.removeSampler(gpu.renderer, gpu.linear_repeat_sampler);

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

pub fn frameStart() u32 {
    std.debug.assert(!gpu.frame_started);
    gpu.frame_started = true;

    var frame_fence = gpu.fences[gpu.frame_index];
    var fence_status: IGraphics.FenceStatus = undefined;
    IGraphics.getFenceStatus(gpu.renderer, frame_fence, &fence_status);
    if (fence_status.bits == IGraphics.FenceStatus.FENCE_STATUS_INCOMPLETE.bits) {
        IGraphics.waitForFences(gpu.renderer, 1, &frame_fence);
    }

    const cmd_pool = gpu.cmd_pools[gpu.frame_index];
    IGraphics.resetCmdPool(gpu.renderer, cmd_pool);
    const cmd = gpu.cmds[gpu.frame_index];

    IGraphics.beginCmd(cmd);
    return gpu.frame_index;
}

pub fn frameSubmit() void {
    std.debug.assert(gpu.frame_started);

    var swap_chain_image_index: u32 = 0;
    IGraphics.acquireNextImage(gpu.renderer, gpu.swap_chain, gpu.image_acquired_semaphore, null, &swap_chain_image_index);
    const swap_chain_buffer = gpu.swap_chain.*.ppRenderTargets[swap_chain_image_index];

    var cmd = gpu.cmds[gpu.frame_index];

    var render_target_barriers = [1]IGraphics.RenderTargetBarrier{undefined};
    render_target_barriers[0] = std.mem.zeroes(IGraphics.RenderTargetBarrier);
    render_target_barriers[0].pRenderTarget = swap_chain_buffer;
    render_target_barriers[0].mCurrentState = IGraphics.ResourceState.RESOURCE_STATE_PRESENT;
    render_target_barriers[0].mNewState = IGraphics.ResourceState.RESOURCE_STATE_RENDER_TARGET;
    IGraphics.cmdResourceBarrier(cmd, 0, null, 0, null, 1, @ptrCast(&render_target_barriers));

    var bind_render_targets_desc = std.mem.zeroes(IGraphics.BindRenderTargetsDesc);
    bind_render_targets_desc.mRenderTargetCount = 1;
    bind_render_targets_desc.mRenderTargets[0] = std.mem.zeroes(IGraphics.BindRenderTargetDesc);
    bind_render_targets_desc.mRenderTargets[0].pRenderTarget = swap_chain_buffer;
    bind_render_targets_desc.mRenderTargets[0].mLoadAction = IGraphics.LoadActionType.LOAD_ACTION_CLEAR;
    IGraphics.cmdBindRenderTargets(cmd, &bind_render_targets_desc);

    IGraphics.cmdSetViewport(cmd, 0.0, 0.0, @floatFromInt(swap_chain_buffer.*.bitfield_2.mWidth), @floatFromInt(swap_chain_buffer.*.bitfield_2.mHeight), 0.0, 1.0);
    IGraphics.cmdSetScissor(cmd, 0, 0, swap_chain_buffer.*.bitfield_2.mWidth, swap_chain_buffer.*.bitfield_2.mHeight);

    render_target_barriers[0] = std.mem.zeroes(IGraphics.RenderTargetBarrier);
    render_target_barriers[0].pRenderTarget = swap_chain_buffer;
    render_target_barriers[0].mCurrentState = IGraphics.ResourceState.RESOURCE_STATE_RENDER_TARGET;
    render_target_barriers[0].mNewState = IGraphics.ResourceState.RESOURCE_STATE_PRESENT;
    IGraphics.cmdResourceBarrier(cmd, 0, null, 0, null, 1, @ptrCast(&render_target_barriers));

    IGraphics.endCmd(cmd);

    var wait_semaphores = [1]*IGraphics.Semaphore{gpu.image_acquired_semaphore};
    var signal_semaphores = [1]*IGraphics.Semaphore{gpu.semaphores[gpu.frame_index]};

    var submit_desc = std.mem.zeroes(IGraphics.QueueSubmitDesc);
    submit_desc.mCmdCount = 1;
    submit_desc.ppCmds = &cmd;
    submit_desc.mSignalSemaphoreCount = 1;
    submit_desc.ppSignalSemaphores = @ptrCast(&signal_semaphores);
    submit_desc.mWaitSemaphoreCount = 1;
    submit_desc.ppWaitSemaphores = @ptrCast(&wait_semaphores);
    submit_desc.pSignalFence = gpu.fences[gpu.frame_index];
    IGraphics.queueSubmit(gpu.graphics_queue, &submit_desc);

    wait_semaphores[0] = gpu.semaphores[gpu.frame_index];
    var present_desc = std.mem.zeroes(IGraphics.QueuePresentDesc);
    present_desc.mIndex = @intCast(swap_chain_image_index);
    present_desc.pSwapChain = gpu.swap_chain;
    present_desc.mWaitSemaphoreCount = 1;
    present_desc.ppWaitSemaphores = @ptrCast(&wait_semaphores);
    present_desc.mSubmitDone = true;
    IGraphics.queuePresent(gpu.graphics_queue, &present_desc);

    gpu.frame_index += 1;
    gpu.frame_index %= frames_in_flight_count;
    gpu.frame_started = false;
}

pub fn requestResize() void {
    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .RESIZE = true, .RENDERTARGET = true } };
    onUnload(reload_desc);
    onLoad(reload_desc);
}

pub fn compileShader(shader_load_desc: *const ShaderLoadDesc) !ShaderHandle {
    var binary_shader_desc = std.mem.zeroes(IGraphics.BinaryShaderDesc);

    if (shader_load_desc.vertex) |*vertex| {
        loadShaderStage(vertex, &binary_shader_desc.mVert);
        binary_shader_desc.mStages.bits |= IGraphics.ShaderStage.SHADER_STAGE_VERT.bits;
    }

    if (shader_load_desc.pixel) |*pixel| {
        loadShaderStage(pixel, &binary_shader_desc.mFrag);
        binary_shader_desc.mStages.bits |= IGraphics.ShaderStage.SHADER_STAGE_FRAG.bits;
    }

    if (shader_load_desc.compute) |*compute| {
        loadShaderStage(compute, &binary_shader_desc.mComp);
        binary_shader_desc.mStages.bits |= IGraphics.ShaderStage.SHADER_STAGE_COMP.bits;
    }

    var shader: [*c]IGraphics.Shader = null;
    IGraphics.addShaderBinary(gpu.renderer, &binary_shader_desc, &shader);

    if (shader_load_desc.vertex) |_| {
        if (binary_shader_desc.mVert.pByteCode) |byte_code| {
            const slice = @as([*]u8, @ptrCast(byte_code))[0..binary_shader_desc.mVert.mByteCodeSize];
            gpu.allocator.free(slice);
        }
    }

    if (shader_load_desc.pixel) |_| {
        if (binary_shader_desc.mFrag.pByteCode) |byte_code| {
            const slice = @as([*]u8, @ptrCast(byte_code))[0..binary_shader_desc.mFrag.mByteCodeSize];
            gpu.allocator.free(slice);
        }
    }

    if (shader_load_desc.compute) |_| {
        if (binary_shader_desc.mComp.pByteCode) |byte_code| {
            const slice = @as([*]u8, @ptrCast(byte_code))[0..binary_shader_desc.mComp.mByteCodeSize];
            gpu.allocator.free(slice);
        }
    }

    return gpu.shaders.add(.{ .ptr = shader }) catch unreachable;

}

fn loadShaderStage(shader_stage_load_desc: *const ShaderStageLoadDesc, binary_shader_stage_desc: [*c]IGraphics.BinaryShaderStageDesc) void {
    var file = std.fs.cwd().openFile(shader_stage_load_desc.path, .{}) catch unreachable;
    defer file.close();

    const stats = file.stat() catch unreachable;
    std.debug.assert(stats.size > 0);

    const buffer = gpu.allocator.alloc(u8, stats.size) catch unreachable;
    const read_size = file.readAll(buffer) catch unreachable;
    std.debug.assert(read_size == stats.size);

    binary_shader_stage_desc.*.pByteCode = @ptrCast(buffer.ptr);
    binary_shader_stage_desc.*.mByteCodeSize = @intCast(stats.size);
    binary_shader_stage_desc.*.pEntryPoint = @ptrCast(shader_stage_load_desc.entry);
    binary_shader_stage_desc.*.pName = @ptrCast(shader_stage_load_desc.path);
}

fn onLoad(reload_desc: IGraphics.ReloadDesc) void {
    std.debug.assert(gpu.renderer != null);

    if (reload_desc.mType.RESIZE or reload_desc.mType.RENDERTARGET) {
        swapchainCreate();
    }
}

fn onUnload(reload_desc: IGraphics.ReloadDesc) void {
    std.debug.assert(gpu.renderer != null);

    IGraphics.waitQueueIdle(gpu.graphics_queue);

    if (reload_desc.mType.RESIZE or reload_desc.mType.RENDERTARGET) {
        swapchainDestroy();
    }
}

fn swapchainCreate() void {
    const window_handle = IGraphics.WindowHandle{
        .type = .WIN32,
        .window = gpu.hwnd,
    };

    var window_width: u32 = 0;
    var window_height: u32 = 0;
    IGraphicsTides.getWindowSize(window_handle, &window_width, &window_height);

    var desc = std.mem.zeroes(IGraphics.SwapChainDesc);
    desc.mWindowHandle = window_handle;
    desc.mPresentQueueCount = 1;
    desc.ppPresentQueues = &gpu.graphics_queue;
    desc.mWidth = window_width;
    desc.mHeight = window_height;
    desc.mImageCount = IGraphics.getRecommendedSwapchainImageCount(gpu.renderer, &window_handle);
    desc.mColorFormat = IGraphics.getSupportedSwapchainFormat(gpu.renderer, &desc, IGraphics.ColorSpace.COLOR_SPACE_SDR_SRGB);
    desc.mEnableVsync = true;
    IGraphics.addSwapChain(gpu.renderer, &desc, &gpu.swap_chain);
}

fn swapchainDestroy() void {
    IGraphics.removeSwapChain(gpu.renderer, gpu.swap_chain);
}
