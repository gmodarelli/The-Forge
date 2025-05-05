const std = @import("std");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");
const zmath = @import("zmath");

pub const Gfx = struct {
    // Static samplers
    linear_repeat_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,
    linear_clamp_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,

    // Shaders
    blit_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    object_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    clear_screen_shader: zf.ShaderHandle = zf.ShaderHandle.nil,

    // PSOs
    blit_pso: zf.PsoHandle = zf.PsoHandle.nil,
    object_pso: zf.PsoHandle = zf.PsoHandle.nil,
    clear_screen_pso: zf.PsoHandle = zf.PsoHandle.nil,

    // Render Targets and Render Textures
    depth_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    scene_color: [zf.frames_in_flight_count]zf.RenderTextureHandle = .{ zf.RenderTextureHandle.nil, zf.RenderTextureHandle.nil },

    // Uniform buffers
    global_frame_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,

    // Geometry buffers
    // TODO: Figure out if we need double-buffering here to be able to stream in meshes
    vertex_buffer: zf.BufferHandle = undefined,
    index_buffer: zf.BufferHandle = undefined,

    // Materials
    blit_material: GfxMaterial = undefined,
    object_material: GfxMaterial = undefined,
    clear_screen_material: GfxMaterial = undefined,
};

pub const Frame = struct {
    view_matrix: [16]f32,
    projection_matrix: [16]f32,
    view_projection_matrix: [16]f32,
    time: f32,
    vertex_buffer_index: u32,
};

// TODO: List all possible passes (eg. default, shadow_caster, gbuffer, etc.)
pub const Pass = enum {
    default,
    gbuffer,
    shadow_caster,
};

pub const GfxMaterialPass = struct {
    pso: zf.PsoHandle,

    per_draw_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    per_batch_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    per_frame_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    persistent_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    persistent_samplers_descriptor_set: [*c]zf.IGraphics.DescriptorSet,

    pass: Pass,
};

const material_passes_max_count: u32 = 8;

pub const GfxMaterial = struct {
    passes: [material_passes_max_count]GfxMaterialPass,
    passes_count: u32,
};

var gfx: *Gfx = undefined;

pub fn main() !void {
    // Create a window
    zglfw.init() catch unreachable;
    defer zglfw.terminate();

    var window_width: c_int = 1920;
    var window_height: c_int = 1080;

    zglfw.windowHint(.client_api, .no_api);
    const window = zglfw.Window.create(window_width, window_height, "Ze-Forge Test", null) catch unreachable;
    defer zglfw.Window.destroy(window);

    const gpu_desc = zf.GpuDesc{
        .graphics_root_signature_path = "shaders/GraphicsRootSignature.rs",
        .compute_root_signature_path = "shaders/ComputeRootSignature.rs",
        .hwnd = zglfw.getWin32Window(window).?,
    };
    zf.initializeGpu(gpu_desc, std.heap.page_allocator) catch unreachable;
    defer zf.shutdownGpu();

    gfx = std.heap.page_allocator.create(Gfx) catch unreachable;
    defer std.heap.page_allocator.destroy(gfx);

    zf.registerUpdateDescriptorSetFn(updateDescriptorSets);

    // Static Samplers
    {
        var sampler_desc = std.mem.zeroes(zf.SamplerDesc);
        sampler_desc.mMinFilter = zf.FilterType.FILTER_LINEAR;
        sampler_desc.mMagFilter = zf.FilterType.FILTER_LINEAR;
        sampler_desc.mMipMapMode = zf.MipMapMode.MIPMAP_MODE_LINEAR;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_REPEAT;
        gfx.linear_repeat_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;

        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        gfx.linear_clamp_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;
    }

    // Shaders
    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/Blit.vert",
                .entry = "FullscreenVertex",
            },
            .pixel = .{
                .path = "shaders/Blit.frag",
                .entry = "BlitFragment",
            },
            .compute = null,
        };
        gfx.blit_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/Object.vert",
                .entry = "ObjectVS",
            },
            .pixel = .{
                .path = "shaders/Object.frag",
                .entry = "ObjectPS",
            },
            .compute = null,
        };
        gfx.object_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{ .compute = .{
            .path = "shaders/ClearScreen.comp",
            .entry = "main",
        }, .vertex = null, .pixel = null };
        gfx.clear_screen_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    // PSOs
    {
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.clear_screen_pso = zf.createPso(pipeline_desc, gfx.clear_screen_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{zf.getSwapChainFormat()};
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_GRAPHICS;
        var graphics_desc = &pipeline_desc.__union_field1.mGraphicsDesc;
        graphics_desc.* = std.mem.zeroes(zf.GraphicsPipelineDesc);
        graphics_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
        graphics_desc.mRenderTargetCount = render_targets.len;
        graphics_desc.pColorFormats = @ptrCast(&render_targets);
        graphics_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        graphics_desc.mSampleQuality = 0;

        var rasterizer_state_desc = std.mem.zeroes(zf.RasterizerStateDesc);
        rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_NONE;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        gfx.blit_pso = zf.createPso(pipeline_desc, gfx.blit_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{zf.getSwapChainFormat()};
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_GRAPHICS;
        var graphics_desc = &pipeline_desc.__union_field1.mGraphicsDesc;
        graphics_desc.* = std.mem.zeroes(zf.GraphicsPipelineDesc);
        graphics_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
        graphics_desc.mRenderTargetCount = render_targets.len;
        graphics_desc.pColorFormats = @ptrCast(&render_targets);
        graphics_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        graphics_desc.mSampleQuality = 0;

        var rasterizer_state_desc = std.mem.zeroes(zf.RasterizerStateDesc);
        rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_BACK;
        rasterizer_state_desc.mFillMode = zf.FillMode.FILL_MODE_SOLID;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        var depth_state_desc = std.mem.zeroes(zf.DepthStateDesc);
        depth_state_desc.mDepthWrite = true;
        depth_state_desc.mDepthTest = true;
        depth_state_desc.mDepthFunc = zf.CompareMode.CMP_GEQUAL;
        graphics_desc.pDepthState = @ptrCast(&depth_state_desc);
        graphics_desc.mDepthStencilFormat = .D32_SFLOAT;

        gfx.object_pso = zf.createPso(pipeline_desc, gfx.object_shader) catch unreachable;
    }

    // Render Targets
    {
        var depth_buffer_desc = std.mem.zeroes(zf.RenderTargetDesc);
        depth_buffer_desc.pName = "Depth Buffer";
        depth_buffer_desc.mArraySize = 1;
        depth_buffer_desc.mClearValue.__struct_field3.depth = 0.0;
        depth_buffer_desc.mClearValue.__struct_field3.stencil = 0;
        depth_buffer_desc.mDepth = 1;
        depth_buffer_desc.mFormat = .D32_SFLOAT;
        depth_buffer_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        depth_buffer_desc.mWidth = @intCast(window_width);
        depth_buffer_desc.mHeight = @intCast(window_height);
        depth_buffer_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        depth_buffer_desc.mSampleQuality = 0;
        depth_buffer_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        gfx.depth_buffer = zf.createRenderTarget(depth_buffer_desc) catch unreachable;
    }

    // Render Textures
    {
        var scene_color_desc = std.mem.zeroes(zf.TextureDesc);
        scene_color_desc.mWidth = @intCast(window_width);
        scene_color_desc.mHeight = @intCast(window_height);
        scene_color_desc.mDepth = 1;
        scene_color_desc.mArraySize = 1;
        scene_color_desc.mMipLevels = 1;
        scene_color_desc.mClearValue.__struct_field1.r = 0.0;
        scene_color_desc.mClearValue.__struct_field1.g = 0.0;
        scene_color_desc.mClearValue.__struct_field1.b = 0.0;
        scene_color_desc.mClearValue.__struct_field1.a = 0.0;
        scene_color_desc.mFormat = .R8G8B8A8_SRGB;
        scene_color_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        scene_color_desc.mDescriptors.bits = zf.DescriptorType.DESCRIPTOR_TYPE_TEXTURE.bits | zf.DescriptorType.DESCRIPTOR_TYPE_RW_TEXTURE.bits;
        scene_color_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        scene_color_desc.mSampleQuality = 0;
        scene_color_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        scene_color_desc.pName = "Scene Color";

        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.scene_color[frame_index] = zf.createRenderTexture(scene_color_desc) catch unreachable;
        }
    }

    // Uniform Buffers
    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.global_frame_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(Frame), "Global Frame Constant Buffer");
        }
    }

    // Geometry Buffers
    {
        gfx.vertex_buffer = zf.createRawBuffer(8 * 64 * 64, f32, true, "Vertex Buffer");
        gfx.index_buffer = zf.createIndexBuffer(8 * 64 * 64, zf.IndexType.INDEX_TYPE_UINT32, "Index Buffer");
    }

    // Clear Screen material example
    {
        gfx.clear_screen_material.passes_count = 1;
        gfx.clear_screen_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.clear_screen_material.passes[0].pass = .default;
        gfx.clear_screen_material.passes[0].pso = gfx.clear_screen_pso;

        gfx.clear_screen_material.passes[0].per_draw_descriptor_set = null;
        gfx.clear_screen_material.passes[0].per_batch_descriptor_set = null;
        gfx.clear_screen_material.passes[0].per_frame_descriptor_set = null;
        gfx.clear_screen_material.passes[0].persistent_descriptor_set = null;
        gfx.clear_screen_material.passes[0].persistent_samplers_descriptor_set = null;

        zf.createDescriptorSets(
            gfx.clear_screen_shader,
            @ptrCast(&gfx.clear_screen_material.passes[0].per_draw_descriptor_set),
            @ptrCast(&gfx.clear_screen_material.passes[0].per_batch_descriptor_set),
            @ptrCast(&gfx.clear_screen_material.passes[0].per_frame_descriptor_set),
            @ptrCast(&gfx.clear_screen_material.passes[0].persistent_descriptor_set),
            @ptrCast(&gfx.clear_screen_material.passes[0].persistent_samplers_descriptor_set)
        ) catch unreachable;
    }

    // Blit material example
    {
        gfx.blit_material.passes_count = 1;
        gfx.blit_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.blit_material.passes[0].pass = .default;
        gfx.blit_material.passes[0].pso = gfx.blit_pso;

        gfx.blit_material.passes[0].per_draw_descriptor_set = null;
        gfx.blit_material.passes[0].per_batch_descriptor_set = null;
        gfx.blit_material.passes[0].per_frame_descriptor_set = null;
        gfx.blit_material.passes[0].persistent_descriptor_set = null;
        gfx.blit_material.passes[0].persistent_samplers_descriptor_set = null;

        zf.createDescriptorSets(
            gfx.blit_shader,
            @ptrCast(&gfx.blit_material.passes[0].per_draw_descriptor_set),
            @ptrCast(&gfx.blit_material.passes[0].per_batch_descriptor_set),
            @ptrCast(&gfx.blit_material.passes[0].per_frame_descriptor_set),
            @ptrCast(&gfx.blit_material.passes[0].persistent_descriptor_set),
            @ptrCast(&gfx.blit_material.passes[0].persistent_samplers_descriptor_set)
        ) catch unreachable;
    }

    // Object material example
    {
        gfx.object_material.passes_count = 1;
        gfx.object_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.object_material.passes[0].pass = .default;
        gfx.object_material.passes[0].pso = gfx.blit_pso;

        gfx.object_material.passes[0].per_draw_descriptor_set = null;
        gfx.object_material.passes[0].per_batch_descriptor_set = null;
        gfx.object_material.passes[0].per_frame_descriptor_set = null;
        gfx.object_material.passes[0].persistent_descriptor_set = null;
        gfx.object_material.passes[0].persistent_samplers_descriptor_set = null;

        zf.createDescriptorSets(
            gfx.object_shader,
            @ptrCast(&gfx.object_material.passes[0].per_draw_descriptor_set),
            @ptrCast(&gfx.object_material.passes[0].per_batch_descriptor_set),
            @ptrCast(&gfx.object_material.passes[0].per_frame_descriptor_set),
            @ptrCast(&gfx.object_material.passes[0].persistent_descriptor_set),
            @ptrCast(&gfx.object_material.passes[0].persistent_samplers_descriptor_set)
        ) catch unreachable;
    }

    updateDescriptorSets();

    var upload_mesh_data = true;

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        const frame_buffer_size = window.getFramebufferSize();
        if (frame_buffer_size[0] != window_width or frame_buffer_size[1] != window_height) {
            window_width = frame_buffer_size[0];
            window_height = frame_buffer_size[1];

            std.log.info(
                "Window resized to {d}x{d}",
                .{ window_width, window_height },
            );

            zf.requestResize();
        }

        const frame_index = zf.frameStart();

        const z_view = zmath.lookAtLh(
            zmath.f32x4(0.0, 0.0, -3.0, 1.0),
            zmath.f32x4(0.0, 0.0, 0.0, 1.0),
            zmath.f32x4(0.0, 1.0, 0.0, 1.0));
        const z_proj = zmath.perspectiveFovLh(
            std.math.degreesToRadians(60.0),
            @as(f32, @floatFromInt(frame_buffer_size[0])) / @as(f32, @floatFromInt(frame_buffer_size[1])),
            0.01,
            100.0);

        var frame = Frame{
            .view_matrix = undefined,
            .projection_matrix = undefined,
            .view_projection_matrix = undefined,
            .time = @floatCast(zglfw.getTime()),
            .vertex_buffer_index = zf.getBufferBindlessIndex(gfx.vertex_buffer),
        };
        zmath.storeMat(&frame.view_matrix, zmath.transpose(z_view));
        zmath.storeMat(&frame.projection_matrix, zmath.transpose(z_proj));
        zmath.storeMat(&frame.view_projection_matrix, zmath.mul(z_view, z_proj));

        const frame_data = zf.DataSlice{
            .data = @ptrCast(&frame),
            .size = @sizeOf(Frame),
        };
        zf.updateUniformBuffer(frame_data, gfx.global_frame_constant_buffers[frame_index]);

        if (upload_mesh_data) {
            const vertices = [_]f32{
                -0.5, -0.5, 0.0,
                -0.5, 0.5, 0.0,
                0.5, 0.5, 0.0,
                0.5, -0.5, 0.0,
            };
            const vertex_data = zf.DataSlice{
                .data = @ptrCast(&vertices),
                .size = @sizeOf(f32) * vertices.len,
            };
            zf.updateBuffer(vertex_data, gfx.vertex_buffer);

            const indices = [_]u32 {
                0, 2, 1,
                0, 3, 2,
            };
            const index_data = zf.DataSlice{
                .data = @ptrCast(&indices),
                .size = @sizeOf(u32) * indices.len,
            };
            zf.updateBuffer(index_data, gfx.index_buffer);
            upload_mesh_data = false;
        }

        // Clear screen: Scene Color
        {
            var texture_barriers = [_]zf.TextureBarrier{
                .{
                    .render_texture_handle = gfx.scene_color[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
            };

            zf.cmdResourceBarrier(null, &texture_barriers, null);
            zf.cmdBindPipeline(gfx.clear_screen_pso);
            zf.cmdBindDescriptorSet(frame_index, gfx.clear_screen_material.passes[0].per_frame_descriptor_set);
            zf.cmdDispacth(@intCast(@divTrunc(frame_buffer_size[0], 8) + 1), @intCast(@divTrunc(frame_buffer_size[1], 8) + 1), 1);

            texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(null, &texture_barriers, null);
        }

        // Blit: Scene Color -> SwapChain Buffer
        {
            const swap_chain_buffer_handle = zf.getSwapChainBufferHandle();
            var render_target_barriers = [_]zf.RenderTargetBarrier{
                .{
                    .render_target_handle = swap_chain_buffer_handle,
                    .current_state = zf.ResourceState.RESOURCE_STATE_PRESENT,
                    .new_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET,
                },
                .{
                    .render_target_handle = gfx.depth_buffer,
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE,
                },
            };
            zf.cmdResourceBarrier(null, null, &render_target_barriers);

            var bind_render_targets = [_]zf.BindRenderTarget{
                .{
                    .render_target_handle = swap_chain_buffer_handle,
                    .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
                },
                .{
                    .render_target_handle = gfx.depth_buffer,
                    .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
                },
            };
            zf.cmdBindRenderTargets(&bind_render_targets);

            zf.cmdSetDefaultViewportAndScissor(@intCast(frame_buffer_size[0]), @intCast(frame_buffer_size[1]));

            zf.cmdBindPipeline(gfx.blit_pso);
            zf.cmdBindDescriptorSet(0, gfx.blit_material.passes[0].persistent_samplers_descriptor_set);
            zf.cmdBindDescriptorSet(frame_index, gfx.blit_material.passes[0].per_frame_descriptor_set);
            zf.cmdDraw(3, 0);

            zf.cmdBindPipeline(gfx.object_pso);
            zf.cmdBindDescriptorSet(frame_index, gfx.object_material.passes[0].per_frame_descriptor_set);
            zf.cmdBindIndexBuffer(gfx.index_buffer, zf.IndexType.INDEX_TYPE_UINT32);
            zf.cmdDrawIndexed(6, 0, 0);

            render_target_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
            render_target_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_PRESENT;
            render_target_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE;
            render_target_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            zf.cmdResourceBarrier(null, null, &render_target_barriers);
        }

        zf.frameSubmit();
    }
}

fn updateDescriptorSets() void {
    // Blit Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_source",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.scene_color[frame_index],
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.blit_shader,
            &gfx.blit_material.passes[0].per_frame_descriptor_set
        );
    }

    // Blit Material: Persistent Sampler
    {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_linear_repeat_sampler",
                .binding_type = .sampler,
                .static_sampler_handle = gfx.linear_repeat_sampler,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .persistent_sampler,
            0,
            gfx.blit_shader,
            &gfx.blit_material.passes[0].persistent_samplers_descriptor_set
        );
    }

    // Object Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.object_shader,
            &gfx.object_material.passes[0].per_frame_descriptor_set
        );
    }

    // Clear Screen Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_output",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.scene_color[frame_index],
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.clear_screen_shader,
            &gfx.clear_screen_material.passes[0].per_frame_descriptor_set
        );
    }
}
