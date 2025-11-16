# Borrow Checking in K Language

## Overview

K Language implements compile-time borrow checking to ensure memory safety without runtime overhead. This design combines Rust's ownership model with Zig's explicit control philosophy.

## Design Principles

1. **Compile-time verification** - All borrowing rules are checked at compile time
2. **Explicit memory control** - Programmers maintain full control over memory layout and lifetimes
3. **Zero runtime cost** - No garbage collection, no reference counting
4. **Optional escape hatches** - Unsafe blocks for low-level control when needed

## Core Concepts

### Ownership

Every value in K has a single owner at any point in time. When the owner goes out of scope, the value is dropped (unless marked with `nodrop`).

```k
fn example() void {
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer); // Explicit cleanup

    // buffer is owned by this function
    process(buffer);
} // buffer is freed here via defer
```

### Borrowing

K allows creating references to values without transferring ownership:

- **Immutable references** (`&T`) - Multiple immutable borrows allowed simultaneously
- **Mutable references** (`&mut T`) - Only one mutable borrow at a time

```k
fn borrow_example() void {
    var data: [100]u8 = undefined;

    // Multiple immutable borrows - OK
    const ref1 = &data;
    const ref2 = &data;
    read(ref1);
    read(ref2);

    // Single mutable borrow - OK
    const mut_ref = &mut data;
    write(mut_ref);

    // ERROR: Cannot have mutable and immutable borrows simultaneously
    // const ref3 = &data; // This would be a compile error
}
```

## Borrowing Rules

K enforces these rules at compile time:

### Rule 1: Single Writer OR Multiple Readers

At any given time, you can have EITHER:
- One mutable reference (`&mut T`), OR
- Any number of immutable references (`&T`)

**Never both simultaneously.**

```k
// ✓ Valid: Multiple readers
fn read_only(data: &[u8]) void {
    const ref1 = data;
    const ref2 = data;
    // Both can read simultaneously
}

// ✓ Valid: Single writer
fn write_only(data: &mut [u8]) void {
    data[0] = 42;
}

// ✗ Invalid: Mixed access
fn mixed_access(data: &mut [u8]) void {
    const reader = &data[0..];  // Immutable borrow
    data[0] = 42;                // ERROR: Cannot mutate while immutably borrowed
}
```

### Rule 2: References Must Not Outlive Referents

References cannot outlive the data they point to. The borrow checker ensures all references are valid for their entire lifetime.

```k
// ✗ Invalid: Dangling reference
fn dangling() &i32 {
    const x: i32 = 42;
    return &x;  // ERROR: x is dropped when function returns
}

// ✓ Valid: Reference is contained within owner's scope
fn contained(data: &[u8]) &u8 {
    return &data[0];  // OK: returned reference derives from parameter
}
```

### Rule 3: Freezing During Borrows

When an immutable borrow is active, the original value is "frozen" and cannot be modified.

```k
fn freeze_example() void {
    var counter: i32 = 0;

    const ref = &counter;  // Immutable borrow starts
    // counter += 1;        // ERROR: Cannot modify while borrowed
    print("{}", .{ref.*});
    // Borrow ends here

    counter += 1;  // OK: No active borrows
}
```

### Rule 4: Lifetime Annotations

When the compiler cannot infer lifetimes automatically, explicit lifetime annotations are required.

```k
// Explicit lifetime 'a
fn longest(a: &'a [u8], b: &'a [u8]) &'a [u8] {
    if (a.len > b.len) return a else return b;
}

// The returned reference has the same lifetime as the input parameters
```

## Integration with Zig's Allocator Pattern

K uses Zig's explicit allocator pattern, with borrow checking applied on top:

```k
const Allocator = @import("std").mem.Allocator;

fn process_data(allocator: Allocator) !void {
    const data = try allocator.alloc(u8, 1024);
    defer allocator.free(data);  // Explicit deallocation

    // Borrow checking ensures no dangling references
    const slice = borrow_slice(data);
    use_slice(slice);

    // slice is no longer used, safe to free via defer
}

fn borrow_slice(data: &[u8]) &[u8] {
    return data[0..100];  // Lifetime tied to input
}
```

## Drop Trait and RAII

K provides two mechanisms for cleanup:

### 1. Defer (Zig-style) - For Allocator Memory

Use `defer` for memory allocated from allocators:

```k
fn with_allocator(allocator: Allocator) !void {
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);  // Manual, explicit cleanup

    // Use buffer...
} // buffer freed here via defer
```

### 2. Drop Trait (Rust-style) - For Resource Types

Use `Drop` for types owning non-memory resources (files, sockets, locks):

```k
// Automatic cleanup via Drop
const File = struct {
    handle: FileHandle,

    pub fn open(path: []const u8) !File {
        return File{ .handle = try open_file(path) };
    }

    // Called automatically when File goes out of scope
    pub fn drop(self: &mut File) void {
        close_file(self.handle);
    }
};

fn use_file() !void {
    const file = try File.open("data.txt");
    // No defer needed - Drop handles cleanup
    write_to_file(file);
} // file.drop() called automatically here
```

### 3. Nodrop - Opt-out of Automatic Drop

Use `nodrop` when you need manual control:

```k
// Opt-out of automatic cleanup for manual control
const nodrop ManualFile = struct {
    handle: FileHandle,

    // Must explicitly call cleanup
    pub fn close(self: &mut ManualFile) void {
        close_file(self.handle);
    }
};

fn manual_control() !void {
    var file = ManualFile{ .handle = try open_file("data.txt") };
    defer file.close();  // Must use defer or call manually

    // Use file...
} // No automatic drop - must call close()
```

### Guidelines

- **Allocator memory**: Use `defer allocator.free()` (explicit)
- **System resources**: Use `Drop` trait (automatic)
- **Manual control needed**: Use `nodrop` + `defer`

```k
fn example_all_three(allocator: Allocator) !void {
    // 1. Allocator memory - use defer
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);

    // 2. Resource type - Drop handles it
    const file = try File.open("data.txt");
    // No defer needed

    // 3. Manual control - nodrop + defer
    var manual_file = ManualFile{ .handle = try open_file("log.txt") };
    defer manual_file.close();
}
```

### Critical Safety Rules

#### Rule 1: Deferred Resources Cannot Be Manually Freed

Once a resource is deferred, it cannot be manually freed to prevent double-free:

```k
fn safe_defer() !void {
    const data = try allocator.alloc(u8, 1024);
    defer allocator.free(data);

    // ERROR: Cannot manually free deferred resource
    // allocator.free(data);  // Compile error!

    use(data);
}  // Freed here via defer
```

**Rationale**: Prevents double-free bugs.

#### Rule 2: Drop + defer Execution Order

When both Drop and defer are present, execution order is:
1. **defer statements** (LIFO - last in, first out)
2. **Drop traits** (after all defers)

```k
fn execution_order() !void {
    defer std.debug.print("Defer 1\n", .{});

    var obj = DroppableType{ ... };
    defer std.debug.print("Defer 2\n", .{});

    // Execution:
    // 1. "Defer 2" (last defer first)
    // 2. "Defer 1" (first defer last)
    // 3. obj.drop() (Drop after all defers)
}
```

**Rationale**:
- defers execute in reverse order (stack semantics)
- Drop executes last to allow defers to access the object

#### Rule 3: nodrop Types Must Have Explicit Cleanup

Types marked `nodrop` will trigger a compiler warning if not explicitly cleaned up:

```k
#[warn(nodrop_no_cleanup)]
fn potential_leak() !void {
    var manual = nodrop Manual{ ... };
}  // Warning: nodrop type not cleaned up

// Fix: Add explicit cleanup
fn no_leak() !void {
    var manual = nodrop Manual{ ... };
    defer manual.deinit();  // OK
}
```

**Rationale**: Prevents accidental memory leaks from forgotten cleanup.

## Unsafe Escape Hatches

For low-level systems programming, K provides `unsafe` blocks that disable borrow checking:

```k
fn unsafe_example() void {
    var data: [100]u8 = undefined;

    unsafe {
        // Raw pointer manipulation
        const ptr: *u8 = &data[0];
        const another_ptr: *u8 = &data[0];

        // Both pointers can modify - programmer's responsibility
        ptr.* = 1;
        another_ptr.* = 2;
    }
}
```

**Use unsafe sparingly** - only when necessary for:
- FFI with C libraries
- Low-level kernel code
- Performance-critical lock-free algorithms
- Hardware register access

## Comparison with Rust and Zig

| Feature | Rust | Zig | K |
|---------|------|-----|---|
| Borrow checking | Yes | No | Yes |
| Explicit allocators | No (mostly hidden) | Yes | Yes |
| Automatic cleanup (RAII) | Yes (always) | No | Optional (Drop trait + nodrop) |
| Lifetime annotations | Required | N/A | Required when ambiguous |
| Unsafe blocks | Yes | Entire language is "unsafe" | Yes |
| Runtime cost | Zero | Zero | Zero |

## Design Rationale

K's borrow checking design aims to:

1. **Prevent common memory bugs** - Use-after-free, double-free, data races
2. **Maintain explicit control** - Programmers see all allocations and can opt-out of RAII
3. **Zero runtime overhead** - All checks happen at compile time
4. **Enable low-level programming** - Unsafe blocks for kernel/embedded development

## Examples

### Example 1: Safe Iterator

```k
const ArrayList = struct {
    items: []i32,
    allocator: Allocator,

    // Returns immutable iterator - allows multiple simultaneous iterations
    pub fn iter(self: &ArrayList) Iterator {
        return Iterator{ .items = self.items };
    }

    // Cannot add items while iterating (would require &mut self)
    pub fn append(self: &mut ArrayList, item: i32) !void {
        // Implementation
    }
};

fn use_list(list: &mut ArrayList) void {
    const it = list.iter();  // Immutable borrow
    // list.append(42);       // ERROR: Cannot mutate while borrowed

    while (it.next()) |item| {
        print("{}", .{item});
    }
    // Iterator dropped, borrow ends

    list.append(42);  // OK: No active borrows
}
```

### Example 2: Kernel Memory Management

```k
// Kernel allocator for page frames
const nodrop PageFrame = struct {
    physical_addr: usize,

    pub fn alloc() !PageFrame {
        const addr = try allocate_physical_page();
        return PageFrame{ .physical_addr = addr };
    }

    pub fn free(self: &PageFrame) void {
        free_physical_page(self.physical_addr);
    }
};

fn kernel_example() void {
    const frame = PageFrame.alloc() catch unreachable;

    // Use frame
    map_page(frame.physical_addr);

    // Must explicitly free (nodrop disables automatic cleanup)
    frame.free();
}
```

### Example 3: Lifetime Elision

K follows Rust's lifetime elision rules to reduce annotation burden:

```k
// No lifetime annotations needed - compiler infers 'a
fn first_element(slice: &[i32]) &i32 {
    return &slice[0];
}

// Explicit annotations required - ambiguous which input lifetime applies
fn choose_first(a: &'a [i32], b: &'b [i32], flag: bool) &'a [i32] {
    if (flag) return a else return b;  // ERROR without annotation
}
```

## Future Considerations

1. **Non-lexical lifetimes (NLL)** - More precise borrow checking based on actual usage
2. **Polonius** - Next-generation borrow checker with better precision
3. **View types** - Lightweight borrows for specific use cases
4. **Const generics** - Compile-time array sizes with borrowing

## References

- [Rust Ownership](https://doc.rust-lang.org/book/ch04-00-understanding-ownership.html)
- [Rust Borrowing Rules](https://doc.rust-lang.org/book/ch04-02-references-and-borrowing.html)
- [Rustonomicon - Ownership](https://doc.rust-lang.org/nomicon/ownership.html)
- [Zig Memory Management](https://ziglang.org/documentation/master/)
- [Zig Allocators](https://ziglang.org/learn/overview/)
