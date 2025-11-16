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
