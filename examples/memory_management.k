// Memory Management Examples in K Language
// Demonstrates allocators, defer, Drop trait, and nodrop

const std = @import("std");
const Allocator = std.mem.Allocator;

// Example 1: Basic Allocator Usage with Defer
fn basic_allocator_example(allocator: Allocator) !void {
    std.debug.print("=== Basic Allocator Example ===\n", .{});

    // Allocate memory
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);  // Guaranteed cleanup

    // Use the buffer
    @memset(buffer, 0);
    buffer[0] = 'H';
    buffer[1] = 'i';

    std.debug.print("Buffer size: {}\n", .{buffer.len});
    std.debug.print("First two bytes: {c}{c}\n", .{buffer[0], buffer[1]});
}

// Example 2: Multiple Defers (executed in reverse order)
fn multiple_defers_example(allocator: Allocator) !void {
    std.debug.print("\n=== Multiple Defers Example ===\n", .{});

    const buffer1 = try allocator.alloc(u8, 100);
    defer {
        std.debug.print("Freeing buffer1\n", .{});
        allocator.free(buffer1);
    }

    const buffer2 = try allocator.alloc(u8, 200);
    defer {
        std.debug.print("Freeing buffer2\n", .{});
        allocator.free(buffer2);
    }

    const buffer3 = try allocator.alloc(u8, 300);
    defer {
        std.debug.print("Freeing buffer3\n", .{});
        allocator.free(buffer3);
    }

    std.debug.print("All buffers allocated\n", .{});
    // Defers execute in reverse: buffer3, buffer2, buffer1
}

// Example 3: Errdefer for Error Handling
fn errdefer_example(allocator: Allocator, should_fail: bool) !void {
    std.debug.print("\n=== Errdefer Example (fail={}) ===\n", .{should_fail});

    const buffer1 = try allocator.alloc(u8, 100);
    errdefer allocator.free(buffer1);  // Only runs on error

    const buffer2 = try allocator.alloc(u8, 200);
    errdefer allocator.free(buffer2);

    std.debug.print("Buffers allocated\n", .{});

    if (should_fail) {
        std.debug.print("Simulating error...\n", .{});
        return error.SimulatedFailure;  // errdefers will run
    }

    // Success path - manually free
    allocator.free(buffer2);
    allocator.free(buffer1);
    std.debug.print("Success - manually freed\n", .{});
}

// Example 4: Drop Trait (RAII)
// Automatic cleanup when value goes out of scope
const File = struct {
    name: []const u8,
    is_open: bool,

    pub fn open(name: []const u8) File {
        std.debug.print("Opening file: {s}\n", .{name});
        return File{
            .name = name,
            .is_open = true,
        };
    }

    pub fn write(self: &File, data: []const u8) void {
        std.debug.print("Writing to {s}: {s}\n", .{self.name, data});
    }

    // Drop is called automatically when File goes out of scope
    pub fn drop(self: &mut File) void {
        if (self.is_open) {
            std.debug.print("Closing file: {s}\n", .{self.name});
            self.is_open = false;
        }
    }
};

fn drop_trait_example() void {
    std.debug.print("\n=== Drop Trait Example ===\n", .{});

    {
        const file = File.open("data.txt");
        file.write("Hello, World!");
        // drop() called automatically here
    }

    std.debug.print("File scope ended\n", .{});
}

// Example 5: Nodrop - Manual Memory Management
// Use nodrop when you need explicit control
const nodrop ManualBuffer = struct {
    data: []u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, size: usize) !ManualBuffer {
        const data = try allocator.alloc(u8, size);
        std.debug.print("ManualBuffer allocated: {} bytes\n", .{size});
        return ManualBuffer{
            .data = data,
            .allocator = allocator,
        };
    }

    // Must be called manually - no automatic cleanup
    pub fn deinit(self: &ManualBuffer) void {
        std.debug.print("ManualBuffer freed: {} bytes\n", .{self.data.len});
        self.allocator.free(self.data);
    }
};

fn nodrop_example(allocator: Allocator) !void {
    std.debug.print("\n=== Nodrop Example ===\n", .{});

    const buffer = try ManualBuffer.init(allocator, 512);

    // Use buffer
    buffer.data[0] = 42;

    // MUST call deinit manually
    buffer.deinit();

    // If we forget to call deinit, memory leaks!
}

// Example 6: Arena Allocator Pattern
fn arena_allocator_example() !void {
    std.debug.print("\n=== Arena Allocator Example ===\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();  // Free all at once

    const allocator = arena.allocator();

    // Multiple allocations
    const strings = try allocator.alloc([]const u8, 3);
    strings[0] = try allocator.dupe(u8, "First");
    strings[1] = try allocator.dupe(u8, "Second");
    strings[2] = try allocator.dupe(u8, "Third");

    for (strings, 0..) |str, i| {
        std.debug.print("[{}] {s}\n", .{i, str});
    }

    // No need to free individually - arena.deinit() frees all
    std.debug.print("All allocations freed by arena\n", .{});
}

// Example 7: Custom Allocator with Tracking
const TrackingAllocator = struct {
    parent_allocator: Allocator,
    allocation_count: usize,
    total_bytes: usize,

    pub fn init(parent: Allocator) TrackingAllocator {
        return TrackingAllocator{
            .parent_allocator = parent,
            .allocation_count = 0,
            .total_bytes = 0,
        };
    }

    pub fn allocator(self: *TrackingAllocator) Allocator {
        return Allocator{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
        if (result) |_| {
            self.allocation_count += 1;
            self.total_bytes += len;
            std.debug.print("Alloc: {} bytes (total: {} allocs, {} bytes)\n",
                .{len, self.allocation_count, self.total_bytes});
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.allocation_count -= 1;
        self.total_bytes -= buf.len;
        std.debug.print("Free: {} bytes (remaining: {} allocs, {} bytes)\n",
            .{buf.len, self.allocation_count, self.total_bytes});
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }

    pub fn print_stats(self: &TrackingAllocator) void {
        std.debug.print("Final stats: {} allocs, {} bytes\n",
            .{self.allocation_count, self.total_bytes});
    }
};

fn tracking_allocator_example() !void {
    std.debug.print("\n=== Tracking Allocator Example ===\n", .{});

    var tracking = TrackingAllocator.init(std.heap.page_allocator);
    const allocator = tracking.allocator();

    const buf1 = try allocator.alloc(u8, 100);
    const buf2 = try allocator.alloc(u8, 200);

    allocator.free(buf1);
    allocator.free(buf2);

    tracking.print_stats();
}

// Example 8: ArrayList with Allocator
fn arraylist_example(allocator: Allocator) !void {
    std.debug.print("\n=== ArrayList Example ===\n", .{});

    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();  // Cleanup

    try list.append(1);
    try list.append(2);
    try list.append(3);

    std.debug.print("ArrayList items: ", .{});
    for (list.items) |item| {
        std.debug.print("{} ", .{item});
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("MEMORY LEAK DETECTED!\n", .{});
        }
    }

    const allocator = gpa.allocator();

    try basic_allocator_example(allocator);
    try multiple_defers_example(allocator);

    // Test errdefer with both success and failure
    errdefer_example(allocator, false) catch {};
    errdefer_example(allocator, true) catch |err| {
        std.debug.print("Caught error: {}\n", .{err});
    };

    drop_trait_example();
    try nodrop_example(allocator);
    try arena_allocator_example();
    try tracking_allocator_example();
    try arraylist_example(allocator);

    std.debug.print("\n=== All examples completed ===\n", .{});
}
