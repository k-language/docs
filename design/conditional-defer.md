# Defer System: Complete Design

## Motivation

K needs a comprehensive defer system that covers all cleanup scenarios:
1. **Function-level cleanup** - always or conditionally on return
2. **Block-level cleanup** - when exiting labelled blocks
3. **Pattern-based cleanup** - based on enum variants

**Problem**: Current `errdefer` is hardcoded for `Result` type's `.Err` variant. This is inconsistent with K's philosophy that all types are equal (no special compiler magic).

## Complete Defer Syntax

### 1. Function-Scoped Defer

```k
defer cleanup();                    // Always on function exit
defer on .Variant cleanup();        // When function returns .Variant
```

### 2. Block-Scoped Defer (Labelled)

```k
block: {
    defer :block cleanup();         // When exiting :block
    defer :block on .Err cleanup(); // When breaking :block with error
}
```

### 3. Sugar Forms

```k
errdefer cleanup();                 // Sugar for: defer on .Err cleanup();
```

## Scope Hierarchy

Defer executes at different scopes:

```k
fn example() !void {
    // Function-level defer
    defer function_cleanup();               // Runs on function exit

    block: {
        // Block-level defer
        defer :block block_cleanup();       // Runs on block exit

        if (condition) {
            break :block;                   // block_cleanup runs here
        }
    }  // or block_cleanup runs here

    // function_cleanup runs when function returns
}
```

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

### Example 5: Labelled Block Defer (Lock Management)

```k
fn critical_section() !void {
    const lock = acquire_lock();
    defer release_lock(lock);

    // Nested critical section with different lock
    inner: {
        const inner_lock = acquire_inner_lock();
        defer :inner release_inner_lock(inner_lock);  // Releases when exiting :inner

        if (should_skip) {
            break :inner;  // inner_lock released here, outer lock still held
        }

        perform_inner_operation();
    }  // inner_lock released here if not broken

    perform_outer_operation();
}  // outer lock released here
```

### Example 6: Labelled Defer with Conditionals

```k
fn parse_with_retry(data: []const u8) !ParseResult {
    var attempts: usize = 0;

    retry: {
        defer :retry increment_attempts(&attempts);
        defer :retry on .Err log_retry_failure(attempts);

        const result = try parse(data);

        if (result.needs_retry and attempts < MAX_RETRIES) {
            break :retry;  // Both defers execute, then loop continues
            // Actually this needs to be a loop, let me fix...
        }

        return result;
    }
}
```

Better version with loop:

```k
fn parse_with_retry(data: []const u8) !ParseResult {
    var attempts: usize = 0;

    while (attempts < MAX_RETRIES) : (attempts += 1) {
        retry: {
            defer :retry on .Err log_attempt(attempts);

            const result = parse(data) catch |err| {
                if (attempts + 1 < MAX_RETRIES) {
                    break :retry;  // Try again
                }
                return err;
            };

            return result;  // Success
        }
    }

    return error.TooManyRetries;
}
```

### Example 7: Resource Pools with Labelled Defer

```k
fn process_with_pooled_resources() !void {
    const pool = get_resource_pool();

    acquire: {
        const resource = try pool.acquire();
        defer :acquire pool.release(resource);  // Always released when leaving :acquire

        if (!resource.is_valid()) {
            break :acquire;  // Release and try again
        }

        try use_resource(resource);
    }  // resource released here
}
```

### Example 8: Nested Transactions with Multiple Labels

```k
fn nested_transactions() !void {
    const outer_tx = begin_transaction();
    defer on .Err rollback_outer(outer_tx);
    defer on .Ok commit_outer(outer_tx);

    try outer_operation();

    savepoint: {
        const inner_tx = create_savepoint(outer_tx);
        defer :savepoint on .Err rollback_savepoint(inner_tx);
        defer :savepoint on .Ok release_savepoint(inner_tx);

        const result = inner_operation() catch |err| {
            // Savepoint defers execute here (rollback_savepoint)
            break :savepoint;  // Continue with outer transaction
        };

        process(result);
    }  // Savepoint defers execute here if no error (release_savepoint)

    try final_operation();
}  // Outer transaction defers execute here (commit_outer or rollback_outer)
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

## Labelled Defer: Block-Scoped Cleanup

### Motivation

Sometimes cleanup needs to happen at block scope, not function scope:

```k
// Problem: Need to release lock when leaving block, not function
fn example() void {
    outer_work();

    {
        const lock = acquire();
        // Want: release lock when leaving THIS block
        // Problem: defer releases at function end
        defer release(lock);  // TOO LATE!

        inner_work();
    }  // Want to release here

    more_outer_work();  // Still have lock - BUG!
}
```

### Solution: Labelled Blocks

```k
fn example() void {
    outer_work();

    block: {
        const lock = acquire();
        defer :block release(lock);  // Releases when leaving :block

        inner_work();
    }  // lock released HERE

    more_outer_work();  // No lock - correct!
}
```

### Syntax

```k
label: {
    defer :label cleanup();              // Unconditional block defer
    defer :label on .Variant cleanup();  // Conditional block defer
}
```

### Integration with Labelled Break

Labelled defer works seamlessly with Zig-style labelled break:

```k
retry: {
    const resource = acquire();
    defer :retry release(resource);

    if (should_retry) {
        break :retry;  // resource released HERE, then continues after block
    }

    use(resource);
}  // or resource released HERE if no break
```

### Execution Order with Nested Labels

```k
fn nested() void {
    defer cleanup1();           // 6th: Function-level

    outer: {
        defer :outer cleanup2();    // 5th: Outer block

        inner: {
            defer :inner cleanup3();    // 4th: Inner block
            defer cleanup4();           // 3rd: Function-level (from inside inner)

            break :inner;
        }  // cleanup3, cleanup4 execute (LIFO: 4, 3)

        defer :outer cleanup5();    // 2nd: Outer block
        break :outer;
    }  // cleanup5, cleanup2 execute (LIFO: 5, 2)

    defer cleanup6();           // 1st: Function-level
}  // cleanup6, cleanup1 execute (LIFO: 6, 1)

// Full execution order: 3→4→5→2→6→1
```

**Rule**: Defers execute in LIFO order within their scope, starting from innermost scope.

### Labelled Defer with Conditionals

Combine labels with variant patterns:

```k
fn transaction() !void {
    tx: {
        const t = begin_transaction();
        defer :tx on .Ok commit(t);
        defer :tx on .Err rollback(t);

        const result = operation() catch |err| {
            break :tx;  // rollback executes, commit skipped
        };

        process(result);
    }  // commit executes if no error
}
```

### Labelled Loops

Labels work with all loop constructs:

```k
fn process_items(items: []Item) !void {
    outer: for (items) |item| {
        const resource = acquire_for(item);
        defer :outer release(resource);  // Releases each iteration

        inner: for (item.children) |child| {
            defer :inner process_child_cleanup(child);

            if (should_skip_child(child)) {
                break :inner;  // Child cleanup, continue outer
            }

            try process_child(child);
        }  // Child cleanup if not broken

        try finalize_item(item);
    }  // Resource released after each outer iteration
}
```

### Use Cases

#### 1. Lock Management
```k
critical: {
    const lock = acquire_lock();
    defer :critical release_lock(lock);

    if (!can_proceed()) break :critical;  // Early exit with cleanup
    perform_critical_section();
}
```

#### 2. Temporary Resource Acquisition
```k
temp: {
    const scratch = allocate_scratch_buffer();
    defer :temp free_scratch(scratch);

    if (can_use_cache()) break :temp;  // Skip scratch work
    use_scratch_buffer(scratch);
}
```

#### 3. Transaction Savepoints
```k
savepoint: {
    const sp = create_savepoint();
    defer :savepoint on .Err rollback_to(sp);
    defer :savepoint on .Ok release(sp);

    try risky_operation();
}
```

#### 4. Scoped Performance Tracking
```k
measure: {
    const timer = start_timer("operation");
    defer :measure record_time(timer);

    if (cache_hit()) break :measure;  // Record fast path
    perform_slow_operation();         // Record slow path
}
```

### Comparison: Function vs Block Defer

| Feature | Function Defer | Block Defer |
|---------|---------------|-------------|
| Scope | Entire function | Labelled block |
| Syntax | `defer f()` | `defer :label f()` |
| Execution | Function return | Block exit or break |
| Nesting | No direct nesting | Nested blocks supported |
| With loops | Once per function | Once per iteration |
| Conditionals | `defer on .Variant` | `defer :label on .Variant` |

### Type Safety

Block defers have same type safety as function defers:

```k
block: {
    defer :block on .Err cleanup();  // ERROR if block doesn't return Result

    const result = operation();
    if (result.is_err()) break :block;  // OK if returns Result
}
```

For simple blocks (no return type), only unconditional defers allowed:

```k
block: {
    defer :block cleanup();              // OK: unconditional
    defer :block on .Err cleanup();      // ERROR: block has no return type
}
```

### Implementation Notes

**Block value return**: Blocks can return values in Zig. If K adopts this, defers can match:

```k
const result: !i32 = block: {
    defer :block on .Err log_error();
    defer :block on .Ok log_success();

    const x = try compute();
    break :block x;  // Returns .Ok(x), log_success runs
};
```

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

**Proposal**: Complete defer system with three orthogonal features:

1. **Pattern-based defer**: `defer on .Variant` for any enum type
2. **Labelled defer**: `defer :label` for block-scoped cleanup
3. **Sugar forms**: `errdefer` = `defer on .Err`

### Complete Defer Matrix

| Scope | Unconditional | Conditional |
|-------|---------------|-------------|
| **Function** | `defer cleanup()` | `defer on .Variant cleanup()` |
| **Block** | `defer :label cleanup()` | `defer :label on .Variant cleanup()` |

### Benefits

**Pattern-Based Defer**:
- ✅ Consistent with sugar philosophy (no compiler magic)
- ✅ Works with Result, Option, and custom enums
- ✅ Type-safe (compile-time verification)
- ✅ Zero-cost abstraction (optimizes away when possible)
- ✅ Backward compatible (errdefer as sugar)

**Labelled Defer**:
- ✅ Block-scoped cleanup (locks, resources, transactions)
- ✅ Works with labelled break (Zig-style)
- ✅ Nested blocks fully supported
- ✅ Per-iteration cleanup in loops
- ✅ Clear scope boundaries

**Combined System**:
- ✅ Orthogonal features compose naturally
- ✅ Covers all cleanup scenarios (function, block, conditional)
- ✅ Uniform syntax and semantics
- ✅ Powerful yet predictable

### Design Complexity

**Risks**:
- ⚠️ More complex than simple `defer`
- ⚠️ Need clear rules for execution order (but well-defined: LIFO within scope)
- ⚠️ Generic functions need compile-time checks (but enforceable)
- ⚠️ Learning curve for nested labels (but pattern is consistent)

**Mitigations**:
- Clear documentation with many examples
- Compile-time errors for invalid patterns
- Simple cases remain simple (`defer` unchanged)
- Progressive disclosure (learn labels when needed)

### Recommendation

**Adopt this complete system**. The benefits significantly outweigh the complexity:

1. **Covers all real-world cleanup scenarios**
2. **Maintains K's design philosophy** (no magic, just sugar)
3. **Enables powerful patterns** (transactions, locks, savepoints)
4. **Zero runtime cost** (compile-time resolution)
5. **Backward compatible** (existing code unchanged)

The defer system becomes a **first-class feature** competitive with RAII while maintaining explicit control flow - perfectly aligned with K's goal of combining Rust's safety with Zig's explicitness.
