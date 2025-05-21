const std = @import("std");
const Camera = @import("camera.zig").Camera;
const gfx = @import("gfx.zig");
const Gfx = gfx.Gfx;

const zglfw = @import("zglfw");
const zmath = @import("zmath");

const App = struct {
    last_time: f64 = 0.0,
    current_time: f64 = 0.0,
    delta_time: f32 = 0.0,

    camera: Camera = .{},

    first_cursor: bool = true,
    cursor_last: [2]f32 = [2]f32{0.0, 0.0},
    cursor_sensitivity: f32 = 0.1,
    cursor_look_at: bool = false,

    entities: std.ArrayList(Entity) = undefined,
};

const Entity = struct {
    position: [3]f32,
    unform_scale: f32,
    orientation: [4]f32,

    renderable_hash: u64,
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

    app.camera.updateView();

    app.entities = std.ArrayList(Entity).init(std.heap.page_allocator);
    defer app.entities.deinit();

    app.entities.append(.{
        .position = [3]f32{ -6.0, -7.0, 0.0 },
        .unform_scale = 1.0,
        .orientation = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        .renderable_hash = std.hash.Wyhash.hash(0, "birch_1"),
    }) catch unreachable;

    app.entities.append(.{
        .position = [3]f32{ 0.0, -7.0, 0.0 },
        .unform_scale = 1.0,
        .orientation = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        .renderable_hash = std.hash.Wyhash.hash(0, "birch_2"),
    }) catch unreachable;

    app.entities.append(.{
        .position = [3]f32{ 6.0, -7.0, 0.0 },
        .unform_scale = 1.0,
        .orientation = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        .renderable_hash = std.hash.Wyhash.hash(0, "bush_large"),
    }) catch unreachable;

    var renderableItemInstances = std.ArrayList(gfx.RenderableItemInstance).init(std.heap.page_allocator);
    defer renderableItemInstances.deinit();

    for(app.entities.items) |entity| {
        var renderableItemInstance: gfx.RenderableItemInstance = undefined;
        const z_trans = zmath.translation(entity.position[0], entity.position[1], entity.position[2]);
        zmath.storeMat(&renderableItemInstance.transform, z_trans);
        renderableItemInstance.renderable_hash = entity.renderable_hash;
        renderableItemInstances.append(renderableItemInstance) catch unreachable;
    }

    gfx.recordRenderableItemInstances(&renderableItemInstances);

    while (!window.shouldClose()) {
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
        gfx.draw(&app.camera, @intCast(frame_buffer_size[0]), @intCast(frame_buffer_size[1]));

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