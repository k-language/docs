# Standard Library Type Safety

## Reference Counting Types

### Rc<T> - Single-Threaded Reference Counting

```k
/// Single-threaded reference counted pointer.
/// NOT thread-safe - cannot be sent between threads.
const Rc = struct(comptime T: type) {
    ptr: *mut RcInner(T),

    const RcInner = struct {
        strong: usize,
        weak: usize,
        value: T,
    };

    pub fn init(allocator: Allocator, value: T) !Rc(T) {
        const inner = try allocator.create(RcInner(T));
        inner.* = RcInner(T){
            .strong = 1,
            .weak = 0,
            .value = value,
        };
        return Rc(T){ .ptr = inner };
    }

    pub fn clone(self: &Rc(T)) Rc(T) {
        self.ptr.strong += 1;
        return Rc(T){ .ptr = self.ptr };
    }

    pub fn drop(self: &mut Rc(T)) void {
        self.ptr.strong -= 1;
        if (self.ptr.strong == 0 and self.ptr.weak == 0) {
            allocator.destroy(self.ptr);
        }
    }
};

// Rc is NEVER Send or Sync (not thread-safe)
const !Send !Sync = Rc(T);  // For all T
```

**Safety Properties**:
- ❌ NOT `Send` - Cannot move between threads
- ❌ NOT `Sync` - Cannot share between threads
- ✅ Single-threaded only
- ✅ No overhead from atomics

### Arc<T> - Thread-Safe Reference Counting

```k
/// Atomic reference counted pointer.
/// Thread-safe - can be sent and shared between threads if T allows it.
const Arc = struct(comptime T: type) {
    ptr: *mut ArcInner(T),

    const ArcInner = struct {
        strong: AtomicUsize,
        weak: AtomicUsize,
        value: T,
    };

    pub fn init(allocator: Allocator, value: T) !Arc(T) {
        const inner = try allocator.create(ArcInner(T));
        inner.* = ArcInner(T){
            .strong = AtomicUsize.init(1),
            .weak = AtomicUsize.init(0),
            .value = value,
        };
        return Arc(T){ .ptr = inner };
    }

    pub fn clone(self: &Arc(T)) Arc(T) {
        _ = self.ptr.strong.fetchAdd(1, .SeqCst);
        return Arc(T){ .ptr = self.ptr };
    }

    pub fn drop(self: &mut Arc(T)) void {
        const prev = self.ptr.strong.fetchSub(1, .SeqCst);
        if (prev == 1) {
            // Last strong reference - check weak count
            if (self.ptr.weak.load(.SeqCst) == 0) {
                allocator.destroy(self.ptr);
            }
        }
    }
};

// Arc is Send + Sync ONLY if T is Send + Sync
impl Send for Arc(T) where T: Send + Sync {}
impl Sync for Arc(T) where T: Send + Sync {}
```

**Safety Properties**:
- ✅ `Send` if `T: Send + Sync` - Can move between threads
- ✅ `Sync` if `T: Send + Sync` - Can share between threads
- ✅ Atomic operations ensure thread safety
- ⚠️ Higher overhead than Rc due to atomics

**Why T: Send + Sync?**

```k
// Arc allows sharing &T across threads:
const arc = Arc.init(allocator, value);
const arc2 = arc.clone();  // Same pointer, different Arc

thread1: const ref = &arc.value;   // &T
thread2: const ref2 = &arc2.value; // &T (same value!)

// Therefore T must be Sync (safe to share &T)
// And T must be Send (value might be dropped in different thread)
```

## Interior Mutability Types

### Cell<T> - Single-Threaded Interior Mutability

```k
/// Provides interior mutability for Copy types.
/// NOT thread-safe.
const Cell = struct(comptime T: type) {
    value: T,

    pub fn init(value: T) Cell(T) {
        return Cell(T){ .value = value };
    }

    pub fn get(self: &Cell(T)) T where T: Copy {
        return self.value;
    }

    pub fn set(self: &Cell(T), value: T) void {
        // Interior mutability: mutate through &self
        const mut_self = @constCast(self);
        mut_self.value = value;
    }

    pub fn replace(self: &Cell(T), value: T) T {
        const old = self.get();
        self.set(value);
        return old;
    }
};

// Cell is Send if T is Send, but NEVER Sync
impl Send for Cell(T) where T: Send {}
const !Sync = Cell(T);  // Never Sync - interior mutability without synchronization
```

**Safety Properties**:
- ✅ `Send` if `T: Send` - Can move to another thread
- ❌ NOT `Sync` - Cannot share between threads (data race)
- ✅ Single-threaded only
- ✅ No runtime checks

**Why !Sync?**

```k
// If Cell were Sync, this would compile:
const cell = Cell.init(0);

thread1: cell.set(1);  // Write
thread2: cell.set(2);  // Write - DATA RACE!

// Therefore Cell must be !Sync
```

### RefCell<T> - Runtime Borrow Checking

```k
/// Provides interior mutability with runtime borrow checking.
/// NOT thread-safe.
const RefCell = struct(comptime T: type) {
    value: T,
    borrow_state: BorrowState,

    const BorrowState = enum {
        NotBorrowed,
        ImmutablyBorrowed,
        MutablyBorrowed,
    };

    pub fn init(value: T) RefCell(T) {
        return RefCell(T){
            .value = value,
            .borrow_state = .NotBorrowed,
        };
    }

    pub fn borrow(self: &RefCell(T)) Ref(T) {
        if (self.borrow_state == .MutablyBorrowed) {
            @panic("already mutably borrowed");
        }

        const mut_self = @constCast(self);
        mut_self.borrow_state = .ImmutablyBorrowed;

        return Ref(T){
            .value = &self.value,
            .cell = mut_self,
        };
    }

    pub fn borrow_mut(self: &RefCell(T)) RefMut(T) {
        if (self.borrow_state != .NotBorrowed) {
            @panic("already borrowed");
        }

        const mut_self = @constCast(self);
        mut_self.borrow_state = .MutablyBorrowed;

        return RefMut(T){
            .value = &mut mut_self.value,
            .cell = mut_self,
        };
    }
};

// RefCell is Send if T is Send, but NEVER Sync
impl Send for RefCell(T) where T: Send {}
const !Sync = RefCell(T);  // Never Sync - runtime checks are not thread-safe
```

**Safety Properties**:
- ✅ `Send` if `T: Send`
- ❌ NOT `Sync` - Runtime checks not thread-safe
- ✅ Runtime borrow checking
- ⚠️ Panics on violation

## Synchronization Types

### Mutex<T> - Mutual Exclusion

```k
/// Provides mutual exclusion for interior mutability.
/// Thread-safe.
const Mutex = struct(comptime T: type) {
    lock: AtomicBool,
    data: UnsafeCell(T),

    pub fn init(value: T) Mutex(T) {
        return Mutex(T){
            .lock = AtomicBool.init(false),
            .data = UnsafeCell.init(value),
        };
    }

    pub fn lock(self: &Mutex(T)) MutexGuard(T) {
        // Spin until we acquire the lock
        while (self.lock.compareAndSwap(false, true, .Acquire, .Acquire)) {
            std.Thread.yield();
        }

        return MutexGuard(T){
            .mutex = self,
            .data = &self.data.get(),
        };
    }
};

// Mutex is Send + Sync if T is Send (NOT Sync!)
impl Send for Mutex(T) where T: Send {}
impl Sync for Mutex(T) where T: Send {}  // Only need T: Send, not T: Sync!
```

**Safety Properties**:
- ✅ `Send` if `T: Send`
- ✅ `Sync` if `T: Send` (NOT `T: Sync`!)
- ✅ Provides exclusive access via lock
- ✅ Lock guard ensures unlock on drop

**Why only T: Send, not T: Sync?**

```k
// Mutex provides exclusive access (&mut T) while locked
const mutex = Mutex.init(value);

thread1: {
    const guard = mutex.lock();  // Exclusive access
    guard.* = new_value;         // &mut T
}

thread2: {
    const guard = mutex.lock();  // Waits for thread1
    const val = guard.*;         // &mut T
}

// Only one thread can access at a time
// T only needs to be Send (can move between threads)
// T does NOT need to be Sync (we never share &T)
```

### RwLock<T> - Read-Write Lock

```k
/// Reader-writer lock allowing multiple readers or one writer.
const RwLock = struct(comptime T: type) {
    readers: AtomicUsize,
    writer: AtomicBool,
    data: UnsafeCell(T),

    pub fn read(self: &RwLock(T)) ReadGuard(T) {
        // Wait for no writers
        while (self.writer.load(.Acquire)) {
            std.Thread.yield();
        }

        _ = self.readers.fetchAdd(1, .Acquire);
        return ReadGuard(T){
            .lock = self,
            .data = &self.data.get(),
        };
    }

    pub fn write(self: &RwLock(T)) WriteGuard(T) {
        // Wait for no readers or writers
        while (self.writer.compareAndSwap(false, true, .Acquire, .Acquire) or
               self.readers.load(.Acquire) > 0)
        {
            std.Thread.yield();
        }

        return WriteGuard(T){
            .lock = self,
            .data = &mut self.data.get(),
        };
    }
};

// RwLock is Send + Sync if T is Send + Sync
impl Send for RwLock(T) where T: Send + Sync {}
impl Sync for RwLock(T) where T: Send + Sync {}
```

**Safety Properties**:
- ✅ `Send` if `T: Send + Sync`
- ✅ `Sync` if `T: Send + Sync`
- ✅ Multiple readers OR one writer
- ✅ Guards ensure unlock on drop

**Why T: Send + Sync?**

```k
// RwLock allows sharing &T across threads (via read())
const rwlock = RwLock.init(value);

thread1: const guard = rwlock.read();  // &T
thread2: const guard2 = rwlock.read(); // &T (same value!)

// Multiple threads share &T, so T must be Sync
// And T must be Send (value might be dropped in different thread)
```

## Summary Table

| Type | Send? | Sync? | Use Case |
|------|-------|-------|----------|
| `Rc<T>` | ❌ | ❌ | Single-threaded reference counting |
| `Arc<T>` | ✅ (if `T: Send+Sync`) | ✅ (if `T: Send+Sync`) | Multi-threaded reference counting |
| `Cell<T>` | ✅ (if `T: Send`) | ❌ | Single-threaded interior mutability |
| `RefCell<T>` | ✅ (if `T: Send`) | ❌ | Single-threaded runtime borrow check |
| `Mutex<T>` | ✅ (if `T: Send`) | ✅ (if `T: Send`) | Multi-threaded mutual exclusion |
| `RwLock<T>` | ✅ (if `T: Send+Sync`) | ✅ (if `T: Send+Sync`) | Multi-threaded read-write lock |

## Common Patterns

### Pattern 1: Shared Ownership Across Threads

```k
fn shared_ownership() !void {
    const data = try Arc.init(allocator, expensive_data);

    var threads: [4]Thread = undefined;
    for (&threads) |*handle| {
        const data_clone = data.clone();
        handle.* = try Thread.spawn(.{}, worker, .{data_clone});
    }

    for (threads) |handle| {
        handle.join();
    }
}
```

### Pattern 2: Shared Mutable State

```k
fn shared_mutable() !void {
    const counter = try Arc.init(allocator, Mutex.init(0));

    var threads: [10]Thread = undefined;
    for (&threads) |*handle| {
        const counter_clone = counter.clone();
        handle.* = try Thread.spawn(.{}, increment, .{counter_clone});
    }

    for (threads) |handle| {
        handle.join();
    }

    const final = counter.lock();
    std.debug.print("Final: {}\n", .{final.*});
}

fn increment(counter: Arc(Mutex(i32))) void {
    for (0..100) |_| {
        var guard = counter.lock();
        guard.* += 1;
    }
}
```

### Pattern 3: Single-Threaded Cyclic References

```k
const Node = struct {
    value: i32,
    next: ?Rc(Node),
};

fn cyclic_reference() !void {
    var node1 = try Rc.init(allocator, Node{ .value = 1, .next = null });
    var node2 = try Rc.init(allocator, Node{ .value = 2, .next = node1.clone() });

    // Cannot create cycle with strong references (would leak)
    // Use Weak<T> for backpointers
}
```

## Testing Thread Safety

```k
test "cannot share Cell between threads" {
    const cell = Cell.init(0);

    // This should NOT compile:
    // const handle = try Thread.spawn(.{}, modify_cell, .{&cell});
    // Error: Cell<i32> is !Sync
}

test "can share Mutex between threads" {
    const mutex = Mutex.init(0);

    const handle = try Thread.spawn(.{}, increment_mutex, .{&mutex});
    increment_mutex(&mutex);
    handle.join();

    const guard = mutex.lock();
    try std.testing.expectEqual(2, guard.*);
}
```

## Heap-Allocated Types

### Box<T> - Unique Owned Heap Pointer

```k
/// Uniquely owned heap-allocated value.
/// Like Rust's Box<T> - provides ownership transfer and indirection.
const Box = struct(comptime T: type) {
    ptr: *mut T,
    allocator: Allocator,

    pub fn init(allocator: Allocator, value: T) !Box(T) {
        const ptr = try allocator.create(T);
        ptr.* = value;
        return Box(T){ .ptr = ptr, .allocator = allocator };
    }

    pub fn deinit(self: &Box(T)) T {
        const value = self.ptr.*;
        return value;
    }

    pub fn drop(self: &mut Box(T)) void {
        self.allocator.destroy(self.ptr);
    }

    // Deref to inner value
    pub fn deref(self: &Box(T)) &T {
        return self.ptr;
    }

    pub fn deref_mut(self: &mut Box(T)) &mut T {
        return self.ptr;
    }
};

// Box is Send+Sync if T is Send+Sync
impl Send for Box(T) where T: Send {}
impl Sync for Box(T) where T: Sync {}
```

**Use Cases**:
- Recursive types (linked lists, trees)
- Large types on heap (avoid stack overflow)
- Trait objects (dynamic dispatch)
- Ownership transfer

**Example**:
```k
const Node = struct {
    value: i32,
    left: ?Box(Node),
    right: ?Box(Node),
};

fn create_tree(allocator: Allocator) !Box(Node) {
    var root = try Box.init(allocator, Node{
        .value = 1,
        .left = null,
        .right = null,
    });

    root.deref_mut().left = try Box.init(allocator, Node{
        .value = 2,
        .left = null,
        .right = null,
    });

    return root;
}  // Box automatically freed via Drop
```

### Vec<T> - Growable Array

```k
/// Dynamically-sized, heap-allocated array.
const Vec = struct(comptime T: type) {
    ptr: [*]T,
    len: usize,
    capacity: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Vec(T) {
        return Vec(T){
            .ptr = undefined,
            .len = 0,
            .capacity = 0,
            .allocator = allocator,
        };
    }

    pub fn with_capacity(allocator: Allocator, capacity: usize) !Vec(T) {
        const ptr = try allocator.alloc(T, capacity);
        return Vec(T){
            .ptr = ptr.ptr,
            .len = 0,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    pub fn push(self: &mut Vec(T), item: T) !void {
        if (self.len == self.capacity) {
            try self.grow();
        }
        self.ptr[self.len] = item;
        self.len += 1;
    }

    pub fn pop(self: &mut Vec(T)) ?T {
        if (self.len == 0) return null;
        self.len -= 1;
        return self.ptr[self.len];
    }

    pub fn get(self: &Vec(T), index: usize) ?&T {
        if (index >= self.len) return null;
        return &self.ptr[index];
    }

    pub fn as_slice(self: &Vec(T)) []T {
        return self.ptr[0..self.len];
    }

    fn grow(self: &mut Vec(T)) !void {
        const new_capacity = if (self.capacity == 0) 8 else self.capacity * 2;
        const new_ptr = try self.allocator.realloc(
            self.ptr[0..self.capacity],
            new_capacity
        );
        self.ptr = new_ptr.ptr;
        self.capacity = new_capacity;
    }

    pub fn drop(self: &mut Vec(T)) void {
        if (self.capacity > 0) {
            self.allocator.free(self.ptr[0..self.capacity]);
        }
    }
};

// Vec is Send+Sync if T is Send+Sync
impl Send for Vec(T) where T: Send {}
impl Sync for Vec(T) where T: Sync {}
```

**Example**:
```k
fn vec_example(allocator: Allocator) !void {
    var numbers = Vec(i32).init(allocator);
    // Drop automatically frees

    try numbers.push(1);
    try numbers.push(2);
    try numbers.push(3);

    while (numbers.pop()) |value| {
        std.debug.print("{}\n", .{value});
    }
}
```

### String - Owned UTF-8 String

```k
/// Owned, growable UTF-8 string.
const String = struct {
    bytes: Vec(u8),

    pub fn init(allocator: Allocator) String {
        return String{ .bytes = Vec(u8).init(allocator) };
    }

    pub fn from(allocator: Allocator, s: []const u8) !String {
        var string = String.init(allocator);
        for (s) |byte| {
            try string.bytes.push(byte);
        }
        return string;
    }

    pub fn push_str(self: &mut String, s: []const u8) !void {
        for (s) |byte| {
            try self.bytes.push(byte);
        }
    }

    pub fn as_str(self: &String) []const u8 {
        return self.bytes.as_slice();
    }

    pub fn len(self: &String) usize {
        return self.bytes.len;
    }

    pub fn drop(self: &mut String) void {
        self.bytes.drop();
    }
};

// String is Send+Sync
impl Send for String {}
impl Sync for String {}
```

**Example**:
```k
fn string_example(allocator: Allocator) !void {
    var greeting = try String.from(allocator, "Hello, ");
    try greeting.push_str("World!");

    std.debug.print("{s}\n", .{greeting.as_str()});
}
```

## Iterator Trait

### Core Iterator Trait

```k
/// Core trait for iteration.
trait Iterator {
    /// The type of elements being iterated over.
    type Item;

    /// Advance iterator and return next item.
    fn next(self: &mut Self) ?Self.Item;

    /// Count remaining items (consumes iterator).
    fn count(self: &mut Self) usize {
        var n: usize = 0;
        while (self.next()) |_| {
            n += 1;
        }
        return n;
    }

    /// Collect into Vec.
    fn collect(self: &mut Self, allocator: Allocator) !Vec(Self.Item) {
        var result = Vec(Self.Item).init(allocator);
        while (self.next()) |item| {
            try result.push(item);
        }
        return result;
    }
}
```

### For-Loop Desugaring

```k
// For-loop syntax
for (items) |item| {
    process(item);
}

// Desugars to:
{
    var iter = items.iter();  // items.iter() returns impl Iterator
    while (iter.next()) |item| {
        process(item);
    }
}
```

### Vec Iterator Implementation

```k
const VecIterator = struct(comptime T: type) {
    slice: []T,
    index: usize,

    pub fn next(self: &mut VecIterator(T)) ?T {
        if (self.index >= self.slice.len) return null;
        const item = self.slice[self.index];
        self.index += 1;
        return item;
    }
};

impl Iterator for VecIterator(T) {
    type Item = T;

    fn next(self: &mut VecIterator(T)) ?T {
        return self.next();
    }
}

// Add to Vec(T):
impl Vec(T) {
    pub fn iter(self: &Vec(T)) VecIterator(T) {
        return VecIterator(T){
            .slice = self.as_slice(),
            .index = 0,
        };
    }
}
```

**Example**:
```k
fn iterator_example(allocator: Allocator) !void {
    var vec = Vec(i32).init(allocator);
    try vec.push(1);
    try vec.push(2);
    try vec.push(3);

    // For-loop (desugars to while + iter.next())
    for (vec.as_slice()) |item| {
        std.debug.print("{}\n", .{item});
    }

    // Manual iteration
    var iter = vec.iter();
    while (iter.next()) |item| {
        std.debug.print("{}\n", .{item});
    }
}
```

## Closure Traits

### Fn/FnMut/FnOnce Traits

```k
/// Immutable closure - can be called multiple times.
trait Fn(Args) -> Output {
    fn call(self: &Self, args: Args) Output;
}

/// Mutable closure - can modify captured state.
trait FnMut(Args) -> Output {
    fn call_mut(self: &mut Self, args: Args) Output;
}

/// One-time closure - consumes self.
trait FnOnce(Args) -> Output {
    fn call_once(self: Self, args: Args) Output;
}
```

### Closure Syntax

```k
// Closure literal
const add = |x: i32, y: i32| -> i32 { x + y };

// Type inference
const add = |x, y| x + y;  // Inferred: |i32, i32| -> i32

// Capturing environment
var acc: i32 = 0;
const increment = |x: i32| {
    acc += x;  // Captures &mut acc
};

// Desugars to anonymous struct:
const Closure = struct {
    acc: &mut i32,

    pub fn call_mut(self: &mut Closure, x: i32) void {
        self.acc.* += x;
    }
};

impl FnMut(i32) -> void for Closure {
    fn call_mut(self: &mut Closure, x: i32) void {
        self.call_mut(x);
    }
}
```

### Iter Methods with Closures

```k
trait Iterator {
    type Item;

    fn next(self: &mut Self) ?Self.Item;

    // Map
    fn map(self: &mut Self, comptime F: type, f: F) Map(Self, F)
        where F: Fn(Self.Item) -> U
    {
        return Map(Self, F){ .iter = self, .f = f };
    }

    // Filter
    fn filter(self: &mut Self, comptime F: type, f: F) Filter(Self, F)
        where F: Fn(&Self.Item) -> bool
    {
        return Filter(Self, F){ .iter = self, .f = f };
    }

    // For each
    fn for_each(self: &mut Self, comptime F: type, mut f: F) void
        where F: FnMut(Self.Item) -> void
    {
        while (self.next()) |item| {
            f.call_mut(item);
        }
    }
}
```

**Example**:
```k
fn functional_example(allocator: Allocator) !void {
    var numbers = Vec(i32).init(allocator);
    try numbers.push(1);
    try numbers.push(2);
    try numbers.push(3);

    var iter = numbers.iter();

    // Map
    var doubled = iter.map(|x| x * 2);
    while (doubled.next()) |x| {
        std.debug.print("{}\n", .{x});  // 2, 4, 6
    }

    // Filter + collect
    var iter2 = numbers.iter();
    var evens = iter2
        .filter(|x| x % 2 == 0)
        .collect(allocator);

    // For each with closure capturing
    var sum: i32 = 0;
    numbers.iter().for_each(|x| {
        sum += x;
    });
    std.debug.print("Sum: {}\n", .{sum});
}
```

## Summary

This document now covers:
- ✅ Reference counting (Rc, Arc)
- ✅ Interior mutability (Cell, RefCell)
- ✅ Synchronization (Mutex, RwLock)
- ✅ Heap allocation (Box)
- ✅ Collections (Vec, String)
- ✅ Iteration (Iterator trait, for-loop desugaring)
- ✅ Closures (Fn/FnMut/FnOnce traits, closure syntax)
- ✅ Thread safety bounds for all types

K Language's standard library provides Rust-level expressiveness while maintaining explicit allocator control.
