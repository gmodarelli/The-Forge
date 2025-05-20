const std = @import("std");
const zgltf = @import("zgltf");

pub const Mesh = struct {
    sub_meshes: [8]SubMesh = undefined,
    sub_meshes_count: u32 = 0,
};

pub const SubMesh = struct {
    index_count: u32,
    first_index: u32,
    vertex_count: u32,
    first_vertex: u32,
};

pub const Vertex = struct {
    position: [3]f32,
    uv: [2]f32,
    normal: [3]f32,
};

pub const GltfLoadDesc = struct {
    base_path: []const u8,
    file_name: []const u8,
    allocator: std.mem.Allocator,
    mesh: *Mesh,
    mesh_vertices: *std.ArrayList(Vertex),
    mesh_indices: *std.ArrayList(u32),
};

pub fn loadGltfMesh(load_desc: *GltfLoadDesc) void {
    var gltf = zgltf.init(load_desc.allocator);
    defer gltf.deinit();

    const gltf_path = std.fs.path.join(load_desc.allocator, &[_][]const u8{ load_desc.base_path, load_desc.file_name }) catch unreachable;
    defer load_desc.allocator.free(gltf_path);

    const json = std.fs.cwd().readFileAllocOptions(
        load_desc.allocator,
        gltf_path,
        512_000,
        null,
        4,
        null
    ) catch unreachable;
    defer load_desc.allocator.free(json);
    gltf.parse(json) catch unreachable;

    std.debug.assert(gltf.data.buffers.items.len == 1);
    const bin_path = std.fs.path.join(load_desc.allocator, &[_][]const u8{ load_desc.base_path, gltf.data.buffers.items[0].uri.? }) catch unreachable;
    defer load_desc.allocator.free(bin_path);

    const bin = std.fs.cwd().readFileAllocOptions(
        load_desc.allocator,
        bin_path,
        5_000_000,
        null,
        4,
        null
    ) catch unreachable;
    defer load_desc.allocator.free(bin);

    var positions = std.ArrayList(f32).init(load_desc.allocator);
    defer positions.deinit();
    var uvs = std.ArrayList(f32).init(load_desc.allocator);
    defer uvs.deinit();
    var normals = std.ArrayList(f32).init(load_desc.allocator);
    defer normals.deinit();
    var indices = std.ArrayList(u32).init(load_desc.allocator);
    defer indices.deinit();

    const mesh = gltf.data.meshes.items[0];
    std.debug.assert(mesh.primitives.items.len < 8);
    load_desc.mesh.sub_meshes_count = 0;

    for (mesh.primitives.items) |primitive| {
        positions.clearRetainingCapacity();
        uvs.clearRetainingCapacity();
        normals.clearRetainingCapacity();
        indices.clearRetainingCapacity();

        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                .position => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    std.debug.assert(accessor.type == .vec3);
                    std.debug.assert(accessor.component_type == .float);
                    gltf.getDataFromBufferView(f32, &positions, accessor, bin);
                },
                .texcoord => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    std.debug.assert(accessor.type == .vec2);
                    std.debug.assert(accessor.component_type == .float);
                    gltf.getDataFromBufferView(f32, &uvs, accessor, bin);
                },
                .normal => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    std.debug.assert(accessor.type == .vec3);
                    std.debug.assert(accessor.component_type == .float);
                    gltf.getDataFromBufferView(f32, &normals, accessor, bin);
                },
                else => {}
            }
        }

        std.debug.assert(primitive.indices != null);
        const accessor = gltf.data.accessors.items[primitive.indices.?];
        if (accessor.component_type == .unsigned_short) {
            var indices16 = std.ArrayList(u16).init(load_desc.allocator);
            defer indices16.deinit();
            gltf.getDataFromBufferView(u16, &indices16, accessor, bin);

            for (indices16.items) |index_16| {
                indices.append(@intCast(index_16)) catch unreachable;
            }
        } else {
            gltf.getDataFromBufferView(u32, &indices, accessor, bin);
        }

        const positions_count = @divExact(positions.items.len, 3);

        load_desc.mesh.sub_meshes[load_desc.mesh.sub_meshes_count].index_count = @intCast(indices.items.len);
        load_desc.mesh.sub_meshes[load_desc.mesh.sub_meshes_count].first_index = @intCast(load_desc.mesh_indices.items.len);
        load_desc.mesh.sub_meshes[load_desc.mesh.sub_meshes_count].vertex_count = @intCast(positions_count);
        load_desc.mesh.sub_meshes[load_desc.mesh.sub_meshes_count].first_vertex = @intCast(load_desc.mesh_vertices.items.len);
        load_desc.mesh.sub_meshes_count += 1;

        for (0..positions_count) |vertex_index| {
            const vertex = Vertex{
                .position = .{ positions.items[vertex_index * 3 + 0] * -1.0, positions.items[vertex_index * 3 + 1], positions.items[vertex_index * 3 + 2] },
                .normal = .{ normals.items[vertex_index * 3 + 0] * -1.0, normals.items[vertex_index * 3 + 1], normals.items[vertex_index * 3 + 2] },
                .uv = .{ uvs.items[vertex_index * 2 + 0], uvs.items[vertex_index * 2 + 1] },
            };
            load_desc.mesh_vertices.append(vertex) catch unreachable;
        }

        for (indices.items) |index| {
            load_desc.mesh_indices.append(index) catch unreachable;
        }
    }
}