# Concurrency and Async in K Language

## Overview

K Language provides fearless concurrency through its ownership and type systems. The design combines Rust's Send/Sync traits for thread safety with explicit async/await syntax for asynchronous programming.

## Design Principles

1. **Compile-time thread safety** - Data race prevention via type system
2. **Zero-cost abstractions** - No runtime overhead for unused features
3. **Explicit async** - Clear distinction between sync and async code
4. **Colorless functions** - Async is a library feature, not deeply baked into the language
5. **No implicit runtime** - Users choose their async runtime (or none)

## Thread Safety: Send and Sync

K uses marker traits to ensure thread safety at compile time:

### Send Trait

A type is `Send` if it can be safely transferred between threads.

```k
// Send allows moving ownership between threads
trait Send {}

// Most types are automatically Send
const Data = struct {
    value: i32,
};  // Automatically implements Send

// Opt-out for types that shouldn't cross threads
const !Send LocalData = struct {
    thread_id: usize,
};
```

### Sync Trait

A type is `Sync` if it can be safely shared between threads via immutable references.

```k
// Sync means &T is Send
trait Sync {}

// T is Sync if sharing &T between threads is safe
// Rule: T is Sync if and only if &T is Send

// Example: AtomicI32 is Sync
const AtomicI32 = struct {
    value: i32,

    pub fn load(self: &AtomicI32) i32 {
        // Atomic load
    }

    pub fn store(self: &AtomicI32, value: i32) void {
        // Atomic store
    }
};  // Implements Sync

// Example: Cell is NOT Sync (interior mutability without atomics)
const !Sync Cell = struct {
    value: i32,

    pub fn get(self: &Cell) i32 {
        return self.value;
    }

    pub fn set(self: &Cell, value: i32) void {
        // UNSAFE: Multiple threads could call this
        self.value = value;
    }
};
```

### Send/Sync Rules

```k
// Generic type T
// - T is Send if it can be moved between threads
// - T is Sync if &T can be shared between threads

// Raw pointers are neither Send nor Sync by default
const !Send !Sync RawPtr = struct {
    ptr: *mut u8,
};

// RefCell is Send but NOT Sync
const !Sync RefCell = struct {
    value: i32,
    borrowed: bool,
};

// Arc (atomic reference counting) is both Send and Sync
const Arc = struct {
    ptr: *mut ArcInner,

    // Arc<T> is Send if T is Send + Sync
    // Arc<T> is Sync if T is Send + Sync
};
```

## Threads

### Creating Threads

```k
const std = @import("std");
const Thread = std.Thread;

fn spawn_threads(allocator: Allocator) !void {
    // Spawn a thread
    const handle = try Thread.spawn(.{}, worker_function, .{42});

    // Wait for thread to complete
    handle.join();
}

fn worker_function(value: i32) void {
    std.debug.print("Worker: {}\n", .{value});
}
```

### Thread Safety Example

```k
// This compiles - Counter is Send
fn safe_thread_example() !void {
    var counter = AtomicI32.init(0);

    const handle = try Thread.spawn(.{}, increment, .{&counter});

    counter.fetch_add(1);
    handle.join();

    std.debug.print("Final: {}\n", .{counter.load()});
}

fn increment(counter: &AtomicI32) void {
    counter.fetch_add(1);
}

// This does NOT compile - &mut is not Sync
fn unsafe_thread_example() !void {
    var counter: i32 = 0;

    // ERROR: &mut i32 is not Send
    // const handle = try Thread.spawn(.{}, bad_increment, .{&mut counter});
}
```

## Message Passing

K provides channels for safe message passing between threads:

```k
const std = @import("std");
const Channel = std.sync.Channel;

fn channel_example(allocator: Allocator) !void {
    var channel = try Channel(i32).init(allocator);
    defer channel.deinit();

    // Spawn sender thread
    const sender = try Thread.spawn(.{}, send_messages, .{&channel});

    // Receive messages
    while (channel.receive()) |value| {
        std.debug.print("Received: {}\n", .{value});
    }

    sender.join();
}

fn send_messages(channel: &Channel(i32)) void {
    for (0..10) |i| {
        channel.send(@intCast(i)) catch break;
    }
    channel.close();
}
```

## Shared State

### Mutex

```k
const std = @import("std");
const Mutex = std.Thread.Mutex;

const Counter = struct {
    mutex: Mutex,
    value: i32,

    pub fn init() Counter {
        return Counter{
            .mutex = Mutex{},
            .value = 0,
        };
    }

    pub fn increment(self: &Counter) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.value += 1;
    }

    pub fn get(self: &Counter) i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.value;
    }
};

fn mutex_example() !void {
    var counter = Counter.init();

    var threads: [10]Thread = undefined;
    for (&threads) |*handle| {
        handle.* = try Thread.spawn(.{}, increment_many, .{&counter});
    }

    for (threads) |handle| {
        handle.join();
    }

    std.debug.print("Final count: {}\n", .{counter.get()});
}

fn increment_many(counter: &Counter) void {
    for (0..1000) |_| {
        counter.increment();
    }
}
```

### RwLock (Read-Write Lock)

```k
const RwLock = std.Thread.RwLock;

const SharedData = struct {
    lock: RwLock,
    data: []u8,

    pub fn read(self: &SharedData, index: usize) u8 {
        self.lock.lockShared();
        defer self.lock.unlockShared();

        return self.data[index];
    }

    pub fn write(self: &SharedData, index: usize, value: u8) void {
        self.lock.lock();
        defer self.lock.unlock();

        self.data[index] = value;
    }
};
```

## Async/Await

K supports asynchronous programming with async functions and the await keyword:

### Async Functions

```k
// Async function returns a Future
async fn fetch_data(url: []const u8) ![]const u8 {
    const response = await http_get(url);
    return response.body;
}

async fn http_get(url: []const u8) !Response {
    // Async I/O operation
    // ...
}
```

### Future Trait

```k
// Future is a trait that async functions implement
trait Future {
    type Output;

    fn poll(self: &mut Self, context: &Context) Poll(Self.Output);
}

// Poll result
const Poll = enum {
    Ready: T,
    Pending,
};
```

### Async Example

```k
const std = @import("std");

async fn download_file(url: []const u8, allocator: Allocator) ![]u8 {
    std.debug.print("Starting download: {s}\n", .{url});

    const response = await http_get(url);
    defer response.deinit();

    if (response.status != 200) {
        return error.HttpError;
    }

    return try allocator.dupe(u8, response.body);
}

async fn process_urls(urls: [][]const u8, allocator: Allocator) !void {
    // Await multiple futures concurrently
    var tasks = std.ArrayList(Task([]u8)).init(allocator);
    defer tasks.deinit();

    for (urls) |url| {
        const task = async download_file(url, allocator);
        try tasks.append(task);
    }

    // Await all tasks
    for (tasks.items) |task| {
        const data = await task;
        defer allocator.free(data);

        std.debug.print("Downloaded {} bytes\n", .{data.len});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const urls = [_][]const u8{
        "https://example.com/file1",
        "https://example.com/file2",
        "https://example.com/file3",
    };

    // Run async function
    await process_urls(&urls, allocator);
}
```

### Async Runtime

K doesn't mandate a specific async runtime. Users can choose:

```k
// Example: Using a custom runtime
const Runtime = @import("async_runtime");

pub fn main() !void {
    var runtime = Runtime.init();
    defer runtime.deinit();

    runtime.block_on(async_main());
}

async fn async_main() !void {
    const result = await compute();
    std.debug.print("Result: {}\n", .{result});
}

async fn compute() i32 {
    // Async computation
    return 42;
}
```

### Select (Waiting on Multiple Futures)

```k
async fn select_example() !void {
    const task1 = async slow_operation();
    const task2 = async fast_operation();

    // Wait for first to complete
    const result = select(.{task1, task2});

    switch (result) {
        .task1 => |value| std.debug.print("Task 1: {}\n", .{value}),
        .task2 => |value| std.debug.print("Task 2: {}\n", .{value}),
    }
}

async fn slow_operation() i32 {
    await sleep(Duration.from_secs(5));
    return 1;
}

async fn fast_operation() i32 {
    await sleep(Duration.from_millis(100));
    return 2;
}
```

## Atomics

K provides atomic types for lock-free programming:

```k
const std = @import("std");
const Atomic = std.atomic;

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

    pub fn load(self: &AtomicCounter) i32 {
        return self.value.load(.SeqCst);
    }

    pub fn store(self: &AtomicCounter, value: i32) void {
        self.value.store(value, .SeqCst);
    }

    pub fn compare_exchange(
        self: &AtomicCounter,
        expected: i32,
        desired: i32,
    ) bool {
        return self.value.compareAndSwap(
            expected,
            desired,
            .SeqCst,
            .SeqCst,
        ) == expected;
    }
};
```

### Memory Ordering

```k
// Memory orderings for atomic operations
const Ordering = enum {
    Relaxed,   // No synchronization
    Acquire,   // Load barrier
    Release,   // Store barrier
    AcqRel,    // Both barriers
    SeqCst,    // Sequential consistency (strongest)
};

// Example usage
fn lock_free_stack_push(
    head: &Atomic.Value(?*Node),
    node: *Node,
) void {
    var current = head.load(.Relaxed);

    while (true) {
        node.next = current;

        // Try to swap
        const result = head.compareAndSwap(
            current,
            node,
            .Release,  // Ensure writes to node are visible
            .Relaxed,  // Load doesn't need ordering on failure
        );

        if (result == current) break;  // Success
        current = result;  // Retry with new value
    }
}
```

## Comparison with Rust and Zig

| Feature | Rust | Zig | K |
|---------|------|-----|---|
| Thread safety | Send/Sync traits | Manual | Send/Sync traits |
| Async/await | Yes (built-in) | No (callbacks) | Yes (library-based) |
| Async runtime | Required (tokio, async-std) | N/A | Optional (user choice) |
| Atomics | Yes | Yes | Yes |
| Channels | mpsc (std) | No (user impl) | Yes (std) |
| Memory ordering | Explicit | Explicit | Explicit |
| Data race prevention | Compile-time | Runtime/manual | Compile-time |

## Design Rationale

### Why Send/Sync?

1. **Compile-time safety** - Data races are impossible with safe code
2. **Explicit threading** - Types declare their thread-safety guarantees
3. **Composability** - Generic code automatically gets thread-safety bounds

### Why Library-Based Async?

1. **Flexibility** - No forced runtime overhead
2. **Systems programming** - Embedded/kernel code may not want async
3. **Runtime choice** - Different async runtimes for different use cases
4. **Gradual adoption** - Can mix sync and async code

### Why Explicit Memory Ordering?

1. **Performance** - Weaker orderings allow compiler/CPU optimizations
2. **Correctness** - SeqCst is safe default, experts can optimize
3. **Transparency** - No hidden synchronization costs

## Thread Safety Example

```k
// Compile-time enforcement prevents data races
const SharedCounter = struct {
    value: AtomicI32,
};

impl Send for SharedCounter {}
impl Sync for SharedCounter {}

// This is safe - SharedCounter is Sync
fn safe_sharing() !void {
    const counter = SharedCounter{ .value = AtomicI32.init(0) };

    var threads: [4]Thread = undefined;
    for (&threads) |*handle| {
        handle.* = try Thread.spawn(.{}, worker, .{&counter});
    }

    for (threads) |handle| {
        handle.join();
    }
}

fn worker(counter: &SharedCounter) void {
    counter.value.fetch_add(1);
}

// This does NOT compile - &mut is not Sync
const UnsafeCounter = struct {
    value: i32,
};

// ERROR: Cannot share &mut UnsafeCounter between threads
// fn unsafe_sharing() !void {
//     var counter = UnsafeCounter{ .value = 0 };
//     const handle = try Thread.spawn(.{}, bad_worker, .{&mut counter});
// }
```

## Future Directions

1. **Async iterators** - `async for` loops over async sequences
2. **Async traits** - Traits with async methods
3. **Structured concurrency** - Scoped tasks that must complete before scope exit
4. **Work-stealing scheduler** - Efficient task scheduling in std library
5. **Async drop** - Cleanup that can be async

## References

- [Rust Concurrency](https://doc.rust-lang.org/book/ch16-00-concurrency.html)
- [Rust Async Book](https://rust-lang.github.io/async-book/)
- [Zig Async (archived)](https://kristoff.it/blog/zig-colorblind-async-await/)
- [C++ Memory Ordering](https://en.cppreference.com/w/cpp/atomic/memory_order)
