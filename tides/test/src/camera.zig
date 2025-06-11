const std = @import("std");
const zmath = @import("zmath");

pub const Camera = struct {
    view: zmath.Mat = undefined,
    proj: zmath.Mat = undefined,
    view_proj: zmath.Mat = undefined,

    aspect: f32 = 1920.0 / 1080.0,
    fov: f32 = std.math.degreesToRadians(45.0),
    near_plane: f32 = 0.01,
    far_plane: f32 = 50.0,
    position: zmath.Vec = .{ 0.0, 0.0, 0.0, 1.0 },
    forward: zmath.Vec = .{ 0.0, 0.0, 1.0, 0.0 },
    up: zmath.Vec = .{ 0.0, 1.0, 0.0, 0.0 },
    speed: f32 = 10.0,
    yaw: f32 = 90,
    pitch: f32 = 0,

    pub fn updateView(self: *Camera) void {
        self.view = zmath.lookAtLh(self.position, self.position + self.forward, self.up);

        self.updateMatrix();
    }

    pub fn updateProjection(self: *Camera) void {
        self.proj = zmath.perspectiveFovLh(self.fov, self.aspect, self.near_plane, self.far_plane);

        self.updateMatrix();
    }

    pub fn updateOrientation(self: *Camera) void {
        self.forward[0] = std.math.cos(std.math.degreesToRadians(self.yaw)) * std.math.cos(std.math.degreesToRadians(self.pitch));
        self.forward[1] = std.math.sin(std.math.degreesToRadians(self.pitch));
        self.forward[2] = std.math.sin(std.math.degreesToRadians(self.yaw)) * std.math.cos(std.math.degreesToRadians(self.pitch));
        self.forward = zmath.normalize3(self.forward);
    }

    fn updateMatrix(self: *Camera) void {
        self.view_proj = zmath.mul(self.view, self.proj);
    }
};