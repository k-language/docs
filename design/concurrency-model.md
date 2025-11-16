# K Language Concurrency Model

## Overview

This document specifies K's comprehensive concurrency model, combining the best ideas from Rust, Swift, C++26, and Zig:

- **Threads** - OS-level parallelism
- **Coroutines/Generators** - Cooperative multitasking with `yield`
- **Async/Await** - Asynchronous programming with futures
- **Structured Concurrency** - Safe task management (Swift/Kotlin style)
- **Sender/Receiver** - Composable async operations (C++26 style)
- **Lock-free Primitives** - Hazard pointers and RCU
- **Synchronization** - Mutex, RwLock, Latch, Barrier, Semaphore
- **Atomics** - Lock-free operations

**Design Principles**:
- ✅ **Safe by default** - Leverages borrow checking
- ✅ **Zero-cost abstraction** - No runtime overhead
- ✅ **Composable** - Mix and match primitives
- ✅ **Integrated with error handling** - Works with `!T`

---

## Part 1: Thread Model

### Basic Thread Abstraction

```k
const std = @import("std");
const Thread = std.thread.Thread;

fn worker(arg: *u32) void {
  arg.* += 1;
}

// Spawn thread
var value: u32 = 0;
const thread = try Thread.spawn(.{}, worker, .{&value});

// Join thread
thread.join();
std.debug.print("Result: {}\n", .{value});  // 1
```

### Thread with Return Value

```k
fn compute(n: u32) u32 {
  return n * n;
}

const thread = try Thread.spawn(.{}, compute, .{42});
const result = thread.join();  // Returns u32
std.debug.print("Result: {}\n", .{result});  // 1764
```

### Thread-Safe Communication

```k
const Channel = std.sync.Channel;

fn producer(ch: &Channel(i32)) void {
  for (0..10) |i| {
    ch.send(@intCast(i));
  }
  ch.close();
}

fn consumer(ch: &Channel(i32)) void {
  while (ch.recv()) |value| {
    std.debug.print("Received: {}\n", .{value});
  }
}

const ch = Channel(i32).init(allocator);
defer ch.deinit();

const prod = try Thread.spawn(.{}, producer, .{&ch});
const cons = try Thread.spawn(.{}, consumer, .{&ch});

prod.join();
cons.join();
```

---

## Part 2: Coroutines and Generators

### Generator Syntax

**Basic generator** with `yield`:

```k
fn fibonacci() Generator(i32) {
  var a: i32 = 0;
  var b: i32 = 1;
  while (true) {
    yield a;
    const next = a + b;
    a = b;
    b = next;
  }
}

// Usage
const fib = fibonacci();
for (fib.take(10)) |n| {
  std.debug.print("{} ", .{n});
}
// Output: 0 1 1 2 3 5 8 13 21 34
```

### Generator Type

```k
const Generator = struct(T: type) {
  state: GeneratorState,
  resume_fn: *const fn(&GeneratorState) ?T,

  fn next(self: &mut Self) ?T {
    return self.resume_fn(&self.state);
  }
};

// Implements Iterator trait
impl Iterator for Generator(T) {
  type Item = T;

  fn next(self: &mut Self) ?Self.Item {
    return self.next();
  }
}
```

### Generator with Error Handling

```k
fn parse_lines(file: File) Generator(![]const u8) {
  var buffer: [1024]u8 = undefined;
  while (true) {
    const line = file.read_line(&buffer) catch |err| {
      yield error.ReadError;
      break;
    };
    if (line.len == 0) break;
    yield line;
  }
}

// Usage
const lines = parse_lines(file);
for (lines) |line| {
  const text = try line;  // Propagate errors
  process(text);
}
```

### Finite Generator

```k
fn range(start: i32, end: i32) Generator(i32) {
  var i = start;
  while (i < end) {
    yield i;
    i += 1;
  }
  // Generator ends when function returns
}

// Usage
const nums = range(1, 5);
for (nums) |n| {
  std.debug.print("{} ", .{n});  // 1 2 3 4
}
```

### Generator with State

```k
fn counter(initial: i32) Generator(i32) {
  var count = initial;
  while (true) {
    yield count;
    count += 1;
  }
}

const c1 = counter(0);
const c2 = counter(100);

std.debug.print("{}\n", .{c1.next()});  // 0
std.debug.print("{}\n", .{c1.next()});  // 1
std.debug.print("{}\n", .{c2.next()});  // 100
```

---

## Part 3: Async/Await

### Basic Async Function

```k
async fn fetch_user(id: u64) !User {
  const response = await http.get("/users/{id}");
  if (response.status != 200) {
    return error.UserNotFound;
  }
  return try json.parse(User, response.body);
}

// Call async function
const user = try await fetch_user(42);
```

### Future Type

```k
const Future = struct(T: type) {
  state: FutureState,
  poll_fn: *const fn(&FutureState, &Waker) Poll(T),

  fn poll(self: &mut Self, waker: &Waker) Poll(T) {
    return self.poll_fn(&self.state, waker);
  }
};

const Poll = enum(T: type) {
  Ready: T,
  Pending,
};
```

### Async Block

```k
const future = async {
  const user = try await fetch_user(42);
  const posts = try await fetch_posts(user.id);
  return posts;
};

const posts = try await future;
```

### Combining Futures

```k
// Run in parallel, wait for all
const results = try await all(.{
  fetch_user(1),
  fetch_user(2),
  fetch_user(3),
});

// Run in parallel, wait for first
const winner = try await race(.{
  fetch_user(1),
  fetch_user(2),
  fetch_user(3),
});

// Sequential (await each)
const user = try await fetch_user(1);
const posts = try await fetch_posts(user.id);
```

---

## Part 4: Structured Concurrency

### Task Groups (Swift/Kotlin Style)

**Core concept**: Tasks are scoped and automatically awaited.

```k
async fn fetch_all_users(ids: []const u64) ![]User {
  return try task_group([]User, async {
    var results = ArrayList(User).init(allocator);

    for (ids) |id| {
      // Spawn child task
      spawn async {
        const user = try await fetch_user(id);
        try results.append(user);
      };
    }

    // All spawned tasks automatically awaited here
    return results.toOwnedSlice();
  });
}
```

### Task Cancellation

```k
async fn search_with_timeout(query: []const u8) !SearchResult {
  return try task_group(SearchResult, async {
    const search_task = spawn async {
      return try await slow_search(query);
    };

    const timeout_task = spawn async {
      await sleep(Duration.seconds(5));
      return error.Timeout;
    };

    // First to complete wins, others are cancelled
    return try await race(.{search_task, timeout_task});
  });
}
```

### Cancellation Token

```k
async fn download_file(url: []const u8, cancel: &CancelToken) !void {
  var total: usize = 0;
  while (true) {
    // Check cancellation
    if (cancel.is_cancelled()) {
      return error.Cancelled;
    }

    const chunk = try await fetch_chunk(url, total);
    if (chunk.len == 0) break;

    try write_chunk(chunk);
    total += chunk.len;
  }
}

// Usage
const cancel = CancelToken.init();

const task = spawn async {
  try await download_file(url, &cancel);
};

// Cancel from another task
await sleep(Duration.seconds(10));
cancel.cancel();
```

### Scoped Tasks

```k
async fn process_batch(items: []const Item) !void {
  // All tasks scoped to this function
  try task_scope(async {
    for (items) |item| {
      spawn async {
        try await process_item(item);
      };
    }
    // All spawned tasks automatically joined here
  });
  // Guaranteed: all tasks are done
}
```

---

## Part 5: Sender/Receiver (C++26 Style)

### Composable Async Operations

**Core concept**: Separate **work description** from **execution**.

```k
const Sender = trait {
  type Value;
  type Error;

  fn connect(self, receiver: &Receiver) OperationState;
};

const Receiver = trait {
  fn set_value(self, value: Value) void;
  fn set_error(self, error: Error) void;
  fn set_done(self) void;
};
```

### Basic Sender

```k
// Create sender
const work = sender.just(42)
  .then(|x| x * 2)
  .then(|x| format("Result: {x}"));

// Execute on scheduler
const result = try await work.on(thread_pool);
```

### Sender Algorithms

```k
// Transform value
const doubled = sender.just(21).then(|x| x * 2);

// Error handling
const safe = sender.just(divide(10, 0))
  .or_else(|_| sender.just(0));

// Conditional
const result = sender.just(42)
  .let_value(|x| {
    if (x > 50) {
      return sender.just("high");
    } else {
      return sender.just("low");
    }
  });

// Parallel composition
const combined = sender.when_all(.{
  fetch_user(1),
  fetch_user(2),
  fetch_user(3),
});

// Sequential composition
const pipeline = fetch_user(1)
  .let_value(|user| fetch_posts(user.id))
  .let_value(|posts| format_posts(posts));
```

### Custom Scheduler

```k
const Scheduler = trait {
  fn schedule(self) Sender(void, Error);
};

const ThreadPoolScheduler = struct {
  pool: &ThreadPool,

  fn schedule(self: Self) Sender(void, Error) {
    return make_sender(|receiver| {
      self.pool.enqueue(|| {
        receiver.set_value({});
      });
    });
  }
};

// Execute on custom scheduler
const result = try await work.on(my_scheduler);
```

### GPU Scheduler Example

```k
const GpuScheduler = struct {
  device: &GpuDevice,

  fn schedule(self: Self) Sender(void, Error) {
    return make_sender(|receiver| {
      self.device.submit_work(|| {
        receiver.set_value({});
      });
    });
  }
};

// Chain GPU operations without synchronization
const result = sender.just(input_data)
  .on(gpu_scheduler)
  .then(|data| kernel_1(data))
  .then(|data| kernel_2(data))
  .then(|data| kernel_3(data))
  .on(cpu_scheduler);  // Bring back to CPU
```

---

## Part 6: Lock-Free Primitives

### Atomics

```k
const Atomic = std.atomic.Atomic;

var counter = Atomic(u32).init(0);

// Atomic operations
counter.fetch_add(1, .release);
const value = counter.load(.acquire);
const old = counter.swap(42, .acq_rel);
const success = counter.compare_exchange_weak(old, new, .release, .acquire);
```

### Memory Ordering

```k
const Ordering = enum {
  relaxed,   // No synchronization
  acquire,   // Synchronize loads
  release,   // Synchronize stores
  acq_rel,   // Both acquire and release
  seq_cst,   // Sequential consistency
};
```

### Hazard Pointers

**Problem**: How to safely reclaim memory in lock-free data structures?

**Solution**: Each thread announces what pointers it's using.

```k
const HazardPointer = struct {
  domain: &HazardPointerDomain,
  protected: Atomic(?&anyopaque),

  fn protect(self: &Self, ptr: &T) &T {
    self.protected.store(ptr, .release);
    std.atomic.fence(.seq_cst);
    return ptr;
  }

  fn clear(self: &Self) void {
    self.protected.store(null, .release);
  }

  fn retire(self: &Self, ptr: &T) void {
    self.domain.retire(ptr);
  }
};

const HazardPointerDomain = struct {
  hazard_pointers: []HazardPointer,
  retired_list: RetiredList,

  fn acquire(self: &mut Self) &HazardPointer {
    // Find available hazard pointer
    for (self.hazard_pointers) |*hp| {
      if (hp.protected.load(.acquire) == null) {
        return hp;
      }
    }
    unreachable;
  }

  fn retire(self: &mut Self, ptr: &anyopaque) void {
    self.retired_list.push(ptr);

    // Try to reclaim if list is large enough
    if (self.retired_list.len() > THRESHOLD) {
      self.reclaim();
    }
  }

  fn reclaim(self: &mut Self) void {
    // Scan all hazard pointers
    var protected_set = HashSet.init(allocator);
    for (self.hazard_pointers) |hp| {
      if (hp.protected.load(.acquire)) |ptr| {
        protected_set.insert(ptr);
      }
    }

    // Reclaim pointers not in protected set
    self.retired_list.retain(|ptr| {
      if (!protected_set.contains(ptr)) {
        allocator.destroy(ptr);
        return false;
      }
      return true;
    });
  }
};
```

### Lock-Free Stack with Hazard Pointers

```k
const LockFreeStack = struct(T: type) {
  head: Atomic(?&Node(T)),
  hp_domain: HazardPointerDomain,

  const Node = struct(T: type) {
    value: T,
    next: ?&Node(T),
  };

  fn push(self: &Self, value: T) !void {
    const new_node = try allocator.create(Node(T){
      .value = value,
      .next = undefined,
    });

    while (true) {
      const old_head = self.head.load(.acquire);
      new_node.next = old_head;

      if (self.head.compare_exchange_weak(
        old_head,
        new_node,
        .release,
        .relaxed
      )) {
        return;
      }
    }
  }

  fn pop(self: &Self) ?T {
    const hp = self.hp_domain.acquire();
    defer hp.clear();

    while (true) {
      const head = self.head.load(.acquire);
      if (head == null) return null;

      // Protect the head node
      const protected_head = hp.protect(head.?);

      // Verify head didn't change
      if (self.head.load(.acquire) != head) {
        continue;  // Retry
      }

      const next = protected_head.next;

      // Try to swing head to next
      if (self.head.compare_exchange_weak(
        head,
        next,
        .release,
        .relaxed
      )) {
        const value = protected_head.value;
        hp.retire(protected_head);
        return value;
      }
    }
  }
};
```

### RCU (Read-Copy-Update)

**Problem**: Scalable read-mostly data structures.

**Solution**: Readers don't block; writers make a copy, update, then atomically swap.

```k
const Rcu = struct(T: type) {
  data: Atomic(&T),

  fn read<R>(self: &Self, reader: fn(&T) R) R {
    rcu.read_lock();
    defer rcu.read_unlock();

    const ptr = self.data.load(.acquire);
    return reader(ptr);
  }

  fn update(self: &Self, updater: fn(&T) T) !void {
    // Make a copy
    const old_ptr = self.data.load(.acquire);
    const new_data = updater(old_ptr);
    const new_ptr = try allocator.create(new_data);

    // Atomically swap
    const old = self.data.swap(new_ptr, .release);

    // Wait for readers to finish (grace period)
    rcu.synchronize();

    // Safe to free old data
    allocator.destroy(old);
  }
};

// RCU read-side critical section
fn rcu_read_lock() void {
  // Increment thread-local nesting count
  const tls = get_tls();
  tls.rcu_nesting += 1;
  std.atomic.fence(.seq_cst);
}

fn rcu_read_unlock() void {
  std.atomic.fence(.seq_cst);
  const tls = get_tls();
  tls.rcu_nesting -= 1;
}

fn rcu_synchronize() void {
  // Wait for all existing readers to exit critical section
  // (Implementation is complex, involves quiescent states)
}
```

### RCU-Protected List Example

```k
const RcuList = struct(T: type) {
  head: Atomic(?&Node(T)),

  const Node = struct(T: type) {
    value: T,
    next: Atomic(?&Node(T)),
  };

  fn insert(self: &Self, value: T) !void {
    const new_node = try allocator.create(Node(T){
      .value = value,
      .next = Atomic(?&Node(T)).init(null),
    });

    while (true) {
      const old_head = self.head.load(.acquire);
      new_node.next.store(old_head, .release);

      if (self.head.compare_exchange_weak(
        old_head,
        new_node,
        .release,
        .relaxed
      )) {
        return;
      }
    }
  }

  fn remove(self: &Self, value: T) bool {
    while (true) {
      var prev: ?&Node(T) = null;
      var curr = self.head.load(.acquire);

      while (curr) |node| {
        if (node.value == value) {
          const next = node.next.load(.acquire);

          if (prev) |p| {
            if (p.next.compare_exchange_weak(
              curr,
              next,
              .release,
              .relaxed
            )) {
              rcu.synchronize();  // Wait for readers
              allocator.destroy(node);
              return true;
            }
          } else {
            if (self.head.compare_exchange_weak(
              curr,
              next,
              .release,
              .relaxed
            )) {
              rcu.synchronize();
              allocator.destroy(node);
              return true;
            }
          }
          break;  // Retry
        }
        prev = node;
        curr = node.next.load(.acquire);
      }

      if (curr == null) return false;
    }
  }

  fn find(self: &Self, value: T) bool {
    rcu.read_lock();
    defer rcu.read_unlock();

    var curr = self.head.load(.acquire);
    while (curr) |node| {
      if (node.value == value) {
        return true;
      }
      curr = node.next.load(.acquire);
    }
    return false;
  }
};
```

---

## Part 7: Synchronization Primitives

### Mutex

```k
const Mutex = std.sync.Mutex;

var counter: u32 = 0;
var mutex = Mutex{};

fn increment() void {
  mutex.lock();
  defer mutex.unlock();
  counter += 1;
}

// RAII-style (safer)
fn increment_safe() void {
  const guard = mutex.lock();
  defer guard.unlock();
  counter += 1;
}
```

### RwLock (Reader-Writer Lock)

```k
const RwLock = std.sync.RwLock;

var data: []u8 = undefined;
var rwlock = RwLock{};

fn read() []u8 {
  const guard = rwlock.read_lock();
  defer guard.unlock();
  return data;  // Multiple readers allowed
}

fn write(new_data: []u8) void {
  const guard = rwlock.write_lock();
  defer guard.unlock();
  data = new_data;  // Exclusive writer
}
```

### Latch (Countdown)

```k
const Latch = struct {
  count: Atomic(usize),
  cond: Condition,
  mutex: Mutex,

  fn init(count: usize) Latch {
    return .{
      .count = Atomic(usize).init(count),
      .cond = Condition{},
      .mutex = Mutex{},
    };
  }

  fn count_down(self: &Self) void {
    const old = self.count.fetch_sub(1, .release);
    if (old == 1) {
      const guard = self.mutex.lock();
      defer guard.unlock();
      self.cond.broadcast();
    }
  }

  fn wait(self: &Self) void {
    const guard = self.mutex.lock();
    defer guard.unlock();

    while (self.count.load(.acquire) > 0) {
      self.cond.wait(&guard);
    }
  }
};

// Usage
var latch = Latch.init(3);

// Spawn 3 workers
for (0..3) |_| {
  const thread = try Thread.spawn(.{}, worker, .{&latch});
  thread.detach();
}

// Wait for all workers
latch.wait();
std.debug.print("All workers done!\n", .{});
```

### Barrier

```k
const Barrier = struct {
  count: usize,
  waiting: Atomic(usize),
  generation: Atomic(usize),
  mutex: Mutex,
  cond: Condition,

  fn init(count: usize) Barrier {
    return .{
      .count = count,
      .waiting = Atomic(usize).init(0),
      .generation = Atomic(usize).init(0),
      .mutex = Mutex{},
      .cond = Condition{},
    };
  }

  fn arrive_and_wait(self: &Self) bool {
    const guard = self.mutex.lock();
    defer guard.unlock();

    const gen = self.generation.load(.acquire);
    const waiting = self.waiting.fetch_add(1, .acq_rel) + 1;

    if (waiting == self.count) {
      // Last thread to arrive
      self.waiting.store(0, .release);
      self.generation.fetch_add(1, .release);
      self.cond.broadcast();
      return true;  // Leader
    } else {
      // Wait for others
      while (self.generation.load(.acquire) == gen) {
        self.cond.wait(&guard);
      }
      return false;
    }
  }
};

// Usage: parallel algorithm with phases
var barrier = Barrier.init(4);

fn worker(id: usize) void {
  while (true) {
    // Phase 1
    compute_phase_1(id);

    // Synchronize
    const is_leader = barrier.arrive_and_wait();
    if (is_leader) {
      std.debug.print("Phase 1 complete\n", .{});
    }

    // Phase 2
    compute_phase_2(id);

    // Synchronize
    _ = barrier.arrive_and_wait();
  }
}
```

### Semaphore

```k
const Semaphore = struct {
  count: Atomic(isize),
  mutex: Mutex,
  cond: Condition,

  fn init(count: usize) Semaphore {
    return .{
      .count = Atomic(isize).init(@intCast(count)),
      .mutex = Mutex{},
      .cond = Condition{},
    };
  }

  fn acquire(self: &Self) void {
    const guard = self.mutex.lock();
    defer guard.unlock();

    while (self.count.load(.acquire) <= 0) {
      self.cond.wait(&guard);
    }

    _ = self.count.fetch_sub(1, .release);
  }

  fn release(self: &Self) void {
    const guard = self.mutex.lock();
    defer guard.unlock();

    _ = self.count.fetch_add(1, .release);
    self.cond.signal();
  }
};

// Usage: resource pool
const MAX_CONNECTIONS = 10;
var pool_semaphore = Semaphore.init(MAX_CONNECTIONS);

fn use_connection() void {
  pool_semaphore.acquire();
  defer pool_semaphore.release();

  // Use connection (only 10 concurrent)
  perform_work();
}
```

---

## Part 8: Integration with Borrow Checking

### Send and Sync Traits

```k
// Send: Can be transferred across thread boundaries
trait Send {}

// Sync: Can be referenced from multiple threads
trait Sync {}

// Rules:
// &T is Send if T is Sync
// &mut T is Send if T is Send
```

### Auto-implementing Send/Sync

```k
// Most types are automatically Send and Sync
const Point = struct {
  x: i32,
  y: i32,
};  // Automatically Send + Sync

// Types containing non-Send are not Send
const NotSend = struct {
  rc: Rc(i32),  // Rc is not Send
};  // Automatically NOT Send

// Explicit opt-out
const ManualSend = struct {
  data: *u8,
} no_auto_send;  // Must manually implement Send if safe
```

### Thread Safety Verification

```k
fn spawn_thread<F: Fn() -> T, T: Send>(func: F) Thread(T) {
  // Compiler verifies:
  // 1. F is Send (can move to new thread)
  // 2. T is Send (return value can move back)
}

// Example error:
const rc = Rc(i32).init(42);
const thread = Thread.spawn(.{}, || {
  rc.get();  // ❌ Error: Rc<i32> is not Send
}, .{});
```

### Safe Shared Mutable State

```k
// ❌ Error: can't share mutable reference
var data: u32 = 0;
const t1 = Thread.spawn(.{}, || {
  data += 1;  // ❌ Error: data is not Sync
}, .{});

// ✅ Correct: use Atomic
var data = Atomic(u32).init(0);
const t1 = Thread.spawn(.{}, || {
  data.fetch_add(1, .release);  // ✅ OK
}, .{});

// ✅ Correct: use Mutex
var data: u32 = 0;
var mutex = Mutex{};
const t1 = Thread.spawn(.{}, || {
  const guard = mutex.lock();
  defer guard.unlock();
  data += 1;  // ✅ OK: protected by mutex
}, .{});
```

---

## Part 9: Complete Examples

### Example 1: Parallel Map-Reduce

```k
fn parallel_sum(numbers: []const i32) !i32 {
  const num_threads = 4;
  const chunk_size = numbers.len / num_threads;

  var results: [num_threads]i32 = undefined;
  var threads: [num_threads]Thread = undefined;

  // Spawn workers
  for (0..num_threads) |i| {
    const start = i * chunk_size;
    const end = if (i == num_threads - 1) numbers.len else (i + 1) * chunk_size;
    const chunk = numbers[start..end];

    threads[i] = try Thread.spawn(.{}, struct {
      fn worker(nums: []const i32, result: &i32) void {
        var sum: i32 = 0;
        for (nums) |n| {
          sum += n;
        }
        result.* = sum;
      }
    }.worker, .{chunk, &results[i]});
  }

  // Join and sum results
  var total: i32 = 0;
  for (threads) |thread| {
    thread.join();
  }
  for (results) |r| {
    total += r;
  }

  return total;
}
```

### Example 2: Producer-Consumer with Channel

```k
fn producer_consumer_example() !void {
  const Channel = std.sync.Channel;
  const channel = Channel(i32).init(allocator, 10);  // Buffered
  defer channel.deinit();

  // Spawn producers
  var producers: [3]Thread = undefined;
  for (&producers, 0..) |*t, i| {
    t.* = try Thread.spawn(.{}, struct {
      fn produce(ch: &Channel(i32), id: usize) void {
        for (0..10) |j| {
          ch.send(@intCast(id * 100 + j));
          std.time.sleep(100 * std.time.ns_per_ms);
        }
      }
    }.produce, .{&channel, i});
  }

  // Spawn consumers
  var consumers: [2]Thread = undefined;
  for (&consumers, 0..) |*t, i| {
    t.* = try Thread.spawn(.{}, struct {
      fn consume(ch: &Channel(i32), id: usize) void {
        while (ch.recv()) |value| {
          std.debug.print("Consumer {} got: {}\n", .{id, value});
        }
      }
    }.consume, .{&channel, i});
  }

  // Wait for producers
  for (producers) |t| t.join();
  channel.close();

  // Wait for consumers
  for (consumers) |t| t.join();
}
```

### Example 3: Async Web Server

```k
async fn handle_request(req: Request) !Response {
  // Parse user ID from path
  const user_id = try parse_user_id(req.path);

  // Fetch user (async I/O)
  const user = try await db.fetch_user(user_id);

  // Fetch posts in parallel
  const posts = try await db.fetch_posts(user.id);

  // Render response
  const html = try render_template("user.html", .{
    .user = user,
    .posts = posts,
  });

  return Response{
    .status = 200,
    .body = html,
  };
}

async fn run_server() !void {
  const listener = try net.listen("127.0.0.1", 8080);
  defer listener.close();

  std.debug.print("Server listening on :8080\n", .{});

  while (true) {
    const conn = try await listener.accept();

    // Spawn task to handle connection
    spawn async {
      defer conn.close();

      const req = try await read_request(conn);
      const resp = try await handle_request(req);
      try await write_response(conn, resp);
    };
  }
}
```

### Example 4: Lock-Free Queue

```k
const LockFreeQueue = struct(T: type) {
  head: Atomic(?&Node(T)),
  tail: Atomic(?&Node(T)),
  hp_domain: HazardPointerDomain,

  const Node = struct(T: type) {
    value: T,
    next: Atomic(?&Node(T)),
  };

  fn init(allocator: Allocator) !LockFreeQueue(T) {
    const dummy = try allocator.create(Node(T){
      .value = undefined,
      .next = Atomic(?&Node(T)).init(null),
    });

    return .{
      .head = Atomic(?&Node(T)).init(dummy),
      .tail = Atomic(?&Node(T)).init(dummy),
      .hp_domain = try HazardPointerDomain.init(allocator, 4),
    };
  }

  fn enqueue(self: &Self, value: T) !void {
    const new_node = try allocator.create(Node(T){
      .value = value,
      .next = Atomic(?&Node(T)).init(null),
    });

    const hp = self.hp_domain.acquire();
    defer hp.clear();

    while (true) {
      const tail = self.tail.load(.acquire);
      const protected_tail = hp.protect(tail.?);

      if (self.tail.load(.acquire) != tail) continue;

      const next = protected_tail.next.load(.acquire);
      if (next) |n| {
        // Tail is lagging, help update it
        _ = self.tail.compare_exchange_weak(tail, n, .release, .relaxed);
        continue;
      }

      // Try to link new node
      if (protected_tail.next.compare_exchange_weak(
        null,
        new_node,
        .release,
        .relaxed
      )) {
        // Success! Try to update tail
        _ = self.tail.compare_exchange_weak(tail, new_node, .release, .relaxed);
        return;
      }
    }
  }

  fn dequeue(self: &Self) ?T {
    const hp = self.hp_domain.acquire();
    defer hp.clear();

    while (true) {
      const head = self.head.load(.acquire);
      const protected_head = hp.protect(head.?);

      if (self.head.load(.acquire) != head) continue;

      const tail = self.tail.load(.acquire);
      const next = protected_head.next.load(.acquire);

      if (head == tail) {
        if (next == null) {
          return null;  // Queue is empty
        }
        // Tail is lagging, help update it
        _ = self.tail.compare_exchange_weak(tail, next, .release, .relaxed);
        continue;
      }

      if (next) |n| {
        const value = n.value;

        if (self.head.compare_exchange_weak(
          head,
          next,
          .release,
          .relaxed
        )) {
          hp.retire(protected_head);
          return value;
        }
      }
    }
  }
};
```

---

## Part 10: Design Decisions and Rationale

### Why Generators?

- ✅ **Simpler than full coroutines** for iteration
- ✅ **Zero-cost** when not used
- ✅ **Integrates with Iterator trait**
- ✅ **Common use case** (lazy sequences)

### Why Async/Await?

- ✅ **Better than callbacks** (no callback hell)
- ✅ **Better than threads** (lightweight)
- ✅ **Proven in Rust, JavaScript, C#, Python**
- ✅ **Composable** with structured concurrency

### Why Structured Concurrency?

- ✅ **No dangling tasks** (all tasks scoped)
- ✅ **Automatic cancellation** propagation
- ✅ **Clear ownership** of concurrent work
- ✅ **Proven in Swift, Kotlin**

### Why Sender/Receiver?

- ✅ **Separates algorithm from execution**
- ✅ **Highly composable**
- ✅ **Works with any scheduler** (threads, GPU, etc.)
- ✅ **C++26 standardizing** this model

### Why Hazard Pointers AND RCU?

- ✅ **Different use cases**:
  - Hazard Pointers: General lock-free structures
  - RCU: Read-mostly data structures
- ✅ **Both are proven** (Linux kernel uses RCU extensively)
- ✅ **Complementary** to each other

### Why Not Go-Style Goroutines?

- ❌ **Hidden concurrency** (hard to reason about)
- ❌ **No structured concurrency** (goroutines can leak)
- ❌ **Runtime overhead** (always need scheduler)
- ✅ **K's approach**: Explicit, structured, zero-cost

---

## Comparison with Other Languages

| Feature | Rust | Swift | C++26 | Zig | **K** |
|---------|------|-------|-------|-----|-------|
| **Threads** | ✅ std::thread | ✅ Thread | ✅ std::jthread | ✅ std.Thread | ✅ std.thread.Thread |
| **Async/Await** | ✅ async/await | ✅ async/await | ⚠️ Coroutines | ❌ (async frames) | ✅ async/await |
| **Structured Concurrency** | ❌ | ✅ TaskGroup | ❌ | ❌ | ✅ task_group |
| **Sender/Receiver** | ❌ | ❌ | ✅ P2300 | ❌ | ✅ sender/receiver |
| **Generators** | ❌ | ❌ | ✅ std::generator | ❌ | ✅ Generator(T) |
| **Channels** | ✅ mpsc | ❌ | ❌ | ❌ | ✅ Channel(T) |
| **Hazard Pointers** | ❌ (crossbeam) | ❌ | ✅ <hazard_pointer> | ❌ | ✅ HazardPointer |
| **RCU** | ❌ | ❌ | ✅ <rcu> | ❌ | ✅ Rcu(T) |
| **Latch** | ❌ | ❌ | ✅ std::latch | ❌ | ✅ Latch |
| **Barrier** | ✅ Barrier | ❌ | ✅ std::barrier | ❌ | ✅ Barrier |
| **Semaphore** | ❌ | ✅ DispatchSemaphore | ✅ std::semaphore | ❌ | ✅ Semaphore |
| **Borrow Checking** | ✅ | ❌ | ❌ | ❌ | ✅ |

**K's advantages**:
- ✅ Combines best of all worlds
- ✅ Structured concurrency (like Swift)
- ✅ Sender/Receiver (like C++26)
- ✅ Borrow checking (like Rust)
- ✅ Zero-cost (like Zig)

---

## Summary

K's concurrency model provides:

1. **Multiple paradigms**:
   - Threads for parallelism
   - Generators for lazy sequences
   - Async/await for I/O
   - Sender/receiver for composition

2. **Safety**:
   - Borrow checking prevents data races
   - Structured concurrency prevents task leaks
   - Type system enforces Send/Sync

3. **Performance**:
   - Zero-cost abstractions
   - Lock-free primitives (hazard pointers, RCU)
   - No hidden runtime overhead

4. **Composability**:
   - Mix threads, async, and lock-free
   - Sender/receiver for flexible execution
   - Works with K's error handling (!T)

**Next steps**:
- Implement basic Thread and Mutex
- Design async/await runtime
- Add generator support to compiler
- Implement hazard pointers and RCU
- Build standard library primitives

With this concurrency model, K becomes a **truly modern systems language** ready for everything from embedded systems to high-performance servers.
