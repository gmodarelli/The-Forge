const std = @import("std");
const zmath = @import("zmath");

pub const Camera = struct {
    position: zmath.Vec = .{ 0.0, 0.0, -20.0, 1.0 },
    forward: zmath.Vec = .{ 0.0, 0.0, 1.0, 0.0 },
    up: zmath.Vec = .{ 0.0, 1.0, 0.0, 0.0 },
    speed: f32 = 10.0,
    view: zmath.Mat = undefined,
    yaw: f32 = 90,
    pitch: f32 = 0,

    pub fn updateView(self: *Camera) void {
        self.view = zmath.lookAtLh(self.position, self.position + self.forward, self.up);
    }

    pub fn updateOrientation(self: *Camera) void {
        self.forward[0] = std.math.cos(std.math.degreesToRadians(self.yaw)) * std.math.cos(std.math.degreesToRadians(self.pitch));
        self.forward[1] = std.math.sin(std.math.degreesToRadians(self.pitch));
        self.forward[2] = std.math.sin(std.math.degreesToRadians(self.yaw)) * std.math.cos(std.math.degreesToRadians(self.pitch));
        self.forward = zmath.normalize3(self.forward);
    }
};