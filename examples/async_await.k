// Async/Await Examples in K Language

const std = @import("std");
const Allocator = std.mem.Allocator;

// Example 1: Basic Async Function
async fn simple_async() i32 {
    std.debug.print("Async function executing\n", .{});
    return 42;
}

// Example 2: Async with Await
async fn fetch_data(id: u32) ![]const u8 {
    std.debug.print("Fetching data for id: {}\n", .{id});

    // Simulate async I/O
    await sleep(Duration.from_millis(100));

    return "data";
}

async fn process_data(id: u32) !void {
    const data = await fetch_data(id);
    std.debug.print("Received: {s}\n", .{data});
}

// Example 3: Multiple Concurrent Tasks
async fn download_file(url: []const u8, allocator: Allocator) ![]u8 {
    std.debug.print("Downloading: {s}\n", .{url});

    // Simulate network delay
    await sleep(Duration.from_millis(500));

    // Return some dummy data
    return try allocator.dupe(u8, url);
}

async fn download_multiple(allocator: Allocator) !void {
    const urls = [_][]const u8{
        "https://example.com/file1.txt",
        "https://example.com/file2.txt",
        "https://example.com/file3.txt",
    };

    // Launch all downloads concurrently
    var tasks = std.ArrayList(Future([]u8)).init(allocator);
    defer tasks.deinit();

    for (urls) |url| {
        const task = async download_file(url, allocator);
        try tasks.append(task);
    }

    // Await all results
    for (tasks.items, 0..) |task, i| {
        const data = await task;
        defer allocator.free(data);

        std.debug.print("File {}: {s}\n", .{i, data});
    }
}

// Example 4: Async with Error Handling
async fn may_fail(should_fail: bool) !i32 {
    await sleep(Duration.from_millis(50));

    if (should_fail) {
        return error.Failed;
    }

    return 42;
}

async fn handle_errors() void {
    const result1 = may_fail(false) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    std.debug.print("Success: {}\n", .{await result1});

    const result2 = may_fail(true) catch |err| {
        std.debug.print("Expected error: {}\n", .{err});
        return;
    };
    std.debug.print("Should not reach here\n", .{});
}

// Example 5: Select - Race Multiple Futures
async fn fast_operation() i32 {
    await sleep(Duration.from_millis(100));
    return 1;
}

async fn slow_operation() i32 {
    await sleep(Duration.from_millis(1000));
    return 2;
}

async fn race_example() void {
    const task1 = async fast_operation();
    const task2 = async slow_operation();

    // Wait for whichever completes first
    const result = select(.{task1, task2});

    switch (result) {
        .task1 => |value| {
            std.debug.print("Fast task won: {}\n", .{value});
        },
        .task2 => |value| {
            std.debug.print("Slow task won: {}\n", .{value});
        },
    }
}

// Example 6: Async Streams/Iterators
const AsyncIterator = trait {
    type Item;

    async fn next(self: &mut Self) ?Self.Item;
};

const Range = struct {
    current: i32,
    end: i32,

    pub fn init(start: i32, end: i32) Range {
        return Range{ .current = start, .end = end };
    }
};

impl AsyncIterator for Range {
    type Item = i32;

    async fn next(self: &mut Range) ?i32 {
        if (self.current >= self.end) return null;

        const value = self.current;
        self.current += 1;

        // Simulate async work
        await sleep(Duration.from_millis(10));

        return value;
    }
}

async fn stream_example() void {
    var range = Range.init(0, 5);

    while (await range.next()) |value| {
        std.debug.print("Value: {}\n", .{value});
    }
}

// Example 7: Async with Channels
const Channel = std.sync.Channel;

async fn producer(channel: &Channel(i32), count: usize) void {
    for (0..count) |i| {
        await sleep(Duration.from_millis(100));
        try channel.send(@intCast(i));
        std.debug.print("Sent: {}\n", .{i});
    }
    channel.close();
}

async fn consumer(channel: &Channel(i32)) void {
    while (channel.receive()) |value| {
        std.debug.print("Received: {}\n", .{value});
        await sleep(Duration.from_millis(150));
    }
}

async fn channel_example(allocator: Allocator) !void {
    var channel = try Channel(i32).init(allocator);
    defer channel.deinit();

    const prod = async producer(&channel, 5);
    const cons = async consumer(&channel);

    await prod;
    await cons;
}

// Example 8: Timeout
async fn with_timeout(comptime T: type, future: Future(T), timeout: Duration) !T {
    const timer = async sleep(timeout);
    const work = future;

    const result = select(.{work, timer});

    return switch (result) {
        .work => |value| value,
        .timer => error.Timeout,
    };
}

async fn slow_task() i32 {
    await sleep(Duration.from_secs(5));
    return 42;
}

async fn timeout_example() void {
    const result = with_timeout(i32, async slow_task(), Duration.from_secs(1)) catch |err| {
        std.debug.print("Task timed out: {}\n", .{err});
        return;
    };

    std.debug.print("Result: {}\n", .{await result});
}

// Example 9: Async Trait Methods
const AsyncReader = trait {
    async fn read(self: &mut Self, buffer: []u8) !usize;
};

const AsyncFile = struct {
    path: []const u8,
    position: usize,
};

impl AsyncReader for AsyncFile {
    async fn read(self: &mut AsyncFile, buffer: []u8) !usize {
        std.debug.print("Reading from {s}\n", .{self.path});

        // Simulate async I/O
        await sleep(Duration.from_millis(200));

        // Dummy implementation
        const bytes_read = @min(buffer.len, 100);
        @memset(buffer[0..bytes_read], 'X');

        self.position += bytes_read;
        return bytes_read;
    }
}

async fn read_all(comptime R: type, reader: &mut R, allocator: Allocator) ![]u8
    where R: AsyncReader
{
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var buffer: [1024]u8 = undefined;

    while (true) {
        const bytes_read = await reader.read(&buffer);
        if (bytes_read == 0) break;

        try result.appendSlice(buffer[0..bytes_read]);
    }

    return result.toOwnedSlice();
}

// Example 10: Custom Future Implementation
const Future = trait {
    type Output;

    fn poll(self: &mut Self, context: &Context) Poll(Self.Output);
};

const Poll = enum {
    Ready: T,
    Pending,
};

const DelayedValue = struct {
    value: i32,
    delay_ms: u64,
    start_time: ?i64,

    pub fn new(value: i32, delay_ms: u64) DelayedValue {
        return DelayedValue{
            .value = value,
            .delay_ms = delay_ms,
            .start_time = null,
        };
    }
};

impl Future for DelayedValue {
    type Output = i32;

    fn poll(self: &mut DelayedValue, context: &Context) Poll(i32) {
        if (self.start_time == null) {
            self.start_time = std.time.milliTimestamp();
            context.wake_later(self.delay_ms);
            return Poll(i32).Pending;
        }

        const elapsed = std.time.milliTimestamp() - self.start_time.?;
        if (elapsed >= self.delay_ms) {
            return Poll(i32){ .Ready = self.value };
        }

        const remaining = self.delay_ms - @intCast(elapsed);
        context.wake_later(remaining);
        return Poll(i32).Pending;
    }
}

async fn custom_future_example() void {
    var delayed = DelayedValue.new(42, 1000);
    const value = await delayed;
    std.debug.print("Got value after delay: {}\n", .{value});
}

// Example 11: Async Runtime Integration
const Runtime = struct {
    // Runtime implementation
    pub fn block_on(comptime T: type, future: Future(T)) T {
        // Execute the future to completion
        // ...
    }

    pub fn spawn(comptime T: type, future: Future(T)) JoinHandle(T) {
        // Spawn a task on the runtime
        // ...
    }
};

const JoinHandle = struct {
    // Handle to a spawned task
    pub fn await(self: JoinHandle(T)) T {
        // Wait for task completion
        // ...
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create async runtime
    var runtime = Runtime.init();
    defer runtime.deinit();

    // Run async main function
    runtime.block_on(async async_main(allocator));
}

async fn async_main(allocator: Allocator) !void {
    std.debug.print("=== Async/Await Examples ===\n\n", .{});

    std.debug.print("1. Simple async:\n", .{});
    const result = await simple_async();
    std.debug.print("Result: {}\n\n", .{result});

    std.debug.print("2. Async with await:\n", .{});
    await process_data(123);
    std.debug.print("\n", .{});

    std.debug.print("3. Multiple concurrent tasks:\n", .{});
    try await download_multiple(allocator);
    std.debug.print("\n", .{});

    std.debug.print("4. Error handling:\n", .{});
    await handle_errors();
    std.debug.print("\n", .{});

    std.debug.print("5. Race example:\n", .{});
    await race_example();
    std.debug.print("\n", .{});

    std.debug.print("6. Async stream:\n", .{});
    await stream_example();
    std.debug.print("\n", .{});

    std.debug.print("7. Channel example:\n", .{});
    try await channel_example(allocator);
    std.debug.print("\n", .{});

    std.debug.print("8. Timeout example:\n", .{});
    await timeout_example();
    std.debug.print("\n", .{});

    std.debug.print("All examples completed!\n", .{});
}

// Helper: Sleep function (would be provided by async runtime)
async fn sleep(duration: Duration) void {
    // Implementation would interact with async runtime
    _ = duration;
}

const Duration = struct {
    nanos: u64,

    pub fn from_millis(ms: u64) Duration {
        return Duration{ .nanos = ms * 1_000_000 };
    }

    pub fn from_secs(secs: u64) Duration {
        return Duration{ .nanos = secs * 1_000_000_000 };
    }
};

const Context = struct {
    pub fn wake_later(self: &Context, delay_ms: u64) void {
        _ = self;
        _ = delay_ms;
    }
};
