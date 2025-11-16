# Conditional Defer: Generalizing errdefer

## Motivation

Currently K has two defer mechanisms:
- `defer` - always executes
- `errdefer` - executes only on error return

**Problem**: `errdefer` is hardcoded for `Result` type's `.Err` variant. This is inconsistent with K's philosophy that all types are equal (no special compiler magic).

## Proposed Design: Pattern-Based Defer

### Syntax

```k
defer cleanup();                    // Always (unchanged)
defer on .Variant cleanup();        // When function returns .Variant
defer on .Err cleanup();            // Equivalent to current errdefer
defer on .Ok cleanup();             // When function returns .Ok
defer on .Some cleanup();           // When function returns .Some
defer on .None cleanup();           // When function returns .None
```

### Sugar

```k
errdefer cleanup();     // Sugar for: defer on .Err cleanup();
```

Keep `errdefer` as sugar since it's common, but it desugars to the general form.

## Examples

### Example 1: Result Type

```k
fn process_file(path: []const u8) !Data {
    const file = try open(path);
    defer close(file);                      // Always close

    const buffer = try allocate();
    defer on .Err free(buffer);             // Free only on error
    defer on .Ok log_success(buffer);       // Log only on success

    const data = try parse(buffer);
    return data;  // .Ok variant - log_success runs, free doesn't
}

// Same as above using sugar:
fn process_file_sugar(path: []const u8) !Data {
    const file = try open(path);
    defer close(file);

    const buffer = try allocate();
    errdefer free(buffer);                  // Sugar for: defer on .Err
    defer on .Ok log_success(buffer);

    const data = try parse(buffer);
    return data;
}
```

### Example 2: Option Type

```k
fn find_user(id: i32) ?User {
    const cache = open_cache();
    defer close_cache(cache);

    defer on .Some increment_hits();        // Track cache hit
    defer on .None increment_misses();      // Track cache miss

    return cache.lookup(id);
}
```

### Example 3: Custom Enum

```k
const Status = enum {
    Success,
    PartialSuccess,
    Failure,
};

fn backup_files(files: []File) Status {
    const log = create_log();
    defer flush_log(log);

    defer on .Success log_info("All files backed up");
    defer on .PartialSuccess log_warn("Some files failed");
    defer on .Failure log_error("Backup failed");

    var success_count: usize = 0;
    for (files) |file| {
        if (backup_file(file)) success_count += 1;
    }

    if (success_count == files.len) return .Success;
    if (success_count > 0) return .PartialSuccess;
    return .Failure;
}
```

### Example 4: Multiple Variants

```k
fn transaction() !void {
    const tx = begin_transaction();
    defer on .Err rollback(tx);             // Rollback on any error
    defer on .Ok commit(tx);                // Commit on success

    try step1();
    try step2();
    try step3();
}
```

## Type Safety Analysis

### Type Inference

The compiler infers the enum type from the function's return type:

```k
fn foo() Result<i32, Error> {
    defer on .Ok cleanup();     // OK: Result has .Ok variant
    defer on .Err cleanup();    // OK: Result has .Err variant
    defer on .Some cleanup();   // ERROR: Result has no .Some variant
}

fn bar() Option<i32> {
    defer on .Some cleanup();   // OK: Option has .Some variant
    defer on .None cleanup();   // OK: Option has .None variant
    defer on .Ok cleanup();     // ERROR: Option has no .Ok variant
}
```

**Compile-time guarantee**: Variant must exist in return type's enum.

### Early Returns

All return paths must be consistent:

```k
fn example() Result<i32, Error> {
    defer on .Err cleanup();

    if (condition) {
        return .Err(error.Bad);     // cleanup runs
    }

    return .Ok(42);                 // cleanup doesn't run
}

// ERROR: Inconsistent return type
fn broken() i32 {
    defer on .Err cleanup();        // ERROR: i32 is not an enum
    return 42;
}
```

## Multiple Defers Execution Order

When multiple conditional defers match the same variant:

```k
fn example() !void {
    defer on .Err cleanup1();       // 3rd
    defer on .Err cleanup2();       // 2nd
    defer cleanup3();               // 1st
    defer on .Err cleanup4();       // 4th (ERROR - see below)

    return error.Failed;
}
```

**Execution order** (LIFO - last in, first out):
1. `cleanup3()` - unconditional defer (last)
2. `cleanup2()` - conditional defer on .Err (2nd to last)
3. `cleanup1()` - conditional defer on .Err (3rd to last)

**Rule**: Conditional defers execute in reverse order, after unconditional defers.

Wait, this is wrong. Let me reconsider...

Actually, better rule: **All defers execute in strict LIFO order**, but conditional ones are skipped if variant doesn't match:

```k
fn example() !void {
    defer cleanup1();               // 4th (always)
    defer on .Err cleanup2();       // 3rd (if .Err)
    defer cleanup3();               // 2nd (always)
    defer on .Ok cleanup4();        // 1st (if .Ok)

    return error.Failed;  // Returns .Err
}

// Execution on .Err return:
// 1. cleanup4() - SKIPPED (variant is .Err, not .Ok)
// 2. cleanup3() - RUNS (unconditional)
// 3. cleanup2() - RUNS (variant matches .Err)
// 4. cleanup1() - RUNS (unconditional)
```

## Integration with Drop Trait

Execution order when both Drop and conditional defer present:

```k
fn example() !void {
    var obj = DroppableType{ ... };     // Has Drop trait

    defer cleanup1();
    defer on .Err cleanup2();

    return error.Failed;
}

// Execution order:
// 1. cleanup2() - conditional defer (last defer, matches .Err)
// 2. cleanup1() - unconditional defer
// 3. obj.drop() - Drop trait (after all defers)
```

**Rule**: Drop executes after all defers (conditional and unconditional).

## Performance Analysis

### Compile-Time Optimization

The compiler can eliminate conditional defers at compile time in many cases:

```k
fn always_ok() Result<i32, Error> {
    defer on .Err cleanup();        // Compiler can prove this never runs
    return .Ok(42);                 // Statically known return
}

// Compiler generates:
fn always_ok() Result<i32, Error> {
    // defer on .Err omitted - unreachable
    return .Ok(42);
}
```

### Runtime Cost

When compile-time elimination isn't possible:

```k
fn dynamic(flag: bool) !void {
    defer on .Err cleanup();

    if (flag) return .Err(error.Bad);
    return .Ok;
}
```

**Implementation**: Store variant tag at return, check before executing defers.

**Cost**: One tag comparison per conditional defer (negligible).

## Potential Issues and Solutions

### Issue 1: Variant Inference with Complex Returns

**Problem**:
```k
fn complex() !void {
    defer on .Err cleanup();

    if (condition) {
        try operation1();   // Implicit return on error
    }

    return;  // Implicit .Ok
}
```

**Solution**: `try` implicitly returns `.Err`, inference works correctly.

### Issue 2: Multiple Variant Matching

**Question**: Can we match multiple variants?

```k
defer on .Err1 | .Err2 cleanup();   // Multiple variants?
```

**Decision**: Not in initial version. Use separate defers:

```k
defer on .Err1 cleanup();
defer on .Err2 cleanup();
```

If needed later, can add OR syntax.

### Issue 3: Nested Enums

**Problem**:
```k
const Nested = enum {
    Ok: Result<i32, Error>,
    Cancelled,
};

fn foo() Nested {
    defer on .Ok cleanup();         // Matches Nested.Ok or inner Result.Ok?
}
```

**Solution**: Match only top-level enum. To match nested:

```k
fn foo() Nested {
    defer on .Ok cleanup();         // Matches Nested.Ok

    const result = inner_call();
    match (result) {
        .Ok => |r| {
            match (r) {
                .Ok => inner_ok_cleanup(),
                .Err => inner_err_cleanup(),
            }
        },
        .Cancelled => cancelled_cleanup(),
    }
}
```

### Issue 4: Generic Functions

**Problem**: How do conditional defers work with generic return types?

```k
fn generic(comptime T: type) T {
    defer on .Err cleanup();        // OK if T is Result/enum with .Err
                                    // ERROR if T is i32
}
```

**Solution**: Compile-time check based on instantiated type:

```k
fn generic(comptime T: type) T {
    // Only compile if T has .Err variant
    defer on .Err cleanup();

    // Error at instantiation:
    generic(i32);           // ERROR: i32 has no .Err variant
    generic(Result);        // OK: Result has .Err variant
}
```

Can add compile-time check:
```k
fn generic(comptime T: type) T {
    comptime {
        if (!@hasVariant(T, "Err")) {
            @compileError("T must have .Err variant");
        }
    }
    defer on .Err cleanup();
}
```

## Comparison with Other Languages

### Rust

Rust doesn't have conditional defer. Closest equivalent:

```rust
// Rust - manual guard pattern
struct Guard {
    buffer: Buffer,
}

impl Drop for Guard {
    fn drop(&mut self) {
        if std::thread::panicking() {
            // Error case cleanup
            free_buffer(&self.buffer);
        }
    }
}
```

K's conditional defer is cleaner:
```k
defer on .Err free_buffer(buffer);
```

### Zig

Zig has `errdefer` but it's hardcoded for errors:

```zig
errdefer cleanup();  // Only for error returns
```

K generalizes this to all enums.

### Go

Go has `defer` but no conditional variant:

```go
defer cleanup()  // Always runs
```

K adds pattern-based conditions.

## Design Rationale

### Why Generalize errdefer?

1. **Consistency**: No special compiler magic for Result type
2. **Sugar system**: errdefer desugars to general form
3. **Flexibility**: Works with any enum (Result, Option, custom enums)
4. **Type safety**: Compile-time verification of variants
5. **Zero cost**: Optimizes away when possible

### Why `defer on .Variant` Syntax?

Alternatives considered:

```k
// Option 1: defer on .Variant (chosen)
defer on .Err cleanup();

// Option 2: defer when variant
defer when .Err cleanup();

// Option 3: defer if match
defer if .Err cleanup();

// Option 4: defer(.Err)
defer(.Err) cleanup();
```

**Chosen**: `defer on .Variant` - reads naturally, distinguishes from pattern matching.

## Migration Path

### Backward Compatibility

Keep `errdefer` as sugar:

```k
// Old code still works
errdefer cleanup();

// New code can use general form
defer on .Err cleanup();
```

### Deprecation Strategy

**Phase 1** (Current): Both `errdefer` and `defer on .Err` supported
**Phase 2** (Future): Mark `errdefer` as "prefer `defer on .Err`" in linter
**Phase 3** (Optional): Keep `errdefer` indefinitely as convenient sugar

## Conclusion

**Proposal**: Generalize `errdefer` to `defer on .Variant` for any enum type.

**Benefits**:
- ✅ Consistent with sugar philosophy (no compiler magic)
- ✅ Works with Result, Option, and custom enums
- ✅ Type-safe (compile-time verification)
- ✅ Zero-cost abstraction (optimizes away when possible)
- ✅ Backward compatible (errdefer as sugar)

**Risks**:
- ⚠️ Slightly more complex than current design
- ⚠️ Need clear rules for execution order
- ⚠️ Generic functions need compile-time checks

**Recommendation**: **Adopt this generalization**. The benefits outweigh the complexity, and it makes the defer system consistent with the overall type system design.
