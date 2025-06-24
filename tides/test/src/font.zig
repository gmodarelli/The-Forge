const std = @import("std");
const zf = @import("ze_forge");

const font_count_max: u32 = 95;
const CharHashMap = std.AutoHashMap(u32, CharDesc);

pub const CharDesc = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    left: f32,
    bottom: f32,
    right: f32,
    top: f32,
};

pub const FontDesc = struct {
    char_descs: CharHashMap,
    texture: zf.TextureHandle,

    pub fn create(font_desc_path: []const u8, texture: zf.TextureHandle, resolution: [2]u32, allocator: std.mem.Allocator) !*FontDesc {
        var font_desc = allocator.create(FontDesc) catch unreachable;
        font_desc.char_descs = CharHashMap.init(allocator);
        font_desc.texture = texture;

        var file = std.fs.cwd().openFile(font_desc_path, .{}) catch unreachable;
        defer file.close();

        var buffer_reader = std.io.bufferedReader(file.reader());
        var in_stream = buffer_reader.reader();

        const atlas_width: f32 = @floatFromInt(resolution[0]);
        const atlas_height: f32 = @floatFromInt(resolution[1]);

        var buffer: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            var splits = std.mem.splitScalar(u8, line, ',');
            const unicode_char = splits.first();
            const unicode = std.fmt.parseInt(u32, unicode_char[0..], 10) catch unreachable;

            // Skip advance
            _ = splits.next();
            // Skip plane bounds
            _ = splits.next();
            _ = splits.next();
            _ = splits.next();
            _ = splits.next();

            const left_char = splits.next().?;
            const bottom_char = splits.next().?;
            const right_char = splits.next().?;
            const top_char = splits.next().?;

            const left = std.fmt.parseFloat(f32, left_char[0..]) catch unreachable;
            const bottom = std.fmt.parseFloat(f32, bottom_char[0..]) catch unreachable;
            const right = std.fmt.parseFloat(f32, right_char[0..]) catch unreachable;
            const top = std.fmt.parseFloat(f32, top_char[0..top_char.len - 1]) catch unreachable;

            const char_desc = CharDesc{
                .x = left / atlas_width,
                .y = top / atlas_height,
                .width = (right - left) / atlas_width,
                .height = (top - bottom) / atlas_height,
                .left = left,
                .bottom = bottom,
                .right = right,
                .top = top,
            };

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