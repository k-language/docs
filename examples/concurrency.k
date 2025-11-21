// Concurrency Examples in K Language

const std = @import("std");
const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;
const Atomic = std.atomic;
const Allocator = std.mem.Allocator;

// Example 1: Basic Thread Spawning
fn worker(id: usize) void {
    std.debug.print("Worker {} starting\n", .{id});

    var sum: usize = 0;
    for (0..1000) |i| {
        sum += i;
    }

    std.debug.print("Worker {} finished, sum = {}\n", .{id, sum});
}

fn basic_threads_example() !void {
    std.debug.print("=== Basic Threads Example ===\n", .{});

    var threads: [4]Thread = undefined;

    // Spawn threads
    for (&threads, 0..) |*handle, i| {
        handle.* = try Thread.spawn(.{}, worker, .{i});
    }

    // Wait for all threads
    for (threads) |handle| {
        handle.join();
    }

    std.debug.print("All threads completed\n\n", .{});
}

// Example 2: Atomic Counter
const AtomicCounter = struct {
    value: Atomic.Value(i32),

    pub fn init(initial: i32) AtomicCounter {
        return AtomicCounter{
            .value = Atomic.Value(i32).init(initial),
        };
    }

    pub fn increment(self: &AtomicCounter) i32 {
        return self.value.fetchAdd(1, .SeqCst);
    }

    pub fn get(self: &AtomicCounter) i32 {
        return self.value.load(.SeqCst);
    }
};

fn atomic_worker(counter: &AtomicCounter, iterations: usize) void {
    for (0..iterations) |_| {
        _ = counter.increment();
    }
}

fn atomic_counter_example() !void {
    std.debug.print("=== Atomic Counter Example ===\n", .{});

    var counter = AtomicCounter.init(0);

    const thread_count = 10;
    const iterations = 1000;

    var threads: [thread_count]Thread = undefined;

    for (&threads) |*handle| {
        handle.* = try Thread.spawn(.{}, atomic_worker, .{&counter, iterations});
    }

    for (threads) |handle| {
        handle.join();
    }

    const final_value = counter.get();
    const expected = thread_count * iterations;

    std.debug.print("Final value: {} (expected: {})\n", .{final_value, expected});
    std.debug.print("Correct: {}\n\n", .{final_value == expected});
}

// Example 3: Mutex-Protected Shared State
const SharedCounter = struct {
    mutex: Mutex,
    value: i32,

    pub fn init() SharedCounter {
        return SharedCounter{
            .mutex = Mutex{},
            .value = 0,
        };
    }

    pub fn increment(self: &SharedCounter) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.value += 1;
    }

    pub fn get(self: &SharedCounter) i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.value;
    }
};

fn mutex_worker(counter: &SharedCounter, iterations: usize) void {
    for (0..iterations) |_| {
        counter.increment();
    }
}

fn mutex_example() !void {
    std.debug.print("=== Mutex Example ===\n", .{});

    var counter = SharedCounter.init();

    var threads: [5]Thread = undefined;

    for (&threads) |*handle| {
        handle.* = try Thread.spawn(.{}, mutex_worker, .{&counter, 1000});
    }

    for (threads) |handle| {
        handle.join();
    }

    std.debug.print("Final count: {}\n\n", .{counter.get()});
}

// Example 4: Read-Write Lock
const SharedData = struct {
    lock: RwLock,
    data: []i32,
    allocator: Allocator,

    pub fn init(allocator: Allocator, size: usize) !SharedData {
        const data = try allocator.alloc(i32, size);
        @memset(data, 0);

        return SharedData{
            .lock = RwLock{},
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: &mut SharedData) void {
        self.allocator.free(self.data);
    }

    pub fn read(self: &SharedData, index: usize) i32 {
        self.lock.lockShared();
        defer self.lock.unlockShared();

        return self.data[index];
    }

    pub fn write(self: &SharedData, index: usize, value: i32) void {
        self.lock.lock();
        defer self.lock.unlock();

        self.data[index] = value;
    }

    pub fn sum(self: &SharedData) i32 {
        self.lock.lockShared();
        defer self.lock.unlockShared();

        var total: i32 = 0;
        for (self.data) |value| {
            total += value;
        }
        return total;
    }
};

fn reader_thread(data: &SharedData, id: usize) void {
    for (0..100) |_| {
        const sum = data.sum();
        if (id == 0) {  // Only first reader prints
            std.debug.print("Sum: {}\n", .{sum});
        }
        std.time.sleep(1_000_000);  // 1ms
    }
}

fn writer_thread(data: &SharedData, id: usize) void {
    for (0..10) |i| {
        data.write(id, @intCast(i * 10));
        std.time.sleep(10_000_000);  // 10ms
    }
}

fn rwlock_example(allocator: Allocator) !void {
    std.debug.print("=== RwLock Example ===\n", .{});

    var data = try SharedData.init(allocator, 4);
    defer data.deinit();

    const reader_count = 3;
    const writer_count = 4;

    var readers: [reader_count]Thread = undefined;
    var writers: [writer_count]Thread = undefined;

    // Spawn readers
    for (&readers, 0..) |*handle, i| {
        handle.* = try Thread.spawn(.{}, reader_thread, .{&data, i});
    }

    // Spawn writers
    for (&writers, 0..) |*handle, i| {
        handle.* = try Thread.spawn(.{}, writer_thread, .{&data, i});
    }

    // Wait for all
    for (readers) |handle| handle.join();
    for (writers) |handle| handle.join();

    std.debug.print("Final data: {any}\n\n", .{data.data});
}

// Example 5: Channel Communication
const Channel = std.sync.Channel;

fn sender_thread(channel: &Channel(i32), count: usize) !void {
    for (0..count) |i| {
        try channel.send(@intCast(i));
        std.debug.print("Sent: {}\n", .{i});
        std.time.sleep(100_000_000);  // 100ms
    }
    channel.close();
}

fn receiver_thread(channel: &Channel(i32)) void {
    while (channel.receive()) |value| {
        std.debug.print("Received: {}\n", .{value});
    }
    std.debug.print("Channel closed\n", .{});
}

fn channel_example(allocator: Allocator) !void {
    std.debug.print("=== Channel Example ===\n", .{});

    var channel = try Channel(i32).init(allocator);
    defer channel.deinit();

    const sender = try Thread.spawn(.{}, sender_thread, .{&channel, 5});
    const receiver = try Thread.spawn(.{}, receiver_thread, .{&channel});

    sender.join();
    receiver.join();

    std.debug.print("\n", .{});
}

// Example 6: Send and Sync Traits
// Types must be Send to transfer between threads
// Types must be Sync to share references between threads

const SendType = struct {
    value: i32,
};
// Automatically implements Send

const !Sync CellType = struct {
    value: i32,

    pub fn get(self: &CellType) i32 {
        return self.value;
    }

    pub fn set(self: &CellType, value: i32) void {
        // UNSAFE without synchronization
        @constCast(self).value = value;
    }
};

// This compiles - SendType is Send and Sync
fn send_sync_safe() !void {
    const data = SendType{ .value = 42 };

    const handle = try Thread.spawn(.{}, use_send_type, .{data});
    handle.join();
}

fn use_send_type(data: SendType) void {
    std.debug.print("Value: {}\n", .{data.value});
}

// This does NOT compile - CellType is !Sync
// fn send_sync_unsafe() !void {
//     var data = CellType{ .value = 42 };
//     const handle = try Thread.spawn(.{}, use_cell_type, .{&data});
//     handle.join();
// }

// Example 7: Lock-Free Stack
const LockFreeStack = struct {
    head: Atomic.Value(?*Node),

    const Node = struct {
        value: i32,
        next: ?*Node,
    };

    pub fn init() LockFreeStack {
        return LockFreeStack{
            .head = Atomic.Value(?*Node).init(null),
        };
    }

    pub fn push(self: &LockFreeStack, allocator: Allocator, value: i32) !void {
        const node = try allocator.create(Node);
        node.* = Node{ .value = value, .next = null };

        var current = self.head.load(.Acquire);

        while (true) {
            node.next = current;

            const result = self.head.compareAndSwap(
                current,
                node,
                .Release,
                .Acquire,
            );

            if (result == current) break;  // Success
            current = result;  // Retry with new value
        }
    }

    pub fn pop(self: &LockFreeStack) ?i32 {
        var current = self.head.load(.Acquire);

        while (current) |node| {
            const next = node.next;

            const result = self.head.compareAndSwap(
                current,
                next,
                .Release,
                .Acquire,
            );

            if (result == current) {
                return node.value;
            }

            current = result;
        }

        return null;
    }
};

fn stack_worker(
    stack: &LockFreeStack,
    allocator: Allocator,
    id: usize,
) !void {
    // Push values
    for (0..10) |i| {
        try stack.push(allocator, @intCast(id * 100 + i));
    }

    // Pop values
    for (0..10) |_| {
        if (stack.pop()) |value| {
            std.debug.print("Thread {} popped: {}\n", .{id, value});
        }
    }
}

fn lockfree_stack_example(allocator: Allocator) !void {
    std.debug.print("=== Lock-Free Stack Example ===\n", .{});

    var stack = LockFreeStack.init();

    var threads: [4]Thread = undefined;

    for (&threads, 0..) |*handle, i| {
        handle.* = try Thread.spawn(.{}, stack_worker, .{&stack, allocator, i});
    }

    for (threads) |handle| {
        handle.join();
    }

    std.debug.print("\n", .{});
}

// Example 8: Thread Pool
const ThreadPool = struct {
    threads: []Thread,
    queue: std.ArrayList(Task),
    mutex: Mutex,
    allocator: Allocator,
    shutdown: Atomic.Value(bool),

    const Task = struct {
        func: *const fn(*anyopaque) void,
        data: *anyopaque,
    };

    pub fn init(allocator: Allocator, thread_count: usize) !ThreadPool {
        var threads = try allocator.alloc(Thread, thread_count);
        errdefer allocator.free(threads);

        var pool = ThreadPool{
            .threads = threads,
            .queue = std.ArrayList(Task).init(allocator),
            .mutex = Mutex{},
            .allocator = allocator,
            .shutdown = Atomic.Value(bool).init(false),
        };

        for (threads) |*handle| {
            handle.* = try Thread.spawn(.{}, worker_loop, .{&pool});
        }

        return pool;
    }

    fn worker_loop(self: &ThreadPool) void {
        while (!self.shutdown.load(.Acquire)) {
            self.mutex.lock();

            const task = if (self.queue.items.len > 0)
                self.queue.orderedRemove(0)
            else
                null;

            self.mutex.unlock();

            if (task) |t| {
                t.func(t.data);
            } else {
                std.time.sleep(1_000_000);  // 1ms
            }
        }
    }

    pub fn submit(self: &ThreadPool, func: *const fn(*anyopaque) void, data: *anyopaque) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.queue.append(Task{ .func = func, .data = data });
    }

    pub fn shutdown(self: &mut ThreadPool) void {
        self.shutdown.store(true, .Release);

        for (self.threads) |handle| {
            handle.join();
        }

        self.allocator.free(self.threads);
        self.queue.deinit();
    }
};

fn pool_task(data: *anyopaque) void {
    const id = @ptrCast(*usize, @alignCast(@alignOf(usize), data));
    std.debug.print("Task {} executing\n", .{id.*});
    std.time.sleep(100_000_000);  // 100ms
}

fn threadpool_example(allocator: Allocator) !void {
    std.debug.print("=== Thread Pool Example ===\n", .{});

    var pool = try ThreadPool.init(allocator, 4);
    defer pool.shutdown();

    var task_ids: [10]usize = undefined;
    for (&task_ids, 0..) |*id, i| {
        id.* = i;
        try pool.submit(pool_task, id);
    }

    std.time.sleep(2_000_000_000);  // 2 seconds
    std.debug.print("\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Concurrency Examples ===\n\n", .{});

    try basic_threads_example();
    try atomic_counter_example();
    try mutex_example();
    try rwlock_example(allocator);
    try channel_example(allocator);
    try lockfree_stack_example(allocator);
    try threadpool_example(allocator);

    std.debug.print("All concurrency examples completed!\n", .{});
}
