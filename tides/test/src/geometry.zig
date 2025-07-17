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
    center: [3]f32,
    radius: f32,
    aabb_min: [3]f32,
    aabb_max: [3]f32,
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

pub const Meshlet = struct {
    vertex_offset: u32,
    triangle_offset: u32,
    vertex_count: u32,
    triangle_count: u32,
};

pub const MeshletTriangle = packed struct(u32) {
    v0: u10,
    v1: u10,
    v2: u10,
    _unused: u2,
};

pub const MeshletBounds = struct {
    local_center: [3]f32,
    local_extents: [3]f32,
};

pub const BoundingBox = struct {
    center: [3]f32,
    extents: [3]f32,
};

pub const MeshData = struct {
    indices: std.ArrayList(u32),
    positions_stream: std.ArrayList([3]f32),
    normals_stream: std.ArrayList([3]f32),
    texcoords_stream: std.ArrayList([2]f32),
    bounds: BoundingBox,

    meshlets: std.ArrayList(Meshlet),
    meshlet_bounds: std.ArrayList(MeshletBounds),
    meshlet_triangles: std.ArrayList(MeshletTriangle),
    meshlet_vertices: std.ArrayList(u32),
};

pub const MeshLoadDesc = struct {
    base_path: []const u8,
    file_name: []const u8,
    allocator: std.mem.Allocator,
    mesh_data: *std.ArrayList(MeshData),
};

pub fn loadGltfMesh(load_desc: *GltfLoadDesc) void {
    var gltf = zgltf.init(load_desc.allocator);
    defer gltf.deinit();

    const gltf_path = std.fs.path.join(load_desc.allocator, &[_][]const u8{ load_desc.base_path, load_desc.file_name }) catch unreachable;
    defer load_desc.allocator.free(gltf_path);

    const json = std.fs.cwd().readFileAllocOptions(load_desc.allocator, gltf_path, 512_000, null, 4, null) catch unreachable;
    defer load_desc.allocator.free(json);
    gltf.parse(json) catch unreachable;

    std.debug.assert(gltf.data.buffers.items.len == 1);
    const bin_path = std.fs.path.join(load_desc.allocator, &[_][]const u8{ load_desc.base_path, gltf.data.buffers.items[0].uri.? }) catch unreachable;
    defer load_desc.allocator.free(bin_path);

    const bin = std.fs.cwd().readFileAllocOptions(load_desc.allocator, bin_path, 5_000_000, null, 4, null) catch unreachable;
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
                // TODO: Patch zgltf with support for extracting min/max from accessors
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
                else => {},
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
        const sub_mesh_index = load_desc.mesh.sub_meshes_count;
        load_desc.mesh.sub_meshes_count += 1;

        load_desc.mesh.sub_meshes[sub_mesh_index].index_count = @intCast(indices.items.len);
        load_desc.mesh.sub_meshes[sub_mesh_index].first_index = @intCast(load_desc.mesh_indices.items.len);
        load_desc.mesh.sub_meshes[sub_mesh_index].vertex_count = @intCast(positions_count);
        load_desc.mesh.sub_meshes[sub_mesh_index].first_vertex = @intCast(load_desc.mesh_vertices.items.len);

        // TODO: This won't be necessary once zgltf has support for extracting min/max from accessors
        const float_max = std.math.floatMax(f32);
        load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[0] = float_max;
        load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[1] = float_max;
        load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[2] = float_max;
        load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[0] = -float_max;
        load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[1] = -float_max;
        load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[2] = -float_max;

        for (0..positions_count) |vertex_index| {
            const vertex = Vertex{
                .position = .{ positions.items[vertex_index * 3 + 0] * -1.0, positions.items[vertex_index * 3 + 1], positions.items[vertex_index * 3 + 2] },
                .normal = .{ normals.items[vertex_index * 3 + 0] * -1.0, normals.items[vertex_index * 3 + 1], normals.items[vertex_index * 3 + 2] },
                .uv = .{ uvs.items[vertex_index * 2 + 0], uvs.items[vertex_index * 2 + 1] },
            };
            load_desc.mesh_vertices.append(vertex) catch unreachable;

            // AABB
            if (vertex.position[0] < load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[0]) {
                load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[0] = vertex.position[0];
            }

            if (vertex.position[1] < load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[1]) {
                load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[1] = vertex.position[1];
            }

            if (vertex.position[2] < load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[2]) {
                load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[2] = vertex.position[2];
            }

            if (vertex.position[0] > load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[0]) {
                load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[0] = vertex.position[0];
            }

            if (vertex.position[1] > load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[1]) {
                load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[1] = vertex.position[1];
            }

            if (vertex.position[2] > load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[2]) {
                load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[2] = vertex.position[2];
            }
        }

        // Bounding Sphere
        load_desc.mesh.sub_meshes[sub_mesh_index].center[0] = (load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[0] + load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[0]) * 0.5;
        load_desc.mesh.sub_meshes[sub_mesh_index].center[1] = (load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[1] + load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[1]) * 0.5;
        load_desc.mesh.sub_meshes[sub_mesh_index].center[2] = (load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[2] + load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[2]) * 0.5;
        const radius_x = (load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[0] - load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[0]) * 0.5;
        const radius_y = (load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[1] - load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[1]) * 0.5;
        const radius_z = (load_desc.mesh.sub_meshes[sub_mesh_index].aabb_max[2] - load_desc.mesh.sub_meshes[sub_mesh_index].aabb_min[2]) * 0.5;
        load_desc.mesh.sub_meshes[sub_mesh_index].radius = @max(radius_x, @max(radius_y, radius_z));

        for (indices.items) |index| {
            load_desc.mesh_indices.append(index) catch unreachable;
        }
    }
}

pub fn loadMesh(load_desc: *MeshLoadDesc) void {
    const mesh_path = std.fs.path.join(load_desc.allocator, &[_][]const u8{ load_desc.base_path, load_desc.file_name }) catch unreachable;
    defer load_desc.allocator.free(mesh_path);

    var file = std.fs.cwd().openFile(mesh_path, .{}) catch unreachable;
    defer file.close();
    const reader = file.reader();

    var magic: [9]u8 = undefined;
    var read_length = reader.readAtLeast(&magic, magic.len) catch unreachable;
    std.debug.assert(read_length == magic.len);
    std.debug.assert(std.mem.eql(u8, &magic, "TidesMesh"));

    const mesh_count = reader.readInt(usize, .little) catch unreachable;

    for (0..mesh_count) |_| {
        var mesh_data: MeshData = undefined;

        const index_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.indices = std.ArrayList(u32).init(load_desc.allocator);
        mesh_data.indices.resize(index_count) catch unreachable;

        const positions_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.positions_stream = std.ArrayList([3]f32).init(load_desc.allocator);
        mesh_data.positions_stream.resize(positions_count) catch unreachable;

        const normals_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.normals_stream = std.ArrayList([3]f32).init(load_desc.allocator);
        mesh_data.normals_stream.resize(normals_count) catch unreachable;

        const texcoords_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.texcoords_stream = std.ArrayList([2]f32).init(load_desc.allocator);
        mesh_data.texcoords_stream.resize(texcoords_count) catch unreachable;

        const meshlets_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.meshlets = std.ArrayList(Meshlet).init(load_desc.allocator);
        mesh_data.meshlets.resize(meshlets_count) catch unreachable;

        const meshlet_bounds_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.meshlet_bounds = std.ArrayList(MeshletBounds).init(load_desc.allocator);
        mesh_data.meshlet_bounds.resize(meshlet_bounds_count) catch unreachable;

        const meshlet_triangles_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.meshlet_triangles = std.ArrayList(MeshletTriangle).init(load_desc.allocator);
        mesh_data.meshlet_triangles.resize(meshlet_triangles_count) catch unreachable;

        const meshlet_vertices_count = reader.readInt(usize, .little) catch unreachable;
        mesh_data.meshlet_vertices = std.ArrayList(u32).init(load_desc.allocator);
        mesh_data.meshlet_vertices.resize(meshlet_vertices_count) catch unreachable;

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.indices.items), mesh_data.indices.items.len * @sizeOf(u32)) catch unreachable;
        std.debug.assert(read_length == mesh_data.indices.items.len * @sizeOf(u32));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.positions_stream.items), mesh_data.positions_stream.items.len * @sizeOf([3]f32)) catch unreachable;
        std.debug.assert(read_length == mesh_data.positions_stream.items.len * @sizeOf([3]f32));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.normals_stream.items), mesh_data.normals_stream.items.len * @sizeOf([3]f32)) catch unreachable;
        std.debug.assert(read_length == mesh_data.normals_stream.items.len * @sizeOf([3]f32));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.texcoords_stream.items), mesh_data.texcoords_stream.items.len * @sizeOf([2]f32)) catch unreachable;
        std.debug.assert(read_length == mesh_data.texcoords_stream.items.len * @sizeOf([2]f32));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.meshlets.items), mesh_data.meshlets.items.len * @sizeOf(Meshlet)) catch unreachable;
        std.debug.assert(read_length == mesh_data.meshlets.items.len * @sizeOf(Meshlet));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.meshlet_bounds.items), mesh_data.meshlet_bounds.items.len * @sizeOf(MeshletBounds)) catch unreachable;
        std.debug.assert(read_length == mesh_data.meshlet_bounds.items.len * @sizeOf(MeshletBounds));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.meshlet_triangles.items), mesh_data.meshlet_triangles.items.len * @sizeOf(MeshletTriangle)) catch unreachable;
        std.debug.assert(read_length == mesh_data.meshlet_triangles.items.len * @sizeOf(MeshletTriangle));

        read_length = reader.readAtLeast(std.mem.sliceAsBytes(mesh_data.meshlet_vertices.items), mesh_data.meshlet_vertices.items.len * @sizeOf(u32)) catch unreachable;
        std.debug.assert(read_length == mesh_data.meshlet_vertices.items.len * @sizeOf(u32));

        var position_min = mesh_data.positions_stream.items[0];
        var position_max = mesh_data.positions_stream.items[0];

        for (1..positions_count) |i| {
            if (mesh_data.positions_stream.items[i][0] < position_min[0]) {
                position_min[0] = mesh_data.positions_stream.items[i][0];
            }

            if (mesh_data.positions_stream.items[i][1] < position_min[1]) {
                position_min[1] = mesh_data.positions_stream.items[i][1];
            }

            if (mesh_data.positions_stream.items[i][2] < position_min[2]) {
                position_min[2] = mesh_data.positions_stream.items[i][2];
            }

            if (mesh_data.positions_stream.items[i][0] > position_max[0]) {
                position_max[0] = mesh_data.positions_stream.items[i][0];
            }

            if (mesh_data.positions_stream.items[i][1] > position_max[1]) {
                position_max[1] = mesh_data.positions_stream.items[i][1];
            }

            if (mesh_data.positions_stream.items[i][2] > position_max[2]) {
                position_max[2] = mesh_data.positions_stream.items[i][2];
            }
        }

        mesh_data.bounds.center[0] = (position_min[0] + position_max[0]) * 0.5;
        mesh_data.bounds.center[1] = (position_min[1] + position_max[1]) * 0.5;
        mesh_data.bounds.center[2] = (position_min[2] + position_max[2]) * 0.5;

        mesh_data.bounds.extents[0] = (position_max[0] - position_min[0]) * 0.5;
        mesh_data.bounds.extents[1] = (position_max[1] - position_min[1]) * 0.5;
        mesh_data.bounds.extents[2] = (position_max[2] - position_min[2]) * 0.5;

        load_desc.mesh_data.append(mesh_data) catch unreachable;
    }
}
