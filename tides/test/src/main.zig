const std = @import("std");
const Camera = @import("camera.zig").Camera;
const gfx = @import("gfx.zig");
const Gfx = gfx.Gfx;

const zglfw = @import("zglfw");
const zmath = @import("zmath");
const ztracy = @import("ztracy");

const App = struct {
    last_time: f64 = 0.0,
    current_time: f64 = 0.0,
    delta_time: f32 = 0.0,

    camera: Camera = .{},

    first_cursor: bool = true,
    cursor_last: [2]f32 = [2]f32{ 0.0, 0.0 },
    cursor_sensitivity: f32 = 0.1,
    cursor_look_at: bool = false,

    entities: std.ArrayList(Entity) = undefined,
};

const Entity = struct {
    position: [3]f32,
    unform_scale: f32,
    orientation: [4]f32,

    renderable_hash: gfx.HashKey,
};

var app: App = .{};

pub fn main() !void {
    // Create a window
    zglfw.init() catch unreachable;
    defer zglfw.terminate();

    var window_width: c_int = 1920;
    var window_height: c_int = 1080;

    zglfw.windowHint(.client_api, .no_api);
    const window = zglfw.Window.create(window_width, window_height, "Ze-Forge Test", null) catch unreachable;
    defer zglfw.Window.destroy(window);

    app.cursor_look_at = true;
    window.setInputMode(.cursor, .disabled) catch unreachable;
    _ = zglfw.setCursorPosCallback(window, cursorPosCallback);

    gfx.init(zglfw.getWin32Window(window).?, @intCast(window_width), @intCast(window_height));

    const birch_1_key = gfx.HashKey.generate("birch_1");
    const birch_2_key = gfx.HashKey.generate("birch_2");
    const bush_large_key = gfx.HashKey.generate("bush_large");
    // const plane_key = gfx.HashKey.generate("plane");

    // Load resources
    {
        const bark_birch_tree_albedo_key = gfx.HashKey.generate("bark_birch_tree_albedo");
        const bark_birch_tree_normal_key = gfx.HashKey.generate("bark_birch_tree_normal");
        const leaves_birch_albedo_key = gfx.HashKey.generate("leaves_birch_albedo");
        const leaves_giant_pine_albedo_key = gfx.HashKey.generate("leaves_giant_pine_albedo");

        const default_mat_key = gfx.HashKey.generate("default");
        const bark_birch_mat_key = gfx.HashKey.generate("bark_birch");
        const leaves_birch_mat_key = gfx.HashKey.generate("leaves_birch");
        const leaves_giant_pine_mat_key = gfx.HashKey.generate("leaves_giant_pine");

        // Load meshes
        const meshes_path = "content/models";
        gfx.loadMesh(birch_1_key, meshes_path, "Birch_1.mesh");
        gfx.loadMesh(birch_2_key, meshes_path, "Birch_2.mesh");
        gfx.loadMesh(bush_large_key, meshes_path, "Bush_Large.mesh");
        // gfx.loadGltfMesh(plane_key, meshes_path, "Plane.gltf");

        // Load textures
        gfx.loadTexture(bark_birch_tree_albedo_key, "content/textures/Bark_BirchTree.dds");
        gfx.loadTexture(bark_birch_tree_normal_key, "content/textures/Bark_BirchTree_Normal.dds");
        gfx.loadTexture(leaves_birch_albedo_key, "content/textures/Leaves_Birch_C.dds");
        gfx.loadTexture(leaves_giant_pine_albedo_key, "content/textures/Leaves_GiantPine_C.dds");

        // Load materials
        gfx.loadMaterial(default_mat_key, .{});
        gfx.loadMaterial(bark_birch_mat_key, .{
            .albedo_texture = bark_birch_tree_albedo_key,
            .normal_texture = bark_birch_tree_normal_key,
            .alpha_tested = false,
        });
        gfx.loadMaterial(leaves_birch_mat_key, .{
            .albedo_texture = leaves_birch_albedo_key,
            .alpha_tested = true,
        });
        gfx.loadMaterial(leaves_giant_pine_mat_key, .{
            .albedo_texture = leaves_giant_pine_albedo_key,
            .alpha_tested = true,
        });

        // Register renderables
        gfx.registerRenderable(birch_1_key, birch_1_key, &[_]gfx.HashKey{ bark_birch_mat_key, leaves_birch_mat_key });
        gfx.registerRenderable(birch_2_key, birch_2_key, &[_]gfx.HashKey{ bark_birch_mat_key, leaves_birch_mat_key });
        gfx.registerRenderable(bush_large_key, bush_large_key, &[_]gfx.HashKey{leaves_giant_pine_mat_key});
        // gfx.registerRenderable(plane_key, plane_key, &[_]gfx.HashKey{ default_mat_key });
    }

    app.camera.position += zmath.Vec{ 0.0, 7.0, -20.0, 0.0 };
    app.camera.updateView();

    app.camera.aspect = @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(window_height));
    app.camera.fov = std.math.pi * 0.25 * 0.75; // std.math.degreesToRadians(45.0);
    app.camera.near_plane = 0.25;
    app.camera.far_plane = 250.0;
    app.camera.updateProjection();

    app.entities = std.ArrayList(Entity).init(std.heap.page_allocator);
    defer app.entities.deinit();

    // Create fake entities
    {
        // app.entities.append(.{
        //     .position = [3]f32{ -6, 0.0, 0.0 },
        //     .unform_scale = 1.0,
        //     .orientation = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        //     .renderable_hash = birch_2_key,
        // }) catch unreachable;

        // app.entities.append(.{
        //     .position = [3]f32{ 0.0, 0.0, 0.0 },
        //     .unform_scale = 1.0,
        //     .orientation = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        //     .renderable_hash = birch_1_key,
        // }) catch unreachable;

        // app.entities.append(.{
        //     .position = [3]f32{ 6.0, 0.0, 0.0 },
        //     .unform_scale = 1.0,
        //     .orientation = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        //     .renderable_hash = bush_large_key,
        // }) catch unreachable;

        const seed: u64 = 42;
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();

        const renderables = [_]gfx.HashKey{
            birch_1_key, birch_2_key, bush_large_key,
        };

        var x: i32 = 0;
        while (x <= 20) : (x += 1) {
            var z: i32 = 0;
            while (z <= 20) : (z += 1) {
                const renderable_index: usize = rand.intRangeAtMost(usize, 0, renderables.len - 1);

                const yaw: f32 = rand.float(f32) * std.math.pi * 4.0;
                const scale: f32 = rand.float(f32) + 0.5;
                const offset_x: f32 = (rand.float(f32) * 2.0 - 1.0) * 2.0;
                const offset_z: f32 = (rand.float(f32) * 2.0 - 1.0) * 2.0;
                app.entities.append(.{
                    .position = [3]f32{ @as(f32, @floatFromInt(x * 6)) + offset_x, 0.0, @as(f32, @floatFromInt(z * 6)) + offset_z },
                    .unform_scale = scale,
                    .orientation = [4]f32{ 0.0, yaw, 0.0, 1.0 },
                    .renderable_hash = renderables[renderable_index],
                }) catch unreachable;
            }
        }
    }

    // Iterate through entities
    var instances = std.ArrayList(gfx.Instance).init(std.heap.page_allocator);
    defer instances.deinit();

    for (app.entities.items) |entity| {
        var instance: gfx.Instance = undefined;
        instance.renderable = entity.renderable_hash;
        const translation = zmath.translation(entity.position[0], entity.position[1], entity.position[2]);
        const rotation = zmath.matFromRollPitchYaw(entity.orientation[0], entity.orientation[1], entity.orientation[2]);
        const scaling = zmath.scaling(entity.unform_scale, entity.unform_scale, entity.unform_scale);
        // NOTE: zmath stores matrices in row-major order. We transpose them cause HLSL stores them column-major
        zmath.storeMat(&instance.world_mat, zmath.transpose(zmath.mul(zmath.mul(scaling, rotation), translation)));
        instances.append(instance) catch unreachable;
    }

    gfx.registerInstances(&instances);

    while (!window.shouldClose()) {
        ztracy.FrameMark();

        app.current_time = zglfw.getTime();
        app.delta_time = @floatCast(app.current_time - app.last_time);

        zglfw.pollEvents();

        const frame_buffer_size = window.getFramebufferSize();
        if (frame_buffer_size[0] != window_width or frame_buffer_size[1] != window_height) {
            window_width = frame_buffer_size[0];
            window_height = frame_buffer_size[1];

            std.log.info(
                "Window resized to {d}x{d}",
                .{ window_width, window_height },
            );

            gfx.resize();
        }

        if (zglfw.getKey(window, .escape) == .press) {
            if (app.cursor_look_at) {
                window.setInputMode(.cursor, .normal) catch unreachable;
                app.cursor_look_at = false;
            } else {
                window.setInputMode(.cursor, .disabled) catch unreachable;
                app.cursor_look_at = true;
                app.first_cursor = true;
            }
        }

        // Camera movement
        const movement = zmath.f32x4s(app.camera.speed * app.delta_time);
        const forward = movement * app.camera.forward;
        const right = movement * zmath.cross3(app.camera.forward, app.camera.up);
        const up = movement * zmath.cross3(app.camera.forward, zmath.cross3(app.camera.forward, app.camera.up));

        if (zglfw.getKey(window, .w) == .press) {
            app.camera.position += forward;
        }
        if (zglfw.getKey(window, .s) == .press) {
            app.camera.position -= forward;
        }
        if (zglfw.getKey(window, .a) == .press) {
            app.camera.position += right;
        }
        if (zglfw.getKey(window, .d) == .press) {
            app.camera.position -= right;
        }
        if (zglfw.getKey(window, .q) == .press) {
            app.camera.position += up;
        }
        if (zglfw.getKey(window, .e) == .press) {
            app.camera.position -= up;
        }

        app.camera.updateView();
        gfx.draw(&app.camera, @intCast(frame_buffer_size[0]), @intCast(frame_buffer_size[1]), app.delta_time);

        app.last_time = app.current_time;
    }
}

fn cursorPosCallback(window: *zglfw.Window, xpos: f64, ypos: f64) callconv(.c) void {
    if (!app.cursor_look_at) {
        return;
    }

    _ = window;

    if (app.first_cursor) {
        app.cursor_last[0] = @floatCast(xpos);
        app.cursor_last[1] = @floatCast(ypos);
        app.first_cursor = false;
    }

    const offset = [2]f32{
        (app.cursor_last[0] - @as(f32, @floatCast(xpos))) * app.cursor_sensitivity,
        (app.cursor_last[1] - @as(f32, @floatCast(ypos))) * app.cursor_sensitivity,
    };
    app.cursor_last[0] = @floatCast(xpos);
    app.cursor_last[1] = @floatCast(ypos);

    app.camera.yaw += offset[0];
    app.camera.pitch += offset[1];

    if (app.camera.pitch > 89.0) {
        app.camera.pitch = 89.0;
    }
    if (app.camera.pitch < -89.0) {
        app.camera.pitch = -89.0;
    }

    app.camera.updateOrientation();
}
