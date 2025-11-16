# Pattern Matching Semantics

## Question: Is `if (x) |value|` Trait-Based?

**Short Answer**: No, it's **built-in pattern matching** for enum types, not trait-based.

**Long Answer**: Pattern matching is a core language feature that works directly on enum types, including the sugar types (`?T` = `Option<T>`, `!T` = `Result<T, Error>`).

## How Pattern Matching Works

### 1. Direct Enum Matching (Built-in)

```k
// Pattern matching is built into the language for ALL enums
const Status = enum {
    Ok: i32,
    Err: []const u8,
};

const result = Status{ .Ok = 42 };

// Pattern match with unwrapping
if (result) |value| {  // ERROR: Only works for specific patterns
    // This doesn't work for arbitrary enums
}

// Must use match:
match (result) {
    .Ok => |value| std.debug.print("OK: {}\n", .{value}),
    .Err => |msg| std.debug.print("Error: {s}\n", .{msg}),
}
```

### 2. Special Sugar for Option<T> and Result<T, E>

The `if (x) |value|` syntax is **sugar** that only works for specific patterns:

#### Option<T> Sugar

```k
// Sugar form
if (maybe) |value| {
    use(value);
}

// Desugars to:
match (maybe) {
    .Some => |value| { use(value); },
    .None => {},
}
```

**Why special syntax?** Option is so common that Rust (and K) provide ergonomic syntax.

#### Result<T, E> with try/catch

```k
// try sugar
const value = try operation();  // Propagate error

// Desugars to:
const value = match (operation()) {
    .Ok => |v| v,
    .Err => |e| return .Err(e),
};

// catch sugar
const value = operation() catch |err| {
    handle_error(err);
    return default_value;
};

// Desugars to:
const value = match (operation()) {
    .Ok => |v| v,
    .Err => |err| {
        handle_error(err);
        return default_value;
    },
};
```

## Could It Be Trait-Based? (Alternative Design)

### Option 1: Unwrap Trait

```k
trait Unwrap {
    type Inner;
    fn try_unwrap(self: Self) ?Self.Inner;
}

impl Unwrap for Option<T> {
    type Inner = T;
    fn try_unwrap(self: Option<T>) ?T {
        return match (self) {
            .Some => |v| v,
            .None => null,
        };
    }
}

// Then if-let could desugar to:
if (value) |inner| { ... }
// →
if (value.try_unwrap()) |inner| { ... }
```

**Problem**: This just moves the pattern matching elsewhere, doesn't add value.

### Option 2: Match Trait (for iteration, etc.)

Some operations SHOULD be trait-based:

```k
// Iterator - trait-based ✅
trait Iterator {
    type Item;
    fn next(self: &mut Self) ?Self.Item;
}

// For-loop desugars using trait
for (collection) |item| { ... }
// →
{
    var iter = collection.iter();  // Uses Iterator trait
    while (iter.next()) |item| { ... }
}
```

## Current Design Decision

**K Language Approach**:
1. **Pattern matching is built-in** for enums (like Rust)
2. **Sugar syntax** for common patterns:
   - `if (option) |value|` for Option unwrapping
   - `try expr` for Result propagation
   - `expr catch |err|` for Result handling
3. **Traits are for operations**, not pattern matching:
   - Iterator for `next()`
   - Deref for smart pointers
   - Display/Debug for formatting

## Why Not Trait-Based Pattern Matching?

### Advantages of Built-in:
- ✅ **Type safety**: Compiler knows enum structure
- ✅ **Exhaustiveness**: Compiler can check all variants covered
- ✅ **Performance**: No vtable, direct branch
- ✅ **Simplicity**: No need to implement trait for every enum
- ✅ **Familiar**: Same as Rust, which works well

### Disadvantages of Trait-Based:
- ❌ **Boilerplate**: Every enum needs trait impl
- ❌ **Less type safe**: Can't check exhaustiveness as easily
- ❌ **Complexity**: Another trait to learn
- ❌ **Indirection**: Potential performance cost

## Operator Overloading vs Pattern Matching

Pattern matching is **NOT** operator overloading. Here's the difference:

### Operator Overloading (Trait-Based) ✅

```k
trait Add {
    type Output;
    fn add(self: Self, rhs: Self) Self.Output;
}

impl Add for i32 {
    type Output = i32;
    fn add(self: i32, rhs: i32) i32 {
        return self + rhs;  // Built-in addition
    }
}

// Usage:
const result = a + b;  // Desugars to: a.add(b)
```

**This IS trait-based** - types can customize behavior.

### Pattern Matching (Built-in) ✅

```k
const Status = enum {
    Ok: i32,
    Err: []const u8,
};

match (status) {
    .Ok => |value| process(value),
    .Err => |msg| log(msg),
}
```

**This is NOT trait-based** - works directly on enum structure.

## What Should Be Trait-Based?

| Feature | Trait-Based? | Rationale |
|---------|--------------|-----------|
| **Pattern matching** | ❌ No | Built-in for enums, type-safe |
| **Operators (+, -, etc.)** | ✅ Yes | Types customize behavior |
| **Iteration** | ✅ Yes | Many types can be iterable |
| **Formatting (Debug, Display)** | ✅ Yes | Types customize output |
| **Deref** | ✅ Yes | Smart pointers customize |
| **Drop** | ✅ Yes | Types customize cleanup |
| **Option/Result unwrap** | ❌ No | Sugar over pattern matching |

## Summary

**Current Design (Recommended)**:
- Pattern matching is **built-in** for enums
- Sugar syntax (`if (x) |v|`, `try`, `catch`) desugars to pattern matching
- Traits are for **operations**, not structural matching

**Why**: This matches Rust's proven design and provides:
- Type safety (exhaustiveness checking)
- Performance (no indirection)
- Simplicity (no extra traits to implement)

If you want trait-based polymorphism, use:
- Iterator for iteration
- Deref for smart pointers
- Custom traits for domain logic

Pattern matching stays built-in for correctness and performance.
