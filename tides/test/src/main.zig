const std = @import("std");
const Camera = @import("camera.zig").Camera;
const gfx = @import("gfx.zig");
const Gfx = gfx.Gfx;

const zglfw = @import("zglfw");
const zgltf = @import("zgltf");
const zmath = @import("zmath");

// App State
var camera: Camera = .{};
var last_time: f64 = 0.0;
var first_cursor = true;
var cursor_last = [2]f32{0.0, 0.0};
var cursor_sensitivity: f32 = 0.1;
var cursor_look_at = false;

fn cursorPosCallback(window: *zglfw.Window, xpos: f64, ypos: f64) callconv(.c) void {
    if (!cursor_look_at) {
        return;
    }

    _ = window;

    if (first_cursor) {
        cursor_last[0] = @floatCast(xpos);
        cursor_last[1] = @floatCast(ypos);
        first_cursor = false;
    }

    const offset = [2]f32{
        (cursor_last[0] - @as(f32, @floatCast(xpos))) * cursor_sensitivity,
        (cursor_last[1] - @as(f32, @floatCast(ypos))) * cursor_sensitivity,
    };
    cursor_last[0] = @floatCast(xpos);
    cursor_last[1] = @floatCast(ypos);

    camera.yaw += offset[0];
    camera.pitch += offset[1];

    if (camera.pitch > 89.0) {
        camera.pitch = 89.0;
    }
    if (camera.pitch < -89.0) {
        camera.pitch = -89.0;
    }

    camera.updateOrientation();
}

pub fn main() !void {
    // Create a window
    zglfw.init() catch unreachable;
    defer zglfw.terminate();

    var window_width: c_int = 1920;
    var window_height: c_int = 1080;

    zglfw.windowHint(.client_api, .no_api);
    const window = zglfw.Window.create(window_width, window_height, "Ze-Forge Test", null) catch unreachable;
    defer zglfw.Window.destroy(window);

    cursor_look_at = true;
    window.setInputMode(.cursor, .disabled) catch unreachable;
    _ = zglfw.setCursorPosCallback(window, cursorPosCallback);

    camera.updateView();

    gfx.init(zglfw.getWin32Window(window).?, @intCast(window_width), @intCast(window_height));

    while (!window.shouldClose()) {
        const time_now = zglfw.getTime();
        const delta_time: f32 = @floatCast(time_now - last_time);

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
            if (cursor_look_at) {
                window.setInputMode(.cursor, .normal) catch unreachable;
                cursor_look_at = false;
            } else {
                window.setInputMode(.cursor, .disabled) catch unreachable;
                cursor_look_at = true;
                first_cursor = true;
            }
        }

        // Camera movement
        const movement = zmath.f32x4s(camera.speed * delta_time);
        const forward = movement * camera.forward;
        const right = movement * zmath.cross3(camera.forward, camera.up);
        const up = movement * zmath.cross3(camera.forward, zmath.cross3(camera.forward, camera.up));

        if (zglfw.getKey(window, .w) == .press) {
            camera.position += forward;
        }
        if (zglfw.getKey(window, .s) == .press) {
            camera.position -= forward;
        }
        if (zglfw.getKey(window, .a) == .press) {
            camera.position += right;
        }
        if (zglfw.getKey(window, .d) == .press) {
            camera.position -= right;
        }
        if (zglfw.getKey(window, .q) == .press) {
            camera.position += up;
        }
        if (zglfw.getKey(window, .e) == .press) {
            camera.position -= up;
        }

        camera.updateView();
        gfx.draw(&camera, @intCast(frame_buffer_size[0]), @intCast(frame_buffer_size[1]));

        last_time = time_now;
    }
}