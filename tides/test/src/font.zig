const std = @import("std");
const zf = @import("ze_forge");

const font_count_max: u32 = 95;
const CharHashMap = std.AutoHashMap(u32, CharDesc);

pub const PlaneBounds = struct {
    left: f32,
    top: f32,
    right: f32,
    bottom: f32,
};

pub const AtlasBounds = struct {
    left: f32,
    top: f32,
    right: f32,
    bottom: f32,
};

pub const SourceRect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const CharDesc = struct {
    advance: f32,

    plane_bounds: PlaneBounds,
    atlas_bounds: AtlasBounds,
    source_rect: SourceRect,
};

pub const FontDesc = struct {
    char_descs: CharHashMap,
    texture: zf.TextureHandle,

    distance_range: u32,
    size: u32,
    line_height: f32,
    ascender: f32,
    descender: f32,

    pub fn create(font_desc_path: []const u8, texture: zf.TextureHandle, allocator: std.mem.Allocator) !*FontDesc {
        var font_desc = allocator.create(FontDesc) catch unreachable;
        font_desc.char_descs = CharHashMap.init(allocator);
        font_desc.texture = texture;

        const data = std.fs.cwd().readFileAlloc(allocator, font_desc_path, 1024 * 1024) catch unreachable;
        defer allocator.free(data);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch unreachable;
        defer parsed.deinit();

        const atlas = parsed.value.object.get("atlas").?;
        const metrics = parsed.value.object.get("metrics").?;
        const glyphs = parsed.value.object.get("glyphs").?;

        font_desc.distance_range = @intCast(atlas.object.get("distanceRange").?.integer);
        font_desc.size = @intCast(atlas.object.get("size").?.integer);
        font_desc.line_height = @floatCast(metrics.object.get("lineHeight").?.float);
        font_desc.ascender = @floatCast(metrics.object.get("ascender").?.float);
        font_desc.descender = @floatCast(metrics.object.get("descender").?.float);

        for (glyphs.array.items) |glyph| {
            const unicode: u32 = @intCast(glyph.object.get("unicode").?.integer);

            var char_desc = std.mem.zeroes(CharDesc);
            char_desc.advance = @floatCast(glyph.object.get("advance").?.float);

            if (glyph.object.get("planeBounds")) |plane_bounds| {
                char_desc.plane_bounds = .{
                    .left = @floatCast(plane_bounds.object.get("left").?.float),
                    .top = @floatCast(plane_bounds.object.get("top").?.float),
                    .right = @floatCast(plane_bounds.object.get("right").?.float),
                    .bottom = @floatCast(plane_bounds.object.get("bottom").?.float),
                };
            }

            if (glyph.object.get("atlasBounds")) |atlas_bounds| {
                char_desc.atlas_bounds = .{
                    .left = @floatCast(atlas_bounds.object.get("left").?.float),
                    .top = @floatCast(atlas_bounds.object.get("top").?.float),
                    .right = @floatCast(atlas_bounds.object.get("right").?.float),
                    .bottom = @floatCast(atlas_bounds.object.get("bottom").?.float),
                };

                char_desc.source_rect = .{
                    .x = char_desc.atlas_bounds.left + 0.5,
                    .y = char_desc.atlas_bounds.top + 0.5,
                    .width = char_desc.atlas_bounds.right - char_desc.atlas_bounds.left,
                    .height = char_desc.atlas_bounds.bottom - char_desc.atlas_bounds.top,
                };
            }

            font_desc.char_descs.put(unicode, char_desc) catch unreachable;
        }

        return font_desc;
    }

    pub fn getCharDesc(self: *FontDesc, unicode: u32) CharDesc {
        return self.char_descs.get(unicode).?;
    }

    pub fn destroy(self: *FontDesc) void {
        self.char_descs.deinit();
    }
};