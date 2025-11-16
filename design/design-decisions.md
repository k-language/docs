# K Language Design Decisions

## Core Philosophy

K Language combines the best of Rust and Zig while maintaining systems programming clarity and control.

## Key Decisions

### 1. Optional Type Syntax: ?T (Zig-style)

**Decision**: Use `?T` instead of `Option<T>`

```k
// K Language (adopted)
const maybe: ?i32 = null;

if (maybe) |value| {  // Direct unwrapping
    use(value);
}

// Rejected: Rust's Option<T>
// const maybe: Option<i32> = None;
// if let Some(value) = maybe { ... }
```

**Rationale**:
- Simpler syntax for common case
- Integrates with Zig's error unions `!T`
- Less boilerplate
- Type is explicit in declaration

### 2. Memory Management: Three-Tier System

**Decision**: defer + Drop + nodrop

```k
// Tier 1: Allocator memory - use defer (explicit)
const buffer = try allocator.alloc(u8, 1024);
defer allocator.free(buffer);

// Tier 2: Resources - use Drop (automatic)
const file = try File.open("data.txt");
// Cleanup automatic via Drop trait

// Tier 3: Manual control - use nodrop
const nodrop manual = ManualType{ ... };
defer manual.deinit();
```

**Rationale**:
- Zig's defer: Explicit control for memory
- Rust's Drop: Convenience for resources
- nodrop: Escape hatch for low-level code
- Flexibility without sacrificing safety

### 3. Error Handling: ! operator (Zig-style)

**Decision**: Use `!T` error unions instead of `Result<T, E>`

```k
// K Language (adopted)
fn parse(str: []const u8) !i32 {
    if (invalid) return error.InvalidFormat;
    return 42;
}

// Can still use Result enum explicitly when needed
const Result = enum {
    Ok: T,
    Err: E,
};
```

**Rationale**:
- More concise for common case
- Better integration with allocators
- Explicit error sets when needed
- Result enum available for data structures

### 4. Pattern Matching: match over switch

**Decision**: Prefer `match` with exhaustiveness checking

```k
// Recommended
match (value) {
    .Ok => |v| process(v),
    .Err => |e| handle(e),
}

// Allowed but switch is just sugar for match
switch (value) {
    0 => "zero",
    else => "other",
}
```

**Rationale**:
- Exhaustiveness prevents bugs
- Destructuring support
- Guard clauses
- Consistent with modern languages

### 5. Generics: Dual System (comptime + traits)

**Decision**: Support both Zig's comptime and Rust's traits

```k
// Comptime for zero-cost monomorphization
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

// Traits for abstraction and dynamic dispatch
fn print_all(comptime T: type, items: []T) !void
    where T: Display
{
    for (items) |item| {
        try item.display();
    }
}
```

**Rationale**:
- Comptime: Zero-cost, Zig-style performance
- Traits: Rust-style ergonomics and reusability
- Best of both worlds
- Choose based on use case

### 6. Async: Library-based Runtime

**Decision**: async/await syntax, but runtime is user-provided

```k
async fn fetch(url: []const u8) ![]u8 {
    const response = await http_get(url);
    return response.body;
}

// Runtime chosen by user
pub fn main() !void {
    var runtime = choose_runtime();  // tokio-like, custom, or none
    runtime.block_on(async_main());
}
```

**Rationale**:
- Syntax is built-in for consistency
- Runtime is optional for embedded/kernel code
- No forced overhead
- Flexibility for different use cases

### 7. Concurrency: Send/Sync Traits (Rust-style)

**Decision**: Compile-time thread safety via marker traits

```k
trait Send {}  // Can move between threads
trait Sync {}  // Can share between threads

impl Send for MyType {}
impl Sync for MyType {}

// Opt-out
const !Send !Sync LocalData = struct { ... };
```

**Rationale**:
- Prevents data races at compile time
- No runtime overhead
- Explicit opt-in/opt-out
- Proven by Rust's success

### 8. Lifetimes: Explicit When Needed

**Decision**: Rust-style lifetime annotations with inference

```k
// Inferred (most common)
fn first(slice: &[i32]) &i32 {
    return &slice[0];
}

// Explicit when ambiguous
fn longest<'a>(x: &'a str, y: &'a str) &'a str {
    if (x.len > y.len) return x else return y;
}
```

**Rationale**:
- Safety without annotation burden
- Explicit when compiler can't infer
- Familiar to Rust programmers
- Clear ownership semantics

### 9. Unsafe: Explicit Blocks (Rust-style)

**Decision**: Safe by default, unsafe is opt-in

```k
// Safe code (default)
fn safe_operation(data: &[u8]) void {
    // Borrow checker enforces safety
}

// Unsafe code (explicit)
fn raw_operation(ptr: *u8) void {
    unsafe {
        ptr.* = 42;  // Programmer's responsibility
    }
}
```

**Rationale**:
- Clear safety boundaries
- Audit surface is minimized
- Required for FFI and low-level code
- Principle of least privilege

### 10. Generic Struct Syntax: Function-Returning-Type (Zig-style)

**Decision**: Use Zig's function syntax for generic types

```k
// K Language (adopted) - Zig-style
fn ArrayList(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{ .items = &[_]T{}, .len = 0, .allocator = allocator };
        }
    };
}

// Usage
var list = ArrayList(i32).init(allocator);
```

**Alternative Syntax** (available as syntactic sugar):
```k
// Shorthand notation - equivalent to above
const ArrayList = struct(comptime T: type) {
    items: []T,
    // ... same body
};
```

**Rationale**:
- **Primary style**: Zig's `fn Type(comptime T: type) type` is the canonical form
  - More explicit and clear that it's compile-time
  - Matches Zig's philosophy of explicitness
  - Works with all comptime logic
- **Sugar allowed**: `struct(T)` syntax may be used for brevity
  - Compiles to the same code
  - Reader preference
  - Both styles in documentation are acceptable
- **Consistency**: When both appear in docs, they demonstrate equivalence
- **Flexibility**: Choose based on context (tutorial vs. reference)

### 11. Self Reference in Generic Types: @This() Pattern

**Decision**: Use `@This()` to refer to the current type, assign to `Self` for convenience

```k
fn ArrayList(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,

        const Self = @This();  // Define Self once

        pub fn init() Self {   // Use Self in signatures
            return Self{ .items = &[_]T{}, .len = 0 };
        }

        pub fn append(self: &mut Self, item: T) !void {
            // ...
        }
    };
}
```

**Alternative** (explicit type name):
```k
// Also valid - use explicit type name
pub fn clone(self: &Rc(T)) Rc(T) {
    return Rc(T){ .ptr = self.ptr };
}
```

**Guidelines**:
1. **Within generic functions/structs**: Use `Self = @This()` pattern
   - More maintainable if type name changes
   - Shorter and clearer
   - Standard Zig practice

2. **Simple cases**: Direct type name is fine
   - When type is short and non-generic
   - For clarity in documentation
   - When `Self` would be ambiguous

3. **Consistency**: Pick one style per file/module
   - Don't mix both in the same struct
   - Follow existing code style in the file

**Rationale**:
- `@This()` is Zig's standard way to get current type
- `Self` alias reduces repetition in generics
- Explicit type names can be clearer in simple cases
- Both are valid - consistency matters most

### 12. Module System: File-based with Visibility

**Decision**: Zig's file-based modules + Rust's pub(crate)

```k
// Import
const std = @import("std");
const utils = @import("utils.k");

// Visibility
pub fn public_api() void {}
pub(crate) fn internal_api() void {}
pub(super) fn parent_only() void {}
fn private() void {}  // Default
```

**Rationale**:
- Zig's simplicity (file = module)
- Rust's granular visibility
- No module declaration boilerplate
- Clear public API surface

## Design Trade-offs

### Complexity vs Power

| Decision | Adds Complexity | Adds Power | Verdict |
|----------|----------------|------------|---------|
| Borrow checking | High | High | ✅ Worth it |
| Comptime | Medium | High | ✅ Worth it |
| Traits | Medium | High | ✅ Worth it |
| HKT | High | Medium | ✅ Worth it (advanced users) |
| Lifetimes | Medium | High | ✅ Worth it |
| Async runtime | Low | High | ✅ Worth it (optional) |

### Consistency Principles

1. **Explicit over implicit**: All control flow visible (optional)
2. **Safety by default**: Unsafe is opt-in
3. **Zero-cost abstractions**: No runtime overhead
4. **Escape hatches**: Always provide unsafe/manual control
5. **Familiar syntax**: Learn from Rust/Zig/C

## Future Considerations

### Under Consideration

1. **Const generics expansion**: More powerful compile-time computation
2. **Polonius**: Next-gen borrow checker
3. **Async traits**: Traits with async methods
4. **Specialization**: Optimize generic code for specific types
5. **GATs**: Generic associated types

### Explicitly Rejected

1. **Garbage collection**: Goes against systems programming philosophy
2. **Exceptions**: Error handling should be explicit
3. **Null pointers**: Use `?T` instead
4. **Implicit type coercion**: Explicit casts required
5. **Mandatory runtime**: Keep it optional

## Comparison Summary

| Feature | Rust | Zig | K | Rationale |
|---------|------|-----|---|-----------|
| Borrow checking | ✅ | ❌ | ✅ | Memory safety |
| Explicit allocators | ❌ | ✅ | ✅ | Control |
| Drop/RAII | ✅ Always | ❌ | ✅ Optional | Flexibility |
| Comptime | ❌ | ✅ | ✅ | Zero-cost |
| Traits | ✅ | ❌ | ✅ | Abstraction |
| Async/await | ✅ | ❌ | ✅ | Ergonomics |
| Optional runtime | ❌ | N/A | ✅ | Embedded support |
| HKT | ❌ | ❌ | ✅ | Advanced patterns |

## Conclusion

K Language is designed for:

1. **Systems programmers** who want Rust's safety with Zig's control
2. **Kernel developers** who need borrow checking without forced runtimes
3. **Performance engineers** who want zero-cost abstractions
4. **Library authors** who need powerful generics and traits

The design prioritizes:
- **Safety** without sacrificing control
- **Performance** without hidden costs
- **Ergonomics** without magic
- **Flexibility** without confusion
