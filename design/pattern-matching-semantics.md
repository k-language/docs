# Pattern Matching Semantics

## Question: Is `if (x) |value|` Trait-Based?

**Short Answer**: **YES!** It's trait-based for maximum extensibility.

**Long Answer**: `if (x) |value|` desugars to a trait method call, allowing any type to implement unwrapping behavior. This is more consistent with K's "no compiler magic" philosophy.

## How Pattern Matching Works

### 1. Trait-Based Unwrapping

The `if (x) |value|` syntax uses the `Unwrappable` trait:

```k
/// Trait for types that can be unwrapped in if-let expressions.
trait Unwrappable {
    type Inner;

    /// Try to unwrap the value. Returns null if empty/none.
    fn try_unwrap(self) ?Self.Inner;
}
```

**Desugaring**:
```k
// You write:
if (maybe) |value| {
    use(value);
}

// Desugars to:
if (maybe.try_unwrap()) |value| {
    use(value);
}

// Which further desugars to:
match (maybe.try_unwrap()) {
    .Some => |value| { use(value); },
    .None => {},
}
```

### 2. Standard Implementations

#### Option<T> Implementation

```k
// Option<T> implements Unwrappable
impl Unwrappable for Option<T> {
    type Inner = T;

    fn try_unwrap(self) ?T {
        return match (self) {
            .Some => |value| value,
            .None => null,
        };
    }
}

// Now you can use if-let
const maybe: ?i32 = 42;  // Sugar for Option<i32>

if (maybe) |value| {  // Uses Unwrappable trait
    std.debug.print("{}\n", .{value});
}
```

#### Result<T, E> Implementation

```k
// Result<T, E> unwraps only the Ok variant
impl Unwrappable for Result<T, E> {
    type Inner = T;

    fn try_unwrap(self) ?T {
        return match (self) {
            .Ok => |value| value,
            .Err => null,  // Errors become null
        };
    }
}

// Usage
const result: !i32 = try compute();  // Sugar for Result<i32, Error>

if (result) |value| {
    // Only executes if result is .Ok
    std.debug.print("Success: {}\n", .{value});
}
```

**Note**: For full error handling, use `match` or `catch`:
```k
// Get error information
result catch |err| {
    std.debug.print("Error: {}\n", .{err});
};
```

### 3. Iterator Implementation

Iterators can also be unwrapped:

```k
impl Unwrappable for Iterator {
    type Inner = Self.Item;

    fn try_unwrap(self: &mut Self) ?Self.Item {
        return self.next();
    }
}

// While-let loop
var iter = vec.iter();
while (iter) |item| {  // Uses Unwrappable::try_unwrap
    process(item);
}

// Desugars to:
while (iter.try_unwrap()) |item| {
    process(item);
}
```

### 4. Custom Type Implementation

Users can implement Unwrappable for their own types:

```k
const Validated<T> = struct {
    value: T,
    is_valid: bool,

    pub fn new(value: T, is_valid: bool) Validated<T> {
        return Validated<T>{ .value = value, .is_valid = is_valid };
    }
};

impl Unwrappable for Validated<T> {
    type Inner = T;

    fn try_unwrap(self) ?T {
        if (self.is_valid) {
            return self.value;
        }
        return null;
    }
}

// Now works with if-let!
const validated = Validated.new(42, true);

if (validated) |value| {
    std.debug.print("Valid: {}\n", .{value});
}
```

## Match vs If-Let

### Match (Built-in Pattern Matching)

`match` provides exhaustive pattern matching for enums:

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

**This is built-in** - the compiler understands enum structure and can verify all variants are covered.

### If-Let (Trait-Based Unwrapping)

`if (x) |value|` uses the `Unwrappable` trait, which is extensible:

```k
// Trait-based - any type can implement
if (maybe) |value| {
    use(value);
}

// Desugars to:
if (maybe.try_unwrap()) |value| {
    use(value);
}
```

**This is trait-based** - types can customize unwrapping behavior via the `Unwrappable` trait.

### Result<T, E> with try/catch

```k
// try sugar - propagates errors
const value = try operation();  // Propagate error

// Desugars to:
const value = match (operation()) {
    .Ok => |v| v,
    .Err => |e| return .Err(e),
};

// catch sugar - handles errors
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

Both `try` and `catch` desugar to `match` expressions on the enum structure.

## Design Philosophy

### What Is Trait-Based?

K Language uses traits for **customizable operations**:

| Feature | Trait-Based? | Rationale |
|---------|--------------|-----------|
| **if-let unwrapping** | ✅ Yes | `Unwrappable` trait - extensible to custom types |
| **Operators (+, -, etc.)** | ✅ Yes | Types customize behavior via operator traits |
| **Iteration** | ✅ Yes | `Iterator` trait - many types can be iterable |
| **Formatting (Debug, Display)** | ✅ Yes | Types customize output |
| **Deref** | ✅ Yes | Smart pointers customize dereferencing |
| **Drop** | ✅ Yes | Types customize cleanup |
| **Match on enums** | ❌ No | Built-in for type safety and exhaustiveness |

### Why If-Let Is Trait-Based

Making `if (x) |value|` trait-based provides:

✅ **Extensibility**: Any type can implement `Unwrappable`, not just Option/Result
✅ **No compiler magic**: Clear desugaring to trait method call
✅ **Consistency**: Like operator overloading, it's just syntax sugar for a trait method
✅ **Custom types**: Users can add if-let support to domain-specific types

Example of extensibility:
```k
// Custom validated type works with if-let
const validated = Validated.new(42, true);

if (validated) |value| {  // Uses Validated's Unwrappable impl
    std.debug.print("Valid: {}\n", .{value});
}
```

### Why Match Is Built-In

Enum pattern matching stays built-in because:

✅ **Type safety**: Compiler knows exact enum structure
✅ **Exhaustiveness**: Compiler can check all variants are covered
✅ **Performance**: Direct branch, no trait dispatch
✅ **Clarity**: Pattern matching is structural, not behavioral

## Summary

**K Language Design**:

1. **If-let is trait-based** (`Unwrappable` trait)
   - Sugar: `if (x) |value|` → `if (x.try_unwrap()) |value|`
   - Extensible to custom types
   - No compiler magic

2. **Match is built-in** (enum pattern matching)
   - Structural matching on enum variants
   - Exhaustiveness checking
   - Type-safe and performant

3. **Error handling** (`try`/`catch`)
   - Sugar for `match` expressions
   - Works on Result enum structure

**Benefits**:
- **Extensibility**: Unwrappable trait lets custom types work with if-let
- **Type safety**: Built-in match provides exhaustiveness checking
- **No magic**: Clear desugaring rules for all syntax sugar
- **Consistency**: Traits for operations (Unwrappable, Iterator, Drop, etc.)

This design combines Rust's safety with extensibility through traits, following K's "no compiler magic" philosophy.
