// auto generated by c2z
const std = @import("std");
//const cpp = @import("cpp");

pub const MemoryStatistics = extern struct {
    totalReportedMemory: u32,
    totalActualMemory: u32,
    peakReportedMemory: u32,
    peakActualMemory: u32,
    accumulatedReportedMemory: u32,
    accumulatedActualMemory: u32,
    accumulatedAllocUnitCount: u32,
    totalAllocUnitCount: u32,
    peakAllocUnitCount: u32,
};

/// appName is used to create dump file, pass NULL to avoid it
pub extern fn initMemAlloc(appName: [*c]const u8) bool;
pub extern fn exitMemAlloc() void;
pub extern fn memGetStatistics() MemoryStatistics;
pub extern fn tf_malloc_internal(size: usize, f: [*c]const u8, l: c_int, sf: [*c]const u8) ?*anyopaque;
pub extern fn tf_memalign_internal(@"align": usize, size: usize, f: [*c]const u8, l: c_int, sf: [*c]const u8) ?*anyopaque;
pub extern fn tf_calloc_internal(count: usize, size: usize, f: [*c]const u8, l: c_int, sf: [*c]const u8) ?*anyopaque;
pub extern fn tf_calloc_memalign_internal(count: usize, @"align": usize, size: usize, f: [*c]const u8, l: c_int, sf: [*c]const u8) ?*anyopaque;
pub extern fn tf_realloc_internal(ptr: ?*anyopaque, size: usize, f: [*c]const u8, l: c_int, sf: [*c]const u8) ?*anyopaque;
pub extern fn tf_free_internal(ptr: ?*anyopaque, f: [*c]const u8, l: c_int, sf: [*c]const u8) void;

pub fn tf_delete_internal(comptime T: type, ptr: [*c]T, f: [*c]const u8, l: c_int, sf: [*c]const u8) void {
    if (ptr) {
        ptr.deinit();
        tf_free_internal(ptr, f, l, sf);
    }
}