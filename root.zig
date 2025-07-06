const std = @import("std");
pub const IGraphics = @import("Common_3/Graphics/Interfaces/IGraphics.zig");
const IGraphicsTides = @import("Common_3/Graphics/Interfaces/IGraphicsTides.zig");

const Pool = @import("zpool").Pool;

pub const HashKey = struct {
    key: u64,

    pub fn generate(input: []const u8) HashKey {
        return .{
            .key = std.hash.Wyhash.hash(0, input),
        };
    }
};

pub export const D3D12SDKVersion: u32 = 715;
pub export const D3D12SDKPath: [*:0]const u8 = ".\\";

// ████████╗██╗  ██╗███████╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗    ████████╗██╗   ██╗██████╗ ███████╗███████╗
// ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝    ╚══██╔══╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔════╝
//    ██║   ███████║█████╗█████╗█████╗  ██║   ██║██████╔╝██║  ███╗█████╗         ██║    ╚████╔╝ ██████╔╝█████╗  ███████╗
//    ██║   ██╔══██║██╔══╝╚════╝██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝         ██║     ╚██╔╝  ██╔═══╝ ██╔══╝  ╚════██║
//    ██║   ██║  ██║███████╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗       ██║      ██║   ██║     ███████╗███████║
//    ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝       ╚═╝      ╚═╝   ╚═╝     ╚══════╝╚══════╝
//

pub const AddressMode = IGraphics.AddressMode;
pub const BlendStateDesc = IGraphics.BlendStateDesc;
pub const CompareMode = IGraphics.CompareMode;
pub const CullMode = IGraphics.CullMode;
pub const DepthStateDesc = IGraphics.DepthStateDesc;
pub const DescriptorType = IGraphics.DescriptorType;
pub const FillMode = IGraphics.FillMode;
pub const FilterType = IGraphics.FilterType;
pub const FrontFace = IGraphics.FrontFace;
pub const GraphicsPipelineDesc = IGraphics.GraphicsPipelineDesc;
pub const IndexType = IGraphics.IndexType;
pub const IndirectArgumentType = IGraphics.IndirectArgumentType;
pub const IndirectDrawIndexArguments = IGraphics.IndirectDrawIndexArguments;
pub const LoadActionType = IGraphics.LoadActionType;
pub const MipMapMode = IGraphics.MipMapMode;
pub const PipelineDesc = IGraphics.PipelineDesc;
pub const PipelineType = IGraphics.PipelineType;
pub const PrimitiveTopology = IGraphics.PrimitiveTopology;
pub const RasterizerStateDesc = IGraphics.RasterizerStateDesc;
pub const RenderTargetDesc = IGraphics.RenderTargetDesc;
pub const ResourceState = IGraphics.ResourceState;
pub const SampleCount = IGraphics.SampleCount;
pub const SamplerDesc = IGraphics.SamplerDesc;
pub const TextureCreationFlags = IGraphics.TextureCreationFlags;
pub const TextureDesc = IGraphics.TextureDesc;
pub const TextureDimension = IGraphics.TextureDimension;
pub const TinyImageFormat = IGraphics.TinyImageFormat;

pub const DataSlice = extern struct {
    data: ?*const anyopaque,
    size: u64,
};

//  ██████╗ ██████╗ ██╗   ██╗
// ██╔════╝ ██╔══██╗██║   ██║
// ██║  ███╗██████╔╝██║   ██║
// ██║   ██║██╔═══╝ ██║   ██║
// ╚██████╔╝██║     ╚██████╔╝
//  ╚═════╝ ╚═╝      ╚═════╝
//

pub const frames_in_flight_count: u32 = 2;

pub const GpuDesc = struct {
    graphics_root_signature_path: []const u8,
    compute_root_signature_path: []const u8,
    hwnd: std.os.windows.HWND,
};

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

    profiler: Profiler,
    frame_profiler_index: usize,

    linear_repeat_sampler: [*c]IGraphics.Sampler = null,
    linear_clamp_sampler: [*c]IGraphics.Sampler = null,

    frame_started: bool = false,
    frame_index: u32 = 0,
    swap_chain_image_index: u32 = 0,
    swap_chain_image_handle: RenderTargetHandle = RenderTargetHandle.nil,

    hwnd: std.os.windows.HWND,

    // Resource Pools
    shaders: ShaderPool = undefined,
    descriptor_sets: DescriptorSetPool = undefined,
    psos: PsoPool = undefined,
    render_targets: RenderTargetPool = undefined,
    render_textures: RenderTexturePool = undefined,
    textures: TexturePool = undefined,
    buffers: BufferPool = undefined,
    static_samplers: StaticSamplerPool = undefined,
    samplers: SamplerPool = undefined,

    // Callbacks
    update_descriptor_sets_fn: updateDescriptorSetsFn = null,

    // Uploads
    upload_queue: UploadQueue = undefined,
    upload_ring_buffer: UploadRingBuffer = undefined,
};

var gpu: Gpu = undefined;

pub fn initializeGpu(gpu_desc: GpuDesc, allocator: std.mem.Allocator) !void {
    gpu.allocator = allocator;

    gpu.shaders = ShaderPool.initMaxCapacity(gpu.allocator) catch unreachable;
    gpu.descriptor_sets = DescriptorSetPool.init(gpu.allocator);
    gpu.psos = PsoPool.initMaxCapacity(gpu.allocator) catch unreachable;
    gpu.render_targets = RenderTargetPool.initMaxCapacity(gpu.allocator) catch unreachable;
    gpu.render_textures = RenderTexturePool.initMaxCapacity(gpu.allocator) catch unreachable;
    gpu.textures = TexturePool.init(gpu.allocator);
    gpu.buffers = BufferPool.init(gpu.allocator);
    gpu.static_samplers = StaticSamplerPool.initMaxCapacity(gpu.allocator) catch unreachable;
    gpu.samplers = SamplerPool.initMaxCapacity(gpu.allocator) catch unreachable;

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

    gpu.swap_chain_image_handle = gpu.render_targets.add(.{ .ptr = null, .desc = std.mem.zeroes(IGraphics.RenderTargetDesc), .resize = false }) catch unreachable;
    gpu.frame_started = false;
    gpu.frame_index = 0;

    gpu.hwnd = gpu_desc.hwnd;

    gpu.profiler.init(gpu.allocator);
    gpu.frame_profiler_index = 0;

    // Initialize uploads
    gpu.upload_queue = UploadQueue.init();
    gpu.upload_ring_buffer = UploadRingBuffer.init(&gpu.upload_queue);

    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .RESIZE = true, .RENDERTARGET = true } };
    onLoad(reload_desc);
}

pub fn shutdownGpu() void {
    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .RESIZE = true, .RENDERTARGET = true, .SHADER = true } };
    onUnload(reload_desc);

    gpu.upload_ring_buffer.exit();
    gpu.upload_queue.exit();

    var buffer_handles = gpu.buffers.liveHandles();
    while (buffer_handles.next()) |handle| {
        const buffer = gpu.buffers.getColumnPtr(handle, .ptr) catch unreachable;
        IGraphicsTides.removeBufferEx(gpu.renderer, buffer.*);
        buffer.* = null;
    }

    var texture_handles = gpu.textures.liveHandles();
    while (texture_handles.next()) |handle| {
        const texture = gpu.textures.getColumnPtr(handle, .ptr) catch unreachable;
        IGraphicsTides.removeTextureEx(gpu.renderer, texture.*);
        texture.* = null;
    }

    gpu.shaders.deinit();
    gpu.descriptor_sets.deinit();
    gpu.psos.deinit();
    gpu.render_targets.deinit();
    gpu.render_textures.deinit();
    gpu.textures.deinit();
    gpu.buffers.deinit();
    gpu.static_samplers.deinit();
    gpu.samplers.deinit();

    gpu.profiler.shutdown();

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

// ███████╗██████╗  █████╗ ███╗   ███╗███████╗
// ██╔════╝██╔══██╗██╔══██╗████╗ ████║██╔════╝
// █████╗  ██████╔╝███████║██╔████╔██║█████╗
// ██╔══╝  ██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝
// ██║     ██║  ██║██║  ██║██║ ╚═╝ ██║███████╗
// ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝

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

    gpu.frame_profiler_index = gpu.profiler.startProfile("Frame");

    IGraphics.acquireNextImage(gpu.renderer, gpu.swap_chain, gpu.image_acquired_semaphore, null, &gpu.swap_chain_image_index);
    const swap_chain_buffer = gpu.swap_chain.*.ppRenderTargets[gpu.swap_chain_image_index];
    gpu.render_targets.setColumn(gpu.swap_chain_image_handle, .ptr, swap_chain_buffer) catch unreachable;

    return gpu.frame_index;
}

pub fn frameSubmit() void {
    std.debug.assert(gpu.frame_started);

    gpu.profiler.endProfile(gpu.frame_profiler_index);
    gpu.profiler.endFrame();

    var cmd = gpu.cmds[gpu.frame_index];
    IGraphics.endCmd(cmd);

    endFrameUpload();

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
    present_desc.mIndex = @intCast(gpu.swap_chain_image_index);
    present_desc.pSwapChain = gpu.swap_chain;
    present_desc.mWaitSemaphoreCount = 1;
    present_desc.ppWaitSemaphores = @ptrCast(&wait_semaphores);
    present_desc.mSubmitDone = true;
    IGraphics.queuePresent(gpu.graphics_queue, &present_desc);

    gpu.frame_index += 1;
    gpu.frame_index %= frames_in_flight_count;
    gpu.frame_started = false;
}

// ██╗      ██████╗  █████╗ ██████╗        ██╗       ██╗   ██╗███╗   ██╗██╗      ██████╗  █████╗ ██████╗
// ██║     ██╔═══██╗██╔══██╗██╔══██╗       ██║       ██║   ██║████╗  ██║██║     ██╔═══██╗██╔══██╗██╔══██╗
// ██║     ██║   ██║███████║██║  ██║    ████████╗    ██║   ██║██╔██╗ ██║██║     ██║   ██║███████║██║  ██║
// ██║     ██║   ██║██╔══██║██║  ██║    ██╔═██╔═╝    ██║   ██║██║╚██╗██║██║     ██║   ██║██╔══██║██║  ██║
// ███████╗╚██████╔╝██║  ██║██████╔╝    ██████║      ╚██████╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║██████╔╝
// ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝     ╚═════╝       ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝
//

pub fn requestResize() void {
    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .RESIZE = true, .RENDERTARGET = true } };
    onUnload(reload_desc);
    onLoad(reload_desc);
}

pub fn requestShadersReload() void {
    const reload_desc = IGraphics.ReloadDesc{ .mType = .{ .SHADER = true } };
    onUnload(reload_desc);
    onLoad(reload_desc);
}

fn onLoad(reload_desc: IGraphics.ReloadDesc) void {
    std.debug.assert(gpu.renderer != null);

    if (reload_desc.mType.RESIZE or reload_desc.mType.RENDERTARGET) {
        swapchainCreate();

        const window_handle = IGraphics.WindowHandle{
            .type = .WIN32,
            .window = gpu.hwnd,
        };

        var window_width: u32 = 0;
        var window_height: u32 = 0;
        IGraphicsTides.getWindowSize(window_handle, &window_width, &window_height);

        var render_target_handles = gpu.render_targets.liveHandles();
        while (render_target_handles.next()) |handle| {
            const resize = gpu.render_targets.getColumn(handle, .resize) catch unreachable;
            if (resize) {
                const render_target = gpu.render_targets.getColumnPtr(handle, .ptr) catch unreachable;
                var render_target_desc = gpu.render_targets.getColumnPtr(handle, .desc) catch unreachable;
                render_target_desc.mWidth = window_width;
                render_target_desc.mHeight = window_height;
                IGraphics.addRenderTarget(gpu.renderer, render_target_desc, &render_target.*);
            }
        }

        var render_texture_handles = gpu.render_textures.liveHandles();
        while (render_texture_handles.next()) |handle| {
            const texture = gpu.render_textures.getColumnPtr(handle, .ptr) catch unreachable;
            var texture_desc = gpu.render_textures.getColumnPtr(handle, .desc) catch unreachable;
            texture_desc.mWidth = window_width;
            texture_desc.mHeight = window_height;
            IGraphicsTides.addTextureEx(gpu.renderer, texture_desc, false, &texture.*);
        }
    }

    if (reload_desc.mType.SHADER) {
        var shader_handles = gpu.shaders.liveHandles();
        while (shader_handles.next()) |handle| {
            const shader = gpu.shaders.getColumnPtr(handle, .ptr) catch unreachable;
            const descriptors = gpu.shaders.getColumnPtr(handle, .descriptors) catch unreachable;
            const descriptor_sets_mappings = gpu.shaders.getColumnPtr(handle, .descriptor_sets_mappings) catch unreachable;
            const desc = gpu.shaders.getColumnPtr(handle, .desc) catch unreachable;
            const thread_group_size_x = gpu.shaders.getColumnPtr(handle, .thread_group_size_x) catch unreachable;
            const thread_group_size_y = gpu.shaders.getColumnPtr(handle, .thread_group_size_y) catch unreachable;
            const thread_group_size_z = gpu.shaders.getColumnPtr(handle, .thread_group_size_z) catch unreachable;
            const compilation_result = compileShaderInternal(desc.*) catch unreachable;
            shader.* = compilation_result.shader;
            descriptors.* = compilation_result.descriptors;
            descriptor_sets_mappings.* = compilation_result.descriptor_sets_mappings;
            thread_group_size_x.* = compilation_result.thread_group_size_x;
            thread_group_size_y.* = compilation_result.thread_group_size_y;
            thread_group_size_z.* = compilation_result.thread_group_size_z;
        }
    }

    if (reload_desc.mType.SHADER or reload_desc.mType.RENDERTARGET) {
        var pso_handles = gpu.psos.liveHandles();
        while (pso_handles.next()) |handle| {
            const pso = gpu.psos.getColumnPtr(handle, .ptr) catch unreachable;
            const desc = gpu.psos.getColumn(handle, .desc) catch unreachable;
            const shader_handle = gpu.psos.getColumn(handle, .shader) catch unreachable;
            if (desc.mType.bits == IGraphics.PipelineType.PIPELINE_TYPE_GRAPHICS.bits) {
                pso.* = createGraphicsPso(desc, shader_handle) catch unreachable;
            } else {
                pso.* = createComputePso(desc, shader_handle) catch unreachable;
            }
        }
    }

    if (gpu.update_descriptor_sets_fn) |callback| {
        callback();
    }
}

fn onUnload(reload_desc: IGraphics.ReloadDesc) void {
    std.debug.assert(gpu.renderer != null);

    IGraphics.waitQueueIdle(gpu.graphics_queue);

    if (reload_desc.mType.RESIZE or reload_desc.mType.RENDERTARGET) {
        swapchainDestroy();

        var render_target_handles = gpu.render_targets.liveHandles();
        while (render_target_handles.next()) |handle| {
            const resize = gpu.render_targets.getColumn(handle, .resize) catch unreachable;
            if (resize) {
                const render_target = gpu.render_targets.getColumnPtr(handle, .ptr) catch unreachable;
                IGraphics.removeRenderTarget(gpu.renderer, render_target.*);
                render_target.* = null;
            }
        }

        var render_texture_handles = gpu.render_textures.liveHandles();
        while (render_texture_handles.next()) |handle| {
            const texture = gpu.render_textures.getColumnPtr(handle, .ptr) catch unreachable;
            IGraphicsTides.removeTextureEx(gpu.renderer, texture.*);
            texture.* = null;
        }
    }

    if (reload_desc.mType.SHADER) {
        var shader_handles = gpu.shaders.liveHandles();
        while (shader_handles.next()) |handle| {
            const shader = gpu.shaders.getColumnPtr(handle, .ptr) catch unreachable;
            const descriptors = gpu.shaders.getColumnPtr(handle, .descriptors) catch unreachable;
            IGraphics.removeShader(gpu.renderer, shader.*);
            IGraphicsTides.removeShaderDescriptors(@constCast(descriptors));
            shader.* = null;
        }
    }

    if (reload_desc.mType.SHADER or reload_desc.mType.RENDERTARGET) {
        var pso_handles = gpu.psos.liveHandles();
        while (pso_handles.next()) |handle| {
            const pso = gpu.psos.getColumnPtr(handle, .ptr) catch unreachable;
            IGraphics.removePipeline(gpu.renderer, pso.*);
            pso.* = null;
        }
    }
}

// ███████╗ █████╗ ███╗   ███╗██████╗ ██╗     ███████╗██████╗ ███████╗
// ██╔════╝██╔══██╗████╗ ████║██╔══██╗██║     ██╔════╝██╔══██╗██╔════╝
// ███████╗███████║██╔████╔██║██████╔╝██║     █████╗  ██████╔╝███████╗
// ╚════██║██╔══██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝  ██╔══██╗╚════██║
// ███████║██║  ██║██║ ╚═╝ ██║██║     ███████╗███████╗██║  ██║███████║
// ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝
//

const StaticSamplerPool = Pool(8, 8, [*c]IGraphics.Sampler, struct {
    ptr: [*c]IGraphics.Sampler,
});
pub const StaticSamplerHandle = StaticSamplerPool.Handle;

const SamplerPool = Pool(8, 8, [*c]IGraphics.Sampler, struct {
    ptr: [*c]IGraphics.Sampler,
});
pub const SamplerHandle = SamplerPool.Handle;

pub fn createStaticSampler(desc: IGraphics.SamplerDesc) !StaticSamplerHandle {
    var sampler: [*c]IGraphics.Sampler = null;
    IGraphics.addSampler(gpu.renderer, &desc, false, &sampler);

    return gpu.static_samplers.add(.{ .ptr = sampler }) catch unreachable;
}

pub fn createBindlessSampler(desc: IGraphics.SamplerDesc) !SamplerHandle {
    var sampler: [*c]IGraphics.Sampler = null;
    IGraphics.addSampler(gpu.renderer, &desc, true, &sampler);

    return gpu.samplers.add(.{ .ptr = sampler }) catch unreachable;
}

pub fn getSamplerBindlessIndex(handle: SamplerHandle) u32 {
    const sampler = gpu.samplers.getColumnPtr(handle, .ptr) catch unreachable;
    return @intCast(sampler.*.*.mDx.mDescriptor);
}

// ██████╗ ███████╗ ██████╗ ███████╗
// ██╔══██╗██╔════╝██╔═══██╗██╔════╝
// ██████╔╝███████╗██║   ██║███████╗
// ██╔═══╝ ╚════██║██║   ██║╚════██║
// ██║     ███████║╚██████╔╝███████║
// ╚═╝     ╚══════╝ ╚═════╝ ╚══════╝
//

const PsoPool = Pool(8, 8, [*c]IGraphics.Pipeline, struct {
    ptr: [*c]IGraphics.Pipeline,
    shader: ShaderHandle,
    desc: IGraphics.PipelineDesc,
});
pub const PsoHandle = PsoPool.Handle;

pub fn createPso(desc: IGraphics.PipelineDesc, shader_handle: ShaderHandle) !PsoHandle {
    const pso: [*c]IGraphics.Pipeline = blk: {
        if (desc.mType.bits == IGraphics.PipelineType.PIPELINE_TYPE_GRAPHICS.bits) {
            break :blk createGraphicsPso(desc, shader_handle) catch unreachable;
        } else {
            break :blk createComputePso(desc, shader_handle) catch unreachable;
        }
    };

    return gpu.psos.add(.{
        .ptr = pso,
        .desc = desc,
        .shader = shader_handle,
    }) catch unreachable;
}

fn createComputePso(desc: IGraphics.PipelineDesc, shader_handle: ShaderHandle) ![*c]IGraphics.Pipeline {
    std.debug.assert(desc.mType.bits == IGraphics.PipelineType.PIPELINE_TYPE_COMPUTE.bits);

    var pso_desc: IGraphics.PipelineDesc = undefined;
    memcpy(&pso_desc, &desc, 0, @sizeOf(IGraphics.PipelineDesc));

    const shader = gpu.shaders.getColumnPtr(shader_handle, .ptr) catch unreachable;
    pso_desc.__union_field1.mComputeDesc.pShaderProgram = shader.*;

    var pso: [*c]IGraphics.Pipeline = null;
    IGraphics.addPipeline(gpu.renderer, &pso_desc, @ptrCast(&pso));

    return pso;
}

fn createGraphicsPso(desc: IGraphics.PipelineDesc, shader_handle: ShaderHandle) ![*c]IGraphics.Pipeline {
    std.debug.assert(desc.mType.bits == IGraphics.PipelineType.PIPELINE_TYPE_GRAPHICS.bits);

    var pso_desc: IGraphics.PipelineDesc = undefined;
    memcpy(&pso_desc, &desc, 0, @sizeOf(IGraphics.PipelineDesc));

    const shader = gpu.shaders.getColumnPtr(shader_handle, .ptr) catch unreachable;
    pso_desc.__union_field1.mGraphicsDesc.pShaderProgram = shader.*;

    var pso: [*c]IGraphics.Pipeline = null;
    IGraphics.addPipeline(gpu.renderer, &pso_desc, @ptrCast(&pso));

    return pso;
}

// ███████╗██╗  ██╗ █████╗ ██████╗ ███████╗██████╗ ███████╗
// ██╔════╝██║  ██║██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝
// ███████╗███████║███████║██║  ██║█████╗  ██████╔╝███████╗
// ╚════██║██╔══██║██╔══██║██║  ██║██╔══╝  ██╔══██╗╚════██║
// ███████║██║  ██║██║  ██║██████╔╝███████╗██║  ██║███████║
// ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝
//

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
    descriptors: IGraphicsTides.Descriptors,
    descriptor_sets_mappings: DescriptorSetsMappings,
    desc: ShaderLoadDesc,
    thread_group_size_x: u32,
    thread_group_size_y: u32,
    thread_group_size_z: u32,
});
pub const ShaderHandle = ShaderPool.Handle;

pub fn compileShader(shader_load_desc: ShaderLoadDesc) !ShaderHandle {
    const compilation_result = compileShaderInternal(shader_load_desc) catch unreachable;

    var desc: ShaderLoadDesc = undefined;
    if (shader_load_desc.vertex) |vertex| {
        desc.vertex = .{
            .entry = gpu.allocator.dupe(u8, vertex.entry) catch unreachable,
            .path = gpu.allocator.dupe(u8, vertex.path) catch unreachable,
        };
    } else {
        desc.vertex = null;
    }

    if (shader_load_desc.pixel) |pixel| {
        desc.pixel = .{
            .entry = gpu.allocator.dupe(u8, pixel.entry) catch unreachable,
            .path = gpu.allocator.dupe(u8, pixel.path) catch unreachable,
        };
    } else {
        desc.pixel = null;
    }

    if (shader_load_desc.compute) |compute| {
        desc.compute = .{
            .entry = gpu.allocator.dupe(u8, compute.entry) catch unreachable,
            .path = gpu.allocator.dupe(u8, compute.path) catch unreachable,
        };
    } else {
        desc.compute = null;
    }

    return gpu.shaders.add(.{
        .ptr = compilation_result.shader,
        .descriptors = compilation_result.descriptors,
        .descriptor_sets_mappings = compilation_result.descriptor_sets_mappings,
        .desc = desc,
        .thread_group_size_x = compilation_result.thread_group_size_x,
        .thread_group_size_y = compilation_result.thread_group_size_y,
        .thread_group_size_z = compilation_result.thread_group_size_z,
    }) catch unreachable;
}

pub fn getShaderThreadGroupSize(handle: ShaderHandle) struct { x: u32, y: u32, z: u32 } {
    const thread_group_size_x = gpu.shaders.getColumn(handle, .thread_group_size_x) catch unreachable;
    const thread_group_size_y = gpu.shaders.getColumn(handle, .thread_group_size_y) catch unreachable;
    const thread_group_size_z = gpu.shaders.getColumn(handle, .thread_group_size_z) catch unreachable;

    return .{
        .x = thread_group_size_x,
        .y = thread_group_size_y,
        .z = thread_group_size_z,
    };
}

fn compileShaderInternal(shader_load_desc: ShaderLoadDesc) !struct {
    shader: [*c]IGraphics.Shader,
    descriptors: IGraphicsTides.Descriptors,
    descriptor_sets_mappings: DescriptorSetsMappings,
    thread_group_size_x: u32,
    thread_group_size_y: u32,
    thread_group_size_z: u32,
} {
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

    var thread_group_size_x: u32 = 0;
    var thread_group_size_y: u32 = 0;
    var thread_group_size_z: u32 = 0;
    var descriptors = std.mem.zeroes(IGraphicsTides.Descriptors);
    IGraphicsTides.createShaderDescriptors(shader, @ptrCast(&descriptors), &thread_group_size_x, &thread_group_size_y, &thread_group_size_z);

    var descriptor_sets_mappings: DescriptorSetsMappings = undefined;
    for (0..IGraphicsTides.TIDES_DESCRIPTOR_SPACES_COUNT) |space_index| {
        const descriptor_set = &descriptors.pSpaceDescriptors[space_index];
        var descriptor_set_mappings = &descriptor_sets_mappings.descriptor_mappings[space_index];
        descriptor_set_mappings.resources_count = descriptor_set.mDescriptorsCount;

        for (0..descriptor_set.mDescriptorsCount) |descriptor_index| {
            const descriptor = &descriptor_set.pDescriptors[descriptor_index];
            var resource_mapping = &descriptor_set_mappings.resource_mappings[descriptor_index];
            const slice = std.mem.span(descriptor.pName);
            resource_mapping.hash = HashKey.generate(slice);
            resource_mapping.index = descriptor.mOffset; // TODO: Figure out if this is right

            resource_mapping.resource_type = switch (descriptor.mType.bits) {
                IGraphics.DescriptorType.DESCRIPTOR_TYPE_SAMPLER.bits => .sampler,
                IGraphics.DescriptorType.DESCRIPTOR_TYPE_TEXTURE.bits, IGraphics.DescriptorType.DESCRIPTOR_TYPE_RW_TEXTURE.bits => .texture,
                IGraphics.DescriptorType.DESCRIPTOR_TYPE_BUFFER.bits, IGraphics.DescriptorType.DESCRIPTOR_TYPE_RW_BUFFER.bits, IGraphics.DescriptorType.DESCRIPTOR_TYPE_BUFFER_RAW.bits, IGraphics.DescriptorType.DESCRIPTOR_TYPE_RW_BUFFER_RAW.bits, IGraphics.DescriptorType.DESCRIPTOR_TYPE_UNIFORM_BUFFER.bits => .buffer,
                else => @panic("Unsupported descriptor type"),
            };
        }
    }

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

    return .{
        .shader = shader,
        .descriptors = descriptors,
        .descriptor_sets_mappings = descriptor_sets_mappings,
        .thread_group_size_x = thread_group_size_x,
        .thread_group_size_y = thread_group_size_y,
        .thread_group_size_z = thread_group_size_z,
    };
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

// ██████╗ ███████╗███╗   ██╗██████╗ ███████╗██████╗     ████████╗███████╗██╗  ██╗████████╗██╗   ██╗██████╗ ███████╗███████╗       ██╗       ████████╗ █████╗ ██████╗  ██████╗ ███████╗████████╗███████╗
// ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗    ╚══██╔══╝██╔════╝╚██╗██╔╝╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔════╝       ██║       ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝ ██╔════╝╚══██╔══╝██╔════╝
// ██████╔╝█████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝       ██║   █████╗   ╚███╔╝    ██║   ██║   ██║██████╔╝█████╗  ███████╗    ████████╗       ██║   ███████║██████╔╝██║  ███╗█████╗     ██║   ███████╗
// ██╔══██╗██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗       ██║   ██╔══╝   ██╔██╗    ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║    ██╔═██╔═╝       ██║   ██╔══██║██╔══██╗██║   ██║██╔══╝     ██║   ╚════██║
// ██║  ██║███████╗██║ ╚████║██████╔╝███████╗██║  ██║       ██║   ███████╗██╔╝ ██╗   ██║   ╚██████╔╝██║  ██║███████╗███████║    ██████║         ██║   ██║  ██║██║  ██║╚██████╔╝███████╗   ██║   ███████║
// ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝       ╚═╝   ╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═════╝         ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝
//

const RenderTargetPool = Pool(8, 8, [*c]IGraphics.RenderTarget, struct {
    ptr: [*c]IGraphics.RenderTarget,
    desc: IGraphics.RenderTargetDesc,
    resize: bool,
});
pub const RenderTargetHandle = RenderTargetPool.Handle;

pub fn createRenderTarget(desc: IGraphics.RenderTargetDesc) !RenderTargetHandle {
    var render_target: [*c]IGraphics.RenderTarget = null;
    IGraphics.addRenderTarget(gpu.renderer, @ptrCast(&desc), &render_target);

    return gpu.render_targets.add(.{
        .ptr = render_target,
        .desc = desc,
        .resize = true,
    });
}

const RenderTexturePool = Pool(8, 8, [*c]IGraphics.Texture, struct {
    ptr: [*c]IGraphics.Texture,
    desc: IGraphics.TextureDesc,
});
pub const RenderTextureHandle = RenderTexturePool.Handle;

pub fn createRenderTexture(desc: IGraphics.TextureDesc) !RenderTextureHandle {
    var texture: [*c]IGraphics.Texture = null;
    IGraphicsTides.addTextureEx(gpu.renderer, @ptrCast(&desc), false, &texture);

    return gpu.render_textures.add(.{
        .ptr = texture,
        .desc = desc,
    });
}

// ████████╗███████╗██╗  ██╗████████╗██╗   ██╗██████╗ ███████╗███████╗
// ╚══██╔══╝██╔════╝╚██╗██╔╝╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔════╝
//    ██║   █████╗   ╚███╔╝    ██║   ██║   ██║██████╔╝█████╗  ███████╗
//    ██║   ██╔══╝   ██╔██╗    ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║
//    ██║   ███████╗██╔╝ ██╗   ██║   ╚██████╔╝██║  ██║███████╗███████║
//    ╚═╝   ╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝
//

const TexturePool = Pool(16, 16, [*c]IGraphics.Buffer, struct {
    ptr: [*c]IGraphics.Texture,
});
pub const TextureHandle = TexturePool.Handle;

pub fn createTexture(desc: IGraphics.TextureDesc, bindless: bool) !TextureHandle {
    var texture: [*c]IGraphics.Texture = null;
    IGraphicsTides.addTextureEx(gpu.renderer, @ptrCast(&desc), bindless, &texture);

    return gpu.textures.add(.{ .ptr = texture });
}

pub fn destroyTexture(handle: TextureHandle) !void {
    const texture = gpu.textures.getColumnPtr(handle, .ptr) catch unreachable;
    IGraphicsTides.removeTextureEx(gpu.renderer, texture.*);
    texture.* = null;
    gpu.textures.removeAssumeLive(handle);
}

pub fn getTextureBindlessIndex(handle: TextureHandle) u32 {
    const texture = gpu.textures.getColumnPtr(handle, .ptr) catch unreachable;
    return @intCast(texture.*.*.mDx.mDescriptors);
}

pub fn getTextureResolution(handle: TextureHandle) [2]u32 {
    const texture = gpu.textures.getColumnPtr(handle, .ptr) catch unreachable;
    const width = texture.*.*.bitfield_1.mWidth;
    const height = texture.*.*.bitfield_1.mHeight;

    return .{ @intCast(width), @intCast(height) };
}

pub fn updateTexture(handle: TextureHandle, desc: TextureDesc, data: []u8) void {
    const slice_alignment = getTextureSubResourceAlignment(desc.mFormat);
    const row_alignment = getTextureRowAlignment();
    const required_size = getSurfaceSize(
        desc.mFormat,
        desc.mWidth,
        desc.mHeight,
        desc.mDepth,
        row_alignment,
        slice_alignment,
        0,
        desc.mMipLevels,
        0,
        desc.mArraySize);

    const texture = gpu.textures.getColumnPtr(handle, .ptr) catch unreachable;

    var upload_context = gpu.upload_ring_buffer.begin(@intCast(required_size));
    var dest_offset: u64 = 0;
    var source_offset: u64 = 0;

    for (0..desc.mMipLevels) |mip_index| {
        const w = @max(1, desc.mWidth >> @intCast(mip_index));
        const h = @max(1, desc.mHeight >> @intCast(mip_index));
        const d = @max(1, desc.mDepth >> @intCast(mip_index));

        const surface_info = getSurfaceInfo(w, h, desc.mFormat);
        const sub_row_pitch = roundUp(u32, surface_info.row_bytes, row_alignment);
        const sub_slice_pitch = roundUp(u32, sub_row_pitch * surface_info.num_rows, slice_alignment);
        const sub_num_rows = surface_info.num_rows;
        const sub_depth = d;
        const upload_data = @intFromPtr(upload_context.buffer.*.pCpuMappedAddress.?) + dest_offset;

        for (0..sub_depth) |z| {
            const dest_data = upload_data + sub_slice_pitch * z;
            for (0..sub_num_rows) |r| {
                memcpy(@ptrFromInt(dest_data + r * sub_row_pitch), @ptrCast(data[source_offset..]), 0, surface_info.row_bytes);
                source_offset += @intCast(surface_info.row_bytes);
            }
        }

        const subresource_desc = IGraphicsTides.SubResourceDataDesc{
            .mArrayLayer = 0,
            .mMipLevel = @intCast(mip_index),
            .mSrcOffset = upload_context.buffer_offset + dest_offset,
        };
        IGraphicsTides.cmdUpdateSubresourceEx(upload_context.cmd, texture.*, upload_context.buffer, @constCast(&subresource_desc));
        dest_offset += sub_depth * sub_slice_pitch;
    }

    gpu.upload_ring_buffer.end(&upload_context, true);
}

fn getTextureRowAlignment() u32 {
    return @max(1, gpu.renderer.*.pGpu.*.mUploadBufferTextureRowAlignment);
}

fn getTextureSubResourceAlignment(format: IGraphics.TinyImageFormat) u32 {
    const block_size = @max(1, IGraphics.tiny_image_format.bitSizeOfBlock(format) >> 3);
    const alignment = roundUp(u32, gpu.renderer.*.pGpu.*.mUploadBufferTextureAlignment, block_size);
    return roundUp(u32, alignment, getTextureRowAlignment());
}

fn getSurfaceSize(
    format: IGraphics.TinyImageFormat,
    width: u32,
    height: u32,
    depth: u32,
    row_stride: u32,
    slice_stride: u32,
    base_mip_level: u32,
    mip_levels: u32,
    base_array_layer: u32,
    array_layers: u32,
) u32 {
    var required_size: u32 = 0;

    for (base_array_layer..(base_array_layer + array_layers)) |_| {
        var w = width;
        var h = height;
        var d = depth;

        for (base_mip_level..(base_mip_level + mip_levels)) |_| {
            const surface_info = getSurfaceInfo(w, h, format);

            required_size += roundUp(u32, d * roundUp(u32, surface_info.row_bytes, row_stride) * surface_info.num_rows, slice_stride);

            w = w >> 1;
            h = h >> 1;
            d = d >> 1;
            if (w == 0) {
                w = 1;
            }
            if (h == 0) {
                h = 1;
            }
            if (d == 0) {
                d = 1;
            }
        }
    }

    return required_size;
}

fn getSurfaceInfo(width: u32, height: u32, format: IGraphics.TinyImageFormat) struct {
    num_bytes: u32,
    row_bytes: u32,
    num_rows: u32,
} {
    const bpp = IGraphics.tiny_image_format.bitSizeOfBlock(format);
    const compressed = IGraphics.tiny_image_format.isCompressed(format);
    const planar = IGraphics.tiny_image_format.isPlanar(format);

    var num_bytes: u32 = 0;
    var row_bytes: u32 = 0;
    var num_rows: u32 = 0;

    if (compressed) {
        const block_width = IGraphics.tiny_image_format.widthOfBlock(format);
        const block_height = IGraphics.tiny_image_format.heightOfBlock(format);
        var num_blocks_wide: u32 = 0;
        var num_blocks_high: u32 = 0;
        if (width > 0) {
            num_blocks_wide = @max(1, (width + (block_width - 1)) / block_width);
        }

        if (height > 0) {
            num_blocks_high = @max(1, (height + (block_height - 1)) / block_height);
        }

        row_bytes = num_blocks_wide * (bpp >> 3);
        num_rows = num_blocks_high;
        num_bytes = row_bytes * num_blocks_high;
    } else if (planar) {
        const num_planes = IGraphics.tiny_image_format.numOfPlanes(format);

        for (0..num_planes) |i| {
            num_bytes += IGraphics.tiny_image_format.planeWidth(format, @intCast(i), width) *
                IGraphics.tiny_image_format.planeHeight(format, @intCast(i), height) *
                IGraphics.tiny_image_format.planeSizeOfBlock(format, @intCast(i));
        }

        num_rows = 1;
        row_bytes = num_bytes;
    } else {
        if (bpp > 0) {
            row_bytes = (width * bpp + 7) / 8;
            num_rows = height;
            num_bytes = row_bytes * height;
        }
    }

    return .{
        .num_bytes = num_bytes,
        .row_bytes = row_bytes,
        .num_rows = num_rows,
    };
}

// ██████╗ ██╗   ██╗███████╗███████╗███████╗██████╗ ███████╗
// ██╔══██╗██║   ██║██╔════╝██╔════╝██╔════╝██╔══██╗██╔════╝
// ██████╔╝██║   ██║█████╗  █████╗  █████╗  ██████╔╝███████╗
// ██╔══██╗██║   ██║██╔══╝  ██╔══╝  ██╔══╝  ██╔══██╗╚════██║
// ██████╔╝╚██████╔╝██║     ██║     ███████╗██║  ██║███████║
// ╚═════╝  ╚═════╝ ╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝
//

const BufferPool = Pool(16, 16, [*c]IGraphics.Buffer, struct {
    ptr: [*c]IGraphics.Buffer,
});
pub const BufferHandle = BufferPool.Handle;

pub const VertexBufferView = struct {
    location: u64,
    elements: u32,
    stride: u32,
    offset_from_start: u32,
};

pub const IndexBufferView = struct {
    location: u64,
    elements: u32,
    offset_from_start: u32,
    index_type: IGraphics.IndexType,
};

pub fn createUniformBuffer(size: u64, name: []const u8) BufferHandle {
    var desc = std.mem.zeroes(IGraphics.BufferDesc);
    desc.mDescriptors = IGraphics.DescriptorType.DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    desc.mMemoryUsage = IGraphics.ResourceMemoryUsage.RESOURCE_MEMORY_USAGE_CPU_TO_GPU;
    desc.mFlags = IGraphics.BufferCreationFlags.BUFFER_CREATION_FLAG_PERSISTENT_MAP_BIT;
    desc.pName = @ptrCast(name);
    desc.mSize = size;

    var buffer: [*c]IGraphics.Buffer = null;
    IGraphicsTides.addBufferEx(gpu.renderer, @ptrCast(&desc), false, &buffer);

    return gpu.buffers.add(.{ .ptr = buffer }) catch unreachable;
}

pub fn createRawBuffer(size: u64, comptime T: type, bindless: bool, write_access: bool, name: ?[]const u8) BufferHandle {
    var desc = std.mem.zeroes(IGraphics.BufferDesc);
    desc.mDescriptors = .DESCRIPTOR_TYPE_BUFFER_RAW;
    if (write_access) {
        desc.mDescriptors.bits |= IGraphics.DescriptorType.DESCRIPTOR_TYPE_RW_BUFFER_RAW.bits;
    }
    desc.mMemoryUsage = .RESOURCE_MEMORY_USAGE_GPU_ONLY;
    if (name) |n| {
        desc.pName = @ptrCast(n);
    }
    desc.mSize = size;
    desc.mElementCount = @intCast(@divTrunc(size, @sizeOf(T)));

    var buffer: [*c]IGraphics.Buffer = null;
    IGraphicsTides.addBufferEx(gpu.renderer, @ptrCast(&desc), bindless, &buffer);

    return gpu.buffers.add(.{ .ptr = buffer }) catch unreachable;
}

pub fn createIndirectArgsBuffer(size: u64, comptime T: type, name: []const u8) BufferHandle {
    var desc = std.mem.zeroes(IGraphics.BufferDesc);
    desc.mDescriptors.bits = IGraphics.DescriptorType.DESCRIPTOR_TYPE_BUFFER.bits | IGraphics.DescriptorType.DESCRIPTOR_TYPE_RW_BUFFER.bits | IGraphics.DescriptorType.DESCRIPTOR_TYPE_INDIRECT_BUFFER.bits;
    desc.mMemoryUsage = .RESOURCE_MEMORY_USAGE_GPU_ONLY;
    desc.mElementCount = @intCast(@divTrunc(size, @sizeOf(T)));
    desc.mStructStride = @sizeOf(u32);
    desc.mSize = size;
    desc.pName = @ptrCast(name);

    var buffer: [*c]IGraphics.Buffer = null;
    IGraphicsTides.addBufferEx(gpu.renderer, @ptrCast(&desc), false, &buffer);

    return gpu.buffers.add(.{ .ptr = buffer }) catch unreachable;
}

pub fn createIndexBuffer(size: u64, index_type: IGraphics.IndexType, name: []const u8) BufferHandle {
    var desc = std.mem.zeroes(IGraphics.BufferDesc);
    desc.mDescriptors = IGraphics.DescriptorType.DESCRIPTOR_TYPE_INDEX_BUFFER;
    desc.mMemoryUsage = IGraphics.ResourceMemoryUsage.RESOURCE_MEMORY_USAGE_GPU_ONLY;
    desc.pName = @ptrCast(name);
    desc.mSize = size;

    const index_size: u64 = switch (index_type.bits) {
        IGraphics.IndexType.INDEX_TYPE_UINT16.bits => 2,
        IGraphics.IndexType.INDEX_TYPE_UINT32.bits => 4,
        else => @panic("Unsupported index size")
    };
    desc.mElementCount = @intCast(@divTrunc(size, index_size));

    var buffer: [*c]IGraphics.Buffer = null;
    IGraphicsTides.addBufferEx(gpu.renderer, @ptrCast(&desc), false, &buffer);

    return gpu.buffers.add(.{ .ptr = buffer }) catch unreachable;
}

pub fn createReadbackBuffer(size: u64, name: []const u8) BufferHandle {
    var desc = std.mem.zeroes(IGraphics.BufferDesc);
    desc.mDescriptors = .DESCRIPTOR_TYPE_BUFFER;
    desc.mMemoryUsage = .RESOURCE_MEMORY_USAGE_GPU_TO_CPU;
    desc.pName = @ptrCast(name);
    desc.mSize = size;
    desc.mStartState = .RESOURCE_STATE_COPY_DEST;

    var buffer: [*c]IGraphics.Buffer = null;
    IGraphicsTides.addBufferEx(gpu.renderer, @ptrCast(&desc), false, &buffer);
    return gpu.buffers.add(.{ .ptr = buffer }) catch unreachable;
}

pub fn updateUniformBuffer(data: DataSlice, handle: BufferHandle) void {
    const buffer = gpu.buffers.getColumnPtr(handle, .ptr) catch unreachable;
    std.debug.assert(buffer.*.*.bitfield_1.mDescriptors == IGraphics.DescriptorType.DESCRIPTOR_TYPE_UNIFORM_BUFFER.bits);
    std.debug.assert(data.size <= buffer.*.*.bitfield_1.mSize);
    memcpy(@ptrCast(buffer.*.*.pCpuMappedAddress.?), data.data.?, 0, data.size);
}

pub fn updateBuffer(data: DataSlice, dest_offset: u64, handle: BufferHandle) void {
    const buffer = gpu.buffers.getColumnPtr(handle, .ptr) catch unreachable;
    std.debug.assert(data.size <= buffer.*.*.bitfield_1.mSize);

    var upload_context = gpu.upload_ring_buffer.begin(data.size);
    memcpy(@ptrCast(upload_context.buffer.*.pCpuMappedAddress.?), data.data.?, 0, data.size);

    IGraphicsTides.cmdUpdateBufferEx(upload_context.cmd, buffer.*, dest_offset, upload_context.buffer, upload_context.buffer_offset, data.size);

    gpu.upload_ring_buffer.end(&upload_context, true);
}

pub fn getBufferBindlessIndex(handle: BufferHandle) u32 {
    const buffer = gpu.buffers.getColumnPtr(handle, .ptr) catch unreachable;
    return @intCast(buffer.*.*.mDx.mDescriptors);
}

pub fn getBufferGPUAddress(handle: BufferHandle) u64 {
    const buffer = gpu.buffers.getColumnPtr(handle, .ptr) catch unreachable;
    return @intCast(buffer.*.*.mDx.mGpuAddress);
}

// ███████╗██╗    ██╗ █████╗ ██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
// ██╔════╝██║    ██║██╔══██╗██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
// ███████╗██║ █╗ ██║███████║██████╔╝██║     ███████║███████║██║██╔██╗ ██║
// ╚════██║██║███╗██║██╔══██║██╔═══╝ ██║     ██╔══██║██╔══██║██║██║╚██╗██║
// ███████║╚███╔███╔╝██║  ██║██║     ╚██████╗██║  ██║██║  ██║██║██║ ╚████║
// ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝      ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
//

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

pub fn getSwapChainFormat() IGraphics.TinyImageFormat {
    return gpu.swap_chain.*.ppRenderTargets[0].*.mFormat;
}

pub fn getSwapChainBufferHandle() RenderTargetHandle {
    return gpu.swap_chain_image_handle;
}

// ██████╗ ███████╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗ ██████╗ ██████╗     ███████╗███████╗████████╗███████╗
// ██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██╔════╝
// ██║  ██║█████╗  ███████╗██║     ██████╔╝██║██████╔╝   ██║   ██║   ██║██████╔╝    ███████╗█████╗     ██║   ███████╗
// ██║  ██║██╔══╝  ╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   ██║   ██║██╔══██╗    ╚════██║██╔══╝     ██║   ╚════██║
// ██████╔╝███████╗███████║╚██████╗██║  ██║██║██║        ██║   ╚██████╔╝██║  ██║    ███████║███████╗   ██║   ███████║
// ╚═════╝ ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝   ╚══════╝
//

pub const DescriptorSpace = enum {
    per_draw,
    per_batch,
    per_frame,
    persistent,
    persistent_sampler,
};

pub const ResourceType = enum {
    buffer,
    texture,
    sampler,
    acceleration_structure,
};

pub const ResourceMapping = struct {
    hash: HashKey,
    resource_type: ResourceType,
    index: u32,
};

pub const DescriptorMappings = struct {
    resources_count: u32,
    resource_mappings: [IGraphicsTides.TIDES_SPACE_DESCRIPTORS_MAX_COUNT]ResourceMapping,
};

pub const DescriptorSetsMappings = struct {
    descriptor_mappings: [IGraphicsTides.TIDES_DESCRIPTOR_SPACES_COUNT]DescriptorMappings,
};

pub const ResourceBindingType = enum {
    buffer,
    render_texture,
    render_target,
    texture,
    sampler,
};

pub const ResourceBindingDesc = struct {
    name: []const u8,
    binding_type: ResourceBindingType,
    render_texture_handle: ?RenderTextureHandle = null,
    render_target_handle: ?RenderTargetHandle = null,
    buffer_handle: ?BufferHandle = null,
    static_sampler_handle: ?StaticSamplerHandle = null,
};

const DescriptorSetPool = Pool(16, 16, [*c]IGraphics.DescriptorSet, struct {
    ptr: [*c]IGraphics.DescriptorSet,
});
pub const DescriptorSetHandle = DescriptorSetPool.Handle;

pub const updateDescriptorSetsFn = ?*const fn () void;

pub fn registerUpdateDescriptorSetFn(update_descriptor_sets_fn: updateDescriptorSetsFn) void {
    std.debug.assert(gpu.update_descriptor_sets_fn == null);
    gpu.update_descriptor_sets_fn = update_descriptor_sets_fn;
}

pub fn createDescriptorSets(shader_handle: ShaderHandle) !struct{
    per_draw: DescriptorSetHandle,
    per_batch: DescriptorSetHandle,
    per_frame: DescriptorSetHandle,
    persistent: DescriptorSetHandle,
    persistent_samplers: DescriptorSetHandle,
} {
    const descriptors = gpu.shaders.getColumnPtr(shader_handle, .descriptors) catch unreachable;

    var per_draw_handle: DescriptorSetHandle = DescriptorSetHandle.nil;
    var per_batch_handle: DescriptorSetHandle = DescriptorSetHandle.nil;
    var per_frame_handle: DescriptorSetHandle = DescriptorSetHandle.nil;
    var persistent_handle: DescriptorSetHandle = DescriptorSetHandle.nil;
    var persistent_samplers_handle: DescriptorSetHandle = DescriptorSetHandle.nil;

    if (descriptors.pSpaceDescriptors[0].mDescriptorsCount > 0) {
        const space_descriptors = &descriptors.pSpaceDescriptors[0];
        var desc = std.mem.zeroes(IGraphics.DescriptorSetDesc);
        desc.mIndex = @intFromEnum(DescriptorSpace.per_draw);
        desc.mDescriptorCount = space_descriptors.mDescriptorsCount;
        desc.mMaxSets = frames_in_flight_count;
        desc.pDescriptors = &space_descriptors.pDescriptors;

        var descriptor_set: [*c]IGraphics.DescriptorSet = null;
        IGraphics.addDescriptorSet(gpu.renderer, &desc, &descriptor_set);

        per_draw_handle = gpu.descriptor_sets.add(.{ .ptr = descriptor_set }) catch unreachable;
    }

    if (descriptors.pSpaceDescriptors[1].mDescriptorsCount > 0) {
        const space_descriptors = &descriptors.pSpaceDescriptors[1];
        var desc = std.mem.zeroes(IGraphics.DescriptorSetDesc);
        desc.mIndex = @intFromEnum(DescriptorSpace.per_batch);
        desc.mDescriptorCount = space_descriptors.mDescriptorsCount;
        desc.mMaxSets = frames_in_flight_count;
        desc.pDescriptors = &space_descriptors.pDescriptors;

        var descriptor_set: [*c]IGraphics.DescriptorSet = null;
        IGraphics.addDescriptorSet(gpu.renderer, &desc, &descriptor_set);

        per_batch_handle = gpu.descriptor_sets.add(.{ .ptr = descriptor_set }) catch unreachable;
    }

    if (descriptors.pSpaceDescriptors[2].mDescriptorsCount > 0) {
        const space_descriptors = &descriptors.pSpaceDescriptors[2];
        var desc = std.mem.zeroes(IGraphics.DescriptorSetDesc);
        desc.mIndex = @intFromEnum(DescriptorSpace.per_frame);
        desc.mDescriptorCount = space_descriptors.mDescriptorsCount;
        desc.mMaxSets = frames_in_flight_count;
        desc.pDescriptors = &space_descriptors.pDescriptors;

        var descriptor_set: [*c]IGraphics.DescriptorSet = null;
        IGraphics.addDescriptorSet(gpu.renderer, &desc, &descriptor_set);

        per_frame_handle = gpu.descriptor_sets.add(.{ .ptr = descriptor_set }) catch unreachable;
    }

    if (descriptors.pSpaceDescriptors[3].mDescriptorsCount > 0) {
        const space_descriptors = &descriptors.pSpaceDescriptors[3];
        var desc = std.mem.zeroes(IGraphics.DescriptorSetDesc);
        desc.mIndex = @intFromEnum(DescriptorSpace.persistent);
        desc.mDescriptorCount = space_descriptors.mDescriptorsCount;
        desc.mMaxSets = 1;
        desc.pDescriptors = &space_descriptors.pDescriptors;

        var descriptor_set: [*c]IGraphics.DescriptorSet = null;
        IGraphics.addDescriptorSet(gpu.renderer, &desc, &descriptor_set);

        persistent_handle = gpu.descriptor_sets.add(.{ .ptr = descriptor_set }) catch unreachable;
    }

    if (descriptors.pSpaceDescriptors[4].mDescriptorsCount > 0) {
        const space_descriptors = &descriptors.pSpaceDescriptors[4];
        var desc = std.mem.zeroes(IGraphics.DescriptorSetDesc);
        desc.mIndex = @intFromEnum(DescriptorSpace.persistent_sampler);
        desc.mDescriptorCount = space_descriptors.mDescriptorsCount;
        desc.mMaxSets = 1;
        desc.pDescriptors = &space_descriptors.pDescriptors;

        var descriptor_set: [*c]IGraphics.DescriptorSet = null;
        IGraphics.addDescriptorSet(gpu.renderer, &desc, &descriptor_set);

        persistent_samplers_handle = gpu.descriptor_sets.add(.{ .ptr = descriptor_set }) catch unreachable;
    }

    return .{
        .per_draw = per_draw_handle,
        .per_batch = per_batch_handle,
        .per_frame = per_frame_handle,
        .persistent = persistent_handle,
        .persistent_samplers = persistent_samplers_handle,
    };
}

pub fn updateDescriptorSet(descs: []const ResourceBindingDesc, descriptor_set_space: DescriptorSpace, descriptor_set_index: u32, shader_handle: ShaderHandle, descriptor_set_handle: DescriptorSetHandle) void {
    var descriptor_data: [IGraphicsTides.TIDES_SPACE_DESCRIPTORS_MAX_COUNT]IGraphics.DescriptorData = undefined;
    std.debug.assert(descs.len <= IGraphicsTides.TIDES_SPACE_DESCRIPTORS_MAX_COUNT);

    const descriptor_sets_mappings = gpu.shaders.getColumnPtr(shader_handle, .descriptor_sets_mappings) catch unreachable;
    const descriptor_mappings = descriptor_sets_mappings.descriptor_mappings[@intFromEnum(descriptor_set_space)];

    for (descs, 0..) |desc, desc_index| {
        const resource_hash = HashKey.generate(desc.name);
        var resource_index: u32 = std.math.maxInt(u32);
        for (descriptor_mappings.resource_mappings) |resource_mapping| {
            if (resource_mapping.hash.key == resource_hash.key) {
                resource_index = resource_mapping.index;
                break;
            }
        }

        if (resource_index == std.math.maxInt(u32)) {
            std.log.debug("Failed to match descriptor for resource {s}", .{desc.name});
        }

        std.debug.assert(resource_index != std.math.maxInt(u32));
        descriptor_data[desc_index] = std.mem.zeroes(IGraphics.DescriptorData);
        descriptor_data[desc_index].bitfield_2 = .{ .mArrayOffset = 0, .mIndex = @intCast(resource_index) };

        switch (desc.binding_type) {
            .buffer => {
                const buffer = gpu.buffers.getColumnPtr(desc.buffer_handle.?, .ptr) catch unreachable;
                descriptor_data[desc_index].__union_field3.ppBuffers = @ptrCast(buffer);
            },
            .sampler => {
                const sampler = gpu.static_samplers.getColumnPtr(desc.static_sampler_handle.?, .ptr) catch unreachable;
                descriptor_data[desc_index].__union_field3.ppSamplers = @ptrCast(sampler);
            },
            .render_target => {
                const render_target = gpu.render_targets.getColumnPtr(desc.render_target_handle.?, .ptr) catch unreachable;
                descriptor_data[desc_index].__union_field3.ppTextures = @ptrCast(&render_target.*.*.pTexture);
            },
            .render_texture => {
                const render_texture = gpu.render_textures.getColumnPtr(desc.render_texture_handle.?, .ptr) catch unreachable;
                descriptor_data[desc_index].__union_field3.ppTextures = @ptrCast(render_texture);
            },
            else => {
                @panic("Unsupported");
            },
        }
    }

    const descriptor_set = gpu.descriptor_sets.getColumnPtr(descriptor_set_handle, .ptr) catch unreachable;
    IGraphics.updateDescriptorSet(gpu.renderer, descriptor_set_index, descriptor_set.*, @intCast(descs.len), @ptrCast(&descriptor_data));
}

//  ██████╗ ██████╗ ███╗   ███╗███╗   ███╗ █████╗ ███╗   ██╗██████╗ ███████╗
// ██╔════╝██╔═══██╗████╗ ████║████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝
// ██║     ██║   ██║██╔████╔██║██╔████╔██║███████║██╔██╗ ██║██║  ██║███████╗
// ██║     ██║   ██║██║╚██╔╝██║██║╚██╔╝██║██╔══██║██║╚██╗██║██║  ██║╚════██║
// ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║██████╔╝███████║
//  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝
//

pub const BufferBarrier = struct {
    buffer_handle: BufferHandle,
    current_state: IGraphics.ResourceState,
    new_state: IGraphics.ResourceState,
};

pub const RenderTargetBarrier = struct {
    render_target_handle: RenderTargetHandle,
    current_state: IGraphics.ResourceState,
    new_state: IGraphics.ResourceState,
};

pub const TextureBarrier = struct {
    render_texture_handle: ?RenderTextureHandle = null,
    current_state: IGraphics.ResourceState,
    new_state: IGraphics.ResourceState,
};

pub const BindRenderTarget = struct {
    render_target_handle: RenderTargetHandle,
    load_action: IGraphics.LoadActionType,
    use_array_slice: bool = false,
    array_slice: u32 = 1,
};

pub fn cmdResourceBarrier(buffer_barriers: ?[]BufferBarrier, texture_barriers: ?[]TextureBarrier, render_target_barriers: ?[]RenderTargetBarrier) void {
    const barriers_count_max = 16;
    var zf_buffer_barriers: [barriers_count_max]IGraphics.BufferBarrier = undefined;
    var zf_render_target_barriers: [barriers_count_max]IGraphics.RenderTargetBarrier = undefined;
    var zf_texture_barriers: [barriers_count_max]IGraphics.TextureBarrier = undefined;

    if (buffer_barriers) |barriers| {
        std.debug.assert(barriers.len <= barriers_count_max);

        for (barriers, 0..) |barrier, i| {
            zf_buffer_barriers[i] = std.mem.zeroes(IGraphics.BufferBarrier);
            zf_buffer_barriers[i].mCurrentState = barrier.current_state;
            zf_buffer_barriers[i].mNewState = barrier.new_state;

            const buffer = gpu.buffers.getColumnPtr(barrier.buffer_handle, .ptr) catch unreachable;
            zf_buffer_barriers[i].pBuffer = buffer.*;
        }
    }

    if (texture_barriers) |barriers| {
        std.debug.assert(barriers.len <= barriers_count_max);

        for (barriers, 0..) |barrier, i| {
            zf_texture_barriers[i] = std.mem.zeroes(IGraphics.TextureBarrier);
            zf_texture_barriers[i].mCurrentState = barrier.current_state;
            zf_texture_barriers[i].mNewState = barrier.new_state;

            var texture: *[*c]IGraphics.Texture = undefined;
            if (barrier.render_texture_handle) |render_texture_handle| {
                texture = gpu.render_textures.getColumnPtr(render_texture_handle, .ptr) catch unreachable;
                zf_texture_barriers[i].pTexture = texture.*;
            }
        }
    }

    if (render_target_barriers) |barriers| {
        std.debug.assert(barriers.len <= barriers_count_max);

        for (barriers, 0..) |barrier, i| {
            zf_render_target_barriers[i] = std.mem.zeroes(IGraphics.RenderTargetBarrier);
            zf_render_target_barriers[i].mCurrentState = barrier.current_state;
            zf_render_target_barriers[i].mNewState = barrier.new_state;

            const render_target = gpu.render_targets.getColumnPtr(barrier.render_target_handle, .ptr) catch unreachable;
            zf_render_target_barriers[i].pRenderTarget = render_target.*;
        }
    }

    IGraphics.cmdResourceBarrier(
        gpu.cmds[gpu.frame_index],
        if (buffer_barriers) |barriers| @intCast(barriers.len) else 0,
        if (buffer_barriers) |_| @ptrCast(&zf_buffer_barriers) else null,
        if (texture_barriers) |barriers| @intCast(barriers.len) else 0,
        if (texture_barriers) |_| @ptrCast(&zf_texture_barriers) else null,
        if (render_target_barriers) |barriers| @intCast(barriers.len) else 0,
        if (render_target_barriers) |_| @ptrCast(&zf_render_target_barriers) else null
    );
}

pub fn cmdBindRenderTargets(bind_render_targets: []BindRenderTarget) void {
    const render_targets_count_max = 8;
    std.debug.assert(bind_render_targets.len <= render_targets_count_max);

    var bind_render_targets_desc = std.mem.zeroes(IGraphics.BindRenderTargetsDesc);
    bind_render_targets_desc.mRenderTargetCount = @intCast(bind_render_targets.len);

    for (bind_render_targets, 0..) |bind_render_target, i| {
        const render_target = gpu.render_targets.getColumnPtr(bind_render_target.render_target_handle, .ptr) catch unreachable;
        const render_target_desc = gpu.render_targets.getColumnPtr(bind_render_target.render_target_handle, .desc) catch unreachable;
        if (render_target_desc.*.mFormat == .D32_SFLOAT) {
            std.debug.assert(i == bind_render_targets.len - 1);
            bind_render_targets_desc.mDepthStencil = std.mem.zeroes(IGraphics.BindDepthTargetDesc);
            bind_render_targets_desc.mDepthStencil.pDepthStencil = render_target.*;
            bind_render_targets_desc.mDepthStencil.mLoadAction = bind_render_target.load_action;
            bind_render_targets_desc.mDepthStencil.mArraySlice = bind_render_target.array_slice;
            bind_render_targets_desc.mDepthStencil.bitfield_1.mUseArraySlice = if (bind_render_target.use_array_slice) 1 else 0;
            bind_render_targets_desc.mRenderTargetCount -= 1;
        } else {
            bind_render_targets_desc.mRenderTargets[i] = std.mem.zeroes(IGraphics.BindRenderTargetDesc);
            bind_render_targets_desc.mRenderTargets[i].pRenderTarget = render_target.*;
            bind_render_targets_desc.mRenderTargets[i].mLoadAction = bind_render_target.load_action;
            bind_render_targets_desc.mRenderTargets[i].mArraySlice = bind_render_target.array_slice;
            bind_render_targets_desc.mRenderTargets[i].bitfield_1.mUseArraySlice = if (bind_render_target.use_array_slice) 1 else 0;
        }
    }

    IGraphics.cmdBindRenderTargets(gpu.cmds[gpu.frame_index], &bind_render_targets_desc);
}

pub fn cmdBindPipeline(handle: PsoHandle) void {
    const pipeline = gpu.psos.getColumnPtr(handle, .ptr) catch unreachable;
    IGraphics.cmdBindPipeline(gpu.cmds[gpu.frame_index], pipeline.*);
}

pub fn cmdBindDescriptorSet(frame_index: u32, descriptor_set_handle: DescriptorSetHandle) void {
    const descriptor_set = gpu.descriptor_sets.getColumnPtr(descriptor_set_handle, .ptr) catch unreachable;
    IGraphics.cmdBindDescriptorSet(gpu.cmds[gpu.frame_index], frame_index, descriptor_set.*);
}

pub fn cmdSetDefaultViewportAndScissor(width: u32, height: u32) void {
    IGraphics.cmdSetViewport(gpu.cmds[gpu.frame_index], 0.0, 0.0, @floatFromInt(width), @floatFromInt(height), 0.0, 1.0);
    IGraphics.cmdSetScissor(gpu.cmds[gpu.frame_index], 0, 0, width, height);
}

pub fn cmdBindIndexBuffer(handle: BufferHandle, index_type: IndexType) void {
    const buffer = gpu.buffers.getColumnPtr(handle, .ptr) catch unreachable;
    IGraphics.cmdBindIndexBuffer(gpu.cmds[gpu.frame_index], buffer.*, @intCast(index_type.bits), 0);
}

pub fn cmdDraw(vertex_count: u32, first_vertex: u32) void {
    IGraphics.cmdDraw(gpu.cmds[gpu.frame_index], vertex_count, first_vertex);
}

pub fn cmdDrawIndexedInstanced(index_count: u32, first_index: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    IGraphics.cmdDrawIndexedInstanced(gpu.cmds[gpu.frame_index], index_count, first_index, instance_count, first_vertex, first_instance);
}

pub fn cmdExecuteIndirect(argument_type: IndirectArgumentType, max_command_count: u32, indirect_buffer_handle: BufferHandle, buffer_offset: u64, counter_buffer_handle: BufferHandle, counter_buffer_offset: u64) void {
    const buffer = gpu.buffers.getColumnPtr(indirect_buffer_handle, .ptr) catch unreachable;
    var counter_buffer: [*c]IGraphics.Buffer = null;
    if (counter_buffer_handle.id != BufferHandle.nil.id) {
        const counter_buffer_ptr = gpu.buffers.getColumnPtr(counter_buffer_handle, .ptr) catch unreachable;
        counter_buffer = counter_buffer_ptr.*;
    }
    IGraphics.cmdExecuteIndirect(gpu.cmds[gpu.frame_index], argument_type, @intCast(max_command_count), buffer.*, buffer_offset, counter_buffer, counter_buffer_offset);
}

pub fn cmdDispatch(group_count_x: u32, group_count_y: u32, group_count_z: u32) void {
    IGraphics.cmdDispatch(gpu.cmds[gpu.frame_index], group_count_x, group_count_y, group_count_z);
}

// ██╗   ██╗██████╗ ██╗      ██████╗  █████╗ ██████╗ ███████╗
// ██║   ██║██╔══██╗██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝
// ██║   ██║██████╔╝██║     ██║   ██║███████║██║  ██║███████╗
// ██║   ██║██╔═══╝ ██║     ██║   ██║██╔══██║██║  ██║╚════██║
// ╚██████╔╝██║     ███████╗╚██████╔╝██║  ██║██████╔╝███████║
//  ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝
//

// Ported from: https://github.com/TheRealMJP/DXRPathTracer/blob/master/SampleFramework12/v1.02/Graphics/DX12_Upload.h

const UploadContext = struct {
    cmd: [*c]IGraphics.Cmd = null,
    buffer: [*c]IGraphics.Buffer = null,
    buffer_offset: u64 = 0,
    resource_offset: u64 = 0,
    submission: *UploadSubmission = undefined,
};

fn endFrameUpload() void {
    gpu.upload_ring_buffer.tryClearPending();

    gpu.upload_queue.syncDependentQueue(gpu.graphics_queue);
}

fn resourceUploadBegin(size: u64) UploadContext {
    return gpu.upload_ring_buffer.begin(size);
}

fn resourceUploadEnd(upload_context: *UploadContext, sync_on_graphics_queue: bool) void {
    gpu.upload_ring_buffer.end(upload_context, sync_on_graphics_queue);
}

const UploadQueue = struct {
    queue: [*c]IGraphics.Queue = null,
    fence: [*c]IGraphics.Fence = null,
    wait_count: u64 = 0,
    mutex: std.Thread.Mutex = .{},

    pub fn init() UploadQueue {
        var upload_queue = UploadQueue{};

        var queue_desc = std.mem.zeroes(IGraphics.QueueDesc);
        queue_desc.mType = .QUEUE_TYPE_TRANSFER; // Copy queue
        queue_desc.mFlag = .QUEUE_FLAG_NONE;
        queue_desc.mPriority = .QUEUE_PRIORITY_NORMAL;
        IGraphics.initQueue(gpu.renderer, &queue_desc, &upload_queue.queue);

        IGraphics.initFence(gpu.renderer, &upload_queue.fence);

        return upload_queue;
    }

    pub fn exit(self: *UploadQueue) void {
        IGraphics.exitFence(gpu.renderer, self.fence);
        IGraphics.exitQueue(gpu.renderer, self.queue);
    }

    pub fn syncDependentQueue(self: *UploadQueue, other_queue: [*c]IGraphics.Queue) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.wait_count > 0) {
            IGraphicsTides.queueWaitForFence(other_queue, self.fence);
            self.wait_count = 0;
        }

    }

    pub fn submitCmdList(self: *UploadQueue, cmd: [*c]IGraphics.Cmd, sync_on_dependent_queue: bool) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var submit_desc = std.mem.zeroes(IGraphics.QueueSubmitDesc);
        submit_desc.mCmdCount = 1;
        submit_desc.ppCmds = @constCast(&cmd);
        submit_desc.pSignalFence = self.fence;
        IGraphics.queueSubmit(self.queue, &submit_desc);

        if (sync_on_dependent_queue) {
            self.wait_count += 1;
        }

        // TODO: Figure out how to use The-Forge's FENCE_STATUS instead
        return self.fence.*.mDx.mFenceValue;
    }

    pub fn flush(self: *UploadQueue) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        IGraphics.waitForFences(gpu.renderer, 1, &self.fence);
    }
};

const UploadSubmission = struct {
    cmd_pool: [*c]IGraphics.CmdPool = null,
    cmd: [*c]IGraphics.Cmd = null,
    offset: u64 = 0,
    size: u64 = 0,
    fence_value: u64 = 0,
    padding: u64 = 0,

    pub fn reset(self: *UploadSubmission) void {
        self.offset = 0;
        self.size = 0;
        self.fence_value = 0;
        self.padding = 0;
    }
};

const UploadRingBuffer = struct {
    pub const submissions_max_count = 16;

    submissions: [submissions_max_count]UploadSubmission = undefined,
    submission_start: u64 = 0,
    submission_used: u64 = 0,

    // CPU-Writable upload buffer
    buffer_size: u64 = 0,
    buffer: [*c]IGraphics.Buffer = null,
    buffer_start: u64 = 0,
    buffer_used: u64 = 0,

    mutex: std.Thread.Mutex = .{},

    submit_queue: *UploadQueue = undefined,

    pub fn init(upload_queue: *UploadQueue) UploadRingBuffer {
        var upload_ring_buffer = UploadRingBuffer{};
        upload_ring_buffer.submit_queue = upload_queue;

        var cmd_pool_desc = std.mem.zeroes(IGraphics.CmdPoolDesc);
        cmd_pool_desc.mTransient = false;
        cmd_pool_desc.pQueue = upload_ring_buffer.submit_queue.queue;

        for (0..submissions_max_count) |i| {
            IGraphics.initCmdPool(gpu.renderer, &cmd_pool_desc, &upload_ring_buffer.submissions[i].cmd_pool);
            var cmd_desc = std.mem.zeroes(IGraphics.CmdDesc);
            cmd_desc.pPool = upload_ring_buffer.submissions[i].cmd_pool;
            IGraphics.initCmd(gpu.renderer, &cmd_desc, &upload_ring_buffer.submissions[i].cmd);
        }

        upload_ring_buffer.resize(64 * 1024 * 1024);

        return upload_ring_buffer;
    }

    pub fn exit(self: *UploadRingBuffer) void {
        IGraphicsTides.removeBufferEx(gpu.renderer, self.buffer);
        for (0..submissions_max_count) |i| {
            IGraphics.exitCmd(gpu.renderer, self.submissions[i].cmd);
            IGraphics.exitCmdPool(gpu.renderer, self.submissions[i].cmd_pool);
        }
    }

    pub fn resize(self: *UploadRingBuffer, size: u64) void {
        if (self.buffer_size > 0) {
            IGraphicsTides.removeBufferEx(gpu.renderer, self.buffer);
        }

        self.buffer_size = size;

        var desc = std.mem.zeroes(IGraphics.BufferDesc);
        desc.mDescriptors = IGraphics.DescriptorType.DESCRIPTOR_TYPE_UNDEFINED;
        desc.mMemoryUsage = IGraphics.ResourceMemoryUsage.RESOURCE_MEMORY_USAGE_CPU_TO_GPU;
        desc.mFlags = IGraphics.BufferCreationFlags.BUFFER_CREATION_FLAG_PERSISTENT_MAP_BIT;
        desc.pName = "Upload Ring Buffer";
        desc.mSize = size;
        IGraphicsTides.addBufferEx(gpu.renderer, &desc, false, @ptrCast(&self.buffer));
    }

    pub fn clearPendingUploads(self: *UploadRingBuffer, wait_count: u64) void {
        const start = self.submission_start;
        const used = self.submission_used;

        for (0..used) |i| {
            const index = (start + i) % submissions_max_count;
            var submission = &self.submissions[index];
            std.debug.assert(submission.size > 0);
            std.debug.assert(self.buffer_used >= submission.size);

            // If the submission hasn't been sent to the GPU yet we can't wait for it
            // TODO: Figure out how to use The-Forge's FENCE_STATUS instead
            if (submission.fence_value == std.math.maxInt(u64)) {
                break;
            }

            if (i < wait_count) {
                IGraphics.waitForFences(gpu.renderer, 1, &self.submit_queue.fence);
            }

            // TODO: Figure out how to use The-Forge's FENCE_STATUS instead
            if (self.submit_queue.fence.*.mDx.mFenceValue >= submission.fence_value) {
                self.submission_start = (self.submission_start + 1) % submissions_max_count;
                self.submission_used -= 1;
                self.buffer_start = (self.buffer_start + submission.padding) % self.buffer_size;
                std.debug.assert(submission.offset == self.buffer_start);
                std.debug.assert(self.buffer_start + submission.size <= self.buffer_size);
                self.buffer_start = (self.buffer_start + submission.size) % self.buffer_size;
                self.buffer_used -= (submission.size + submission.padding);
                submission.reset();

                if (self.buffer_used == 0) {
                    self.buffer_start = 0;
                }
            } else {
                // We don't want to retire our submissions out of allocation order, because
                // the ring buffer logic above will move the tail position forward (we don't
                // allow holes in the ring buffer). Submitting out-of-order should still be
                // ok though as long as we retire in-order.
                break;
            }
        }
    }

    pub fn flush(self: *UploadRingBuffer) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.submission_used > 0) {
            self.clearPendingUploads(std.math.maxInt(u64));
        }
    }

    pub fn tryClearPending(self: *UploadRingBuffer) void {
        // TODO: Replace with std.Thread.Mutex
        if (self.mutex.tryLock()) {
            self.clearPendingUploads(0);
            self.mutex.unlock();
        }
    }

    pub fn allocateSubmission(self: *UploadRingBuffer, size: u64) ?*UploadSubmission {
        std.debug.assert(self.submission_used <= submissions_max_count);
        if (self.submission_used == submissions_max_count) {
            return null;
        }

        const submission_index = (self.submission_start + self.submission_used) % submissions_max_count;
        std.debug.assert(self.submissions[submission_index].size == 0);

        std.debug.assert(self.buffer_used <= self.buffer_size);
        if (size > (self.buffer_size - self.buffer_used)) {
            return null;
        }

        const buffer_start = self.buffer_start;
        const buffer_end = self.buffer_start + self.buffer_used;
        var allocation_offset: u64 = std.math.maxInt(u64);
        var padding: u64 = 0;
        if (buffer_end < self.buffer_size) {
            const end_amt = self.buffer_size - buffer_end;
            if (end_amt >= size) {
                allocation_offset = buffer_end;
            } else if (buffer_start >= size) {
                // Wrap around to the beginning
                allocation_offset = 0;
                self.buffer_used += end_amt;
                padding = end_amt;
            }
        } else {
            const wrappend_end = buffer_end % self.buffer_size;
            if ((buffer_start - wrappend_end) >= size) {
                allocation_offset = wrappend_end;
            }
        }

        if (allocation_offset == std.math.maxInt(u64)) {
            return null;
        }

        self.submission_used += 1;
        self.buffer_used += size;

        var upload_submission = &self.submissions[submission_index];
        upload_submission.offset = allocation_offset;
        upload_submission.size = size;
        upload_submission.fence_value = std.math.maxInt(u64);
        upload_submission.padding = padding;

        return upload_submission;
    }

    pub fn begin(self: *UploadRingBuffer, size: u64) UploadContext {
        std.debug.assert(size > 0);
        // D3D12_TEXTURE_DATA_PLACEMENT_ALIGNMENT
        const aligned_size = alignTo(u64, size, 512);

        if (aligned_size > self.buffer_size) {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.submission_used > 0) {
                self.clearPendingUploads(std.math.maxInt(u64));
            }

            self.resize(aligned_size);
        }

        var upload_submission: ?*UploadSubmission = null;

        {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.clearPendingUploads(0);

            upload_submission = self.allocateSubmission(aligned_size);
            while (upload_submission == null) {
                self.clearPendingUploads(1);
                upload_submission = self.allocateSubmission(aligned_size);
            }
        }

        IGraphics.resetCmdPool(gpu.renderer, upload_submission.?.cmd_pool);
        // NOTE: Since this is a cmd list for a copy queue, beginCmd will only reset the cmd list
        IGraphics.beginCmd(upload_submission.?.cmd);

        var upload_context: UploadContext = .{};
        upload_context.cmd = upload_submission.?.cmd;
        upload_context.buffer = self.buffer;
        // NOTE: This pointer arithmetics happens further down the pipe
        // upload_context.buffer_offset = @intFromPtr(self.buffer.*.pCpuMappedAddress.?) + upload_submission.?.offset;
        upload_context.buffer_offset = upload_submission.?.offset;
        upload_context.resource_offset = upload_submission.?.offset;
        upload_context.submission = upload_submission.?;

        return upload_context;
    }

    pub fn end(self: *UploadRingBuffer, upload_context: *UploadContext, sync_on_dependent_queue: bool) void {
        std.debug.assert(upload_context.cmd != null);
        // std.debug.assert(upload_context.submission != null);

        // Kick-off the copy command
        IGraphics.endCmd(upload_context.cmd);
        upload_context.submission.fence_value = self.submit_queue.submitCmdList(upload_context.submission.cmd, sync_on_dependent_queue);

        upload_context.* = .{};
    }
};

// ██████╗ ██████╗  ██████╗ ███████╗██╗██╗     ███████╗██████╗
// ██╔══██╗██╔══██╗██╔═══██╗██╔════╝██║██║     ██╔════╝██╔══██╗
// ██████╔╝██████╔╝██║   ██║█████╗  ██║██║     █████╗  ██████╔╝
// ██╔═══╝ ██╔══██╗██║   ██║██╔══╝  ██║██║     ██╔══╝  ██╔══██╗
// ██║     ██║  ██║╚██████╔╝██║     ██║███████╗███████╗██║  ██║
// ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
//

// Ported from: https://github.com/TheRealMJP/DXRPathTracer/blob/master/SampleFramework12/v1.02/Graphics/Profiler.h

pub fn startGpuProfile(name: []const u8) usize {
    return gpu.profiler.startProfile(name);
}

pub fn endGpuProfile(profile_index: usize) void {
    gpu.profiler.endProfile(profile_index);
}

pub fn getFrameAvgTimeMs() f32 {
    return getProfilerAvgTimeMs(gpu.frame_profiler_index);
}

pub fn getProfilerAvgTimeMs(profiler_index: usize) f32 {
    const profile_data = gpu.profiler.profiles.items[profiler_index];
    var sum: f64 = 0;

    for(0..ProfileData.filter_size) |i| {
        sum += profile_data.time_samples[i];
    }
    sum /= 64.0;
    return @floatCast(sum);
}

pub const Profiler = struct {
    const profiles_max_count: usize = 64;
    const invalid_profile_index: usize = std.math.maxInt(usize);

    profiles: std.ArrayList(ProfileData),
    query_pools: [frames_in_flight_count][*c]IGraphics.QueryPool,

    pub fn init(self: *Profiler, allocator: std.mem.Allocator) void {
        self.profiles = std.ArrayList(ProfileData).init(allocator);

        for (0..frames_in_flight_count) |frame_index| {
            const query_pool_desc = IGraphics.QueryPoolDesc{
                .pName = "GPU Profiler",
                .mType = .QUERY_TYPE_TIMESTAMP,
                .mQueryCount = profiles_max_count,
                .mNodeIndex = 0,
            };

            IGraphics.initQueryPool(gpu.renderer, @ptrCast(&query_pool_desc), &self.query_pools[frame_index]);
        }
    }

    pub fn shutdown(self: *Profiler) void {
        for (0..frames_in_flight_count) |frame_index| {
            IGraphics.exitQueryPool(gpu.renderer, self.query_pools[frame_index]);
        }
        self.profiles.deinit();
        self.profiles_count = 0;
    }

    pub fn startProfile(self: *Profiler, name: []const u8) usize {
        const hash = HashKey.generate(name);

        var profile_index: usize = invalid_profile_index;
        for (self.profiles.items, 0..) |profile, index| {
            if (profile.hash.key == hash.key) {
                profile_index = index;
                break;
            }
        }

        if (profile_index == invalid_profile_index) {
            std.debug.assert(self.profiles.items.len < profiles_max_count);
            profile_index = self.profiles.items.len;

            var profile = std.mem.zeroes(ProfileData);
            profile.hash = hash;
            memcpy(&profile.name, @ptrCast(&name.ptr), 0, name.len);
            @memset(profile.time_samples[0..], 0);
            self.profiles.append(profile) catch unreachable;
        }

        var profile_data = &self.profiles.items[profile_index];
        std.debug.assert(profile_data.query_started == false);
        std.debug.assert(profile_data.query_finished == false);
        profile_data.active = true;
        profile_data.query_started = true;

        // Insert the start timestamp
        const query_desc = IGraphics.QueryDesc{
            .mIndex = @intCast(profile_index),
        };

        IGraphics.cmdBeginDebugMarker(gpu.cmds[gpu.frame_index], 0.1, 0.8, 0.1, @ptrCast(name[0..]));
        IGraphics.cmdBeginQuery(gpu.cmds[gpu.frame_index], self.query_pools[gpu.frame_index], @constCast(&query_desc));

        return profile_index;
    }

    pub fn endProfile(self: *Profiler, profile_index: usize) void {
        std.debug.assert(profile_index < self.profiles.items.len);

        var profile_data = &self.profiles.items[profile_index];
        std.debug.assert(profile_data.query_started == true);
        std.debug.assert(profile_data.query_finished == false);

        // Insert the end timestamp
        const query_desc = IGraphics.QueryDesc{
            .mIndex = @intCast(profile_index),
        };
        IGraphics.cmdEndQuery(gpu.cmds[gpu.frame_index], self.query_pools[gpu.frame_index], @constCast(&query_desc));

        // Resolve the data
        IGraphics.cmdResolveQuery(gpu.cmds[gpu.frame_index],self.query_pools[gpu.frame_index], query_desc.mIndex, 1);
        IGraphics.cmdEndDebugMarker(gpu.cmds[gpu.frame_index]);

        profile_data.query_started = false;
        profile_data.query_finished = true;
    }

    pub fn endFrame(self: *Profiler) void {
        var timestamp_frequency: f64 = 0;
        IGraphics.getTimestampFrequency(gpu.graphics_queue, @ptrCast(&timestamp_frequency));

        for (self.profiles.items, 0..) |*profile, profile_index| {
            profile.query_finished = false;

            var query_data = std.mem.zeroes(IGraphics.QueryData);
            IGraphics.getQueryData(gpu.renderer, self.query_pools[gpu.frame_index], @intCast(profile_index), @ptrCast(&query_data));

            var time: f64 = 0.0;
            const start_time = query_data.__union_field1.__struct_field3.mBeginTimestamp;
            const end_time = query_data.__union_field1.__struct_field3.mEndTimestamp;
            if (end_time > start_time) {
                const delta = end_time - start_time;
                time = @as(f64, @floatFromInt(delta)) / timestamp_frequency * 1000.0;
            }

            profile.time_samples[profile.current_sample] = time;
            profile.current_sample = (profile.current_sample + 1) % ProfileData.filter_size;

            profile.active = false;
        }
    }
};

const ProfileData = struct {
    pub const filter_size: usize = 64;

    name: [256]u8,
    hash: HashKey,
    query_started: bool,
    query_finished: bool,
    active: bool,
    time_samples: [filter_size]f64 = undefined,
    current_sample: usize,
};

// ██╗   ██╗████████╗██╗██╗     ██╗████████╗██╗███████╗███████╗
// ██║   ██║╚══██╔══╝██║██║     ██║╚══██╔══╝██║██╔════╝██╔════╝
// ██║   ██║   ██║   ██║██║     ██║   ██║   ██║█████╗  ███████╗
// ██║   ██║   ██║   ██║██║     ██║   ██║   ██║██╔══╝  ╚════██║
// ╚██████╔╝   ██║   ██║███████╗██║   ██║   ██║███████╗███████║
//  ╚═════╝    ╚═╝   ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝╚══════╝╚══════╝
//

pub fn memcpy(dst: *anyopaque, src: *const anyopaque, dst_offset: u64, byte_count: u64) void {
    const src_slice = @as([*]const u8, @ptrCast(src))[0..byte_count];
    const dst_slice = @as([*]u8, @ptrCast(dst))[dst_offset..(dst_offset + byte_count)];
    for (src_slice, 0..) |byte, i| {
        dst_slice[i] = byte;
    }
}

inline fn alignTo(comptime T: type, num: T, alignment: T) T {
    std.debug.assert(alignment > 0);
    return @divTrunc(num + alignment - 1, alignment) * alignment;
}

pub inline fn roundUp(comptime T: type, value: T, multiple: T) T {
    return ((value + multiple - 1) / multiple) * multiple;
}
