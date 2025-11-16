# Pattern Matching and Generics in K Language

## Pattern Matching

K provides powerful pattern matching capabilities for destructuring data and control flow.

### Match Expression

The `match` keyword provides exhaustive pattern matching:

```k
const Result = enum {
    Ok: i32,
    Err: []const u8,
};

fn process_result(result: Result) void {
    match (result) {
        .Ok => |value| {
            std.debug.print("Success: {}\n", .{value});
        },
        .Err => |msg| {
            std.debug.print("Error: {s}\n", .{msg});
        },
    }
}
```

### If Let

`if let` allows pattern matching in conditional expressions:

```k
fn check_option(maybe_value: ?i32) void {
    // Option 1: Direct optional unwrapping (recommended)
    if (maybe_value) |value| {
        std.debug.print("Got value: {}\n", .{value});
    } else {
        std.debug.print("No value\n", .{});
    }
}

// Option 2: If let with ? pattern
fn check_option_alt(maybe_value: ?i32) void {
    if let (?value = maybe_value) {
        std.debug.print("Got value: {}\n", .{value});
    }
}

// With enum variants
fn process_if_ok(result: Result) void {
    if let (.Ok = value = result) {
        std.debug.print("Processing: {}\n", .{value});
    }
}
```

### While Let

`while let` loops while a pattern matches:

```k
fn drain_iterator(iter: &mut Iterator(i32)) void {
    // Iterator.next() returns ?i32
    // Option 1: Direct optional unwrapping (recommended)
    while (iter.next()) |item| {
        std.debug.print("Item: {}\n", .{item});
    }
}

// Option 2: while let with ? pattern
fn drain_iterator_alt(iter: &mut Iterator(i32)) void {
    while let (?item = iter.next()) {
        std.debug.print("Item: {}\n", .{item});
    }
}
```

### Destructuring

#### Tuple Destructuring

```k
const Point = struct {
    x: f64,
    y: f64,
};

fn destructure_tuple() void {
    const point = Point{ .x = 3.0, .y = 4.0 };

    // Destructure in let binding
    const { .x = px, .y = py } = point;
    std.debug.print("x={}, y={}\n", .{px, py});

    // Destructure in function parameters
    fn print_point({ .x = x, .y = y }: Point) void {
        std.debug.print("({}, {})\n", .{x, y});
    }
}
```

#### Array Destructuring

```k
fn destructure_array() void {
    const arr = [_]i32{1, 2, 3, 4, 5};

    // Match first elements
    match (arr) {
        [first, second, ..rest] => {
            std.debug.print("First: {}, Second: {}\n", .{first, second});
            std.debug.print("Rest: {any}\n", .{rest});
        },
        else => {},
    }
}
```

#### Nested Destructuring

```k
const Person = struct {
    name: []const u8,
    age: u32,
    address: Address,
};

const Address = struct {
    city: []const u8,
    country: []const u8,
};

fn nested_destructure(person: Person) void {
    const {
        .name = name,
        .address = { .city = city, .country = country }
    } = person;

    std.debug.print("{s} from {s}, {s}\n", .{name, city, country});
}
```

### Pattern Guards

```k
fn match_with_guard(x: i32) void {
    match (x) {
        n if (n < 0) => std.debug.print("Negative\n", .{}),
        n if (n > 100) => std.debug.print("Large\n", .{}),
        n => std.debug.print("Normal: {}\n", .{n}),
    }
}
```

### Range Patterns

```k
fn categorize_age(age: u32) []const u8 {
    return match (age) {
        0...12 => "child",
        13...19 => "teenager",
        20...64 => "adult",
        65... => "senior",
    };
}
```

### Or Patterns

```k
fn is_weekend(day: Day) bool {
    return match (day) {
        .Saturday | .Sunday => true,
        else => false,
    };
}
```

### Wildcard Pattern

```k
fn ignore_some_fields() void {
    const point = Point3D{ .x = 1.0, .y = 2.0, .z = 3.0 };

    match (point) {
        { .x = x, .y = _, .z = _ } => {
            // Only care about x
            std.debug.print("x = {}\n", .{x});
        },
    }
}
```

## Generics

K provides two approaches to generics: compile-time generics via `comptime` and trait-based generics.

### Comptime Generics (Zig-style)

```k
// Generic function with comptime type parameter
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

// Usage - type is inferred or explicit
const result1 = max(i32, 5, 10);
const result2 = max(f64, 3.14, 2.71);
```

### Generic Structs

```k
// Generic struct with comptime type parameter
fn ArrayList(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = &[_]T{},
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn append(self: &mut Self, item: T) !void {
            // Implementation
        }

        pub fn get(self: &Self, index: usize) ?T {
            if (index >= self.len) return null;
            return self.items[index];
        }
    };
}

// Usage
fn use_arraylist(allocator: Allocator) !void {
    var list = ArrayList(i32).init(allocator);
    defer list.deinit();

    try list.append(42);
    try list.append(100);
}
```

### Comptime Constraints

```k
// Constraint: T must be numeric
fn sum(comptime T: type, slice: []const T) T
    comptime {
        const info = @typeInfo(T);
        if (info != .Int and info != .Float) {
            @compileError("sum() requires numeric type");
        }
    }
{
    var total: T = 0;
    for (slice) |item| {
        total += item;
    }
    return total;
}
```

### Trait-Based Generics (Rust-style)

```k
// Define a trait
trait Display {
    fn fmt(self: &Self, buffer: &mut Buffer) !void;
}

trait Debug {
    fn debug_fmt(self: &Self, buffer: &mut Buffer) !void;
}

// Generic function with trait bounds
fn print_value(comptime T: type, value: &T) !void
    where T: Display
{
    var buffer = Buffer.init();
    defer buffer.deinit();

    try value.fmt(&mut buffer);
    std.debug.print("{s}\n", .{buffer.items});
}

// Multiple trait bounds
fn debug_and_display(comptime T: type, value: &T) !void
    where T: Display + Debug
{
    var buffer = Buffer.init();
    defer buffer.deinit();

    try value.debug_fmt(&mut buffer);
    std.debug.print("Debug: {s}\n", .{buffer.items});

    buffer.clear();
    try value.fmt(&mut buffer);
    std.debug.print("Display: {s}\n", .{buffer.items});
}
```

### Implementing Traits for Types

```k
const Point = struct {
    x: f64,
    y: f64,
};

// Implement Display for Point
impl Display for Point {
    fn fmt(self: &Point, buffer: &mut Buffer) !void {
        try buffer.print("({d:.2}, {d:.2})", .{self.x, self.y});
    }
}

// Implement Debug for Point
impl Debug for Point {
    fn debug_fmt(self: &Point, buffer: &mut Buffer) !void {
        try buffer.print("Point {{ x: {d}, y: {d} }}", .{self.x, self.y});
    }
}

// Now Point can be used with generic functions
fn example() !void {
    const p = Point{ .x = 3.0, .y = 4.0 };
    try print_value(Point, &p);
    try debug_and_display(Point, &p);
}
```

### Generic Traits

```k
// Trait with associated type
trait Iterator {
    type Item;

    fn next(self: &mut Self) ?Self.Item;
}

// Implement Iterator for a range
const Range = struct {
    start: i32,
    end: i32,
};

impl Iterator for Range {
    type Item = i32;

    fn next(self: &mut Range) ?i32 {
        if (self.start >= self.end) return null;

        const value = self.start;
        self.start += 1;
        return value;
    }
}

// Generic function using Iterator trait
fn sum_iterator(comptime I: type, iter: &mut I) I.Item
    where I: Iterator,
          I.Item: Add
{
    var total: I.Item = 0;
    while (iter.next()) |item| {
        total = total + item;
    }
    return total;
}
```

### Higher-Kinded Types (HKT)

K supports higher-kinded types for advanced generic programming:

```k
// Functor trait (HKT)
trait Functor(F: type -> type) {
    fn map(
        comptime A: type,
        comptime B: type,
        self: F(A),
        f: fn(A) B,
    ) F(B);
}

// Implement Functor for Option
impl Functor(?T) for Option {
    fn map(
        comptime A: type,
        comptime B: type,
        self: ?A,
        f: fn(A) B,
    ) ?B {
        return if (self) |value| f(value) else null;
    }
}

// Usage
fn double(x: i32) i32 {
    return x * 2;
}

fn hkt_example() void {
    const x: ?i32 = 42;
    const y = Option.map(i32, i32, x, double);  // ?i32 = 84
}
```

### Generic Constraints with Where Clauses

```k
// Complex constraints
fn complex_generic(
    comptime T: type,
    comptime U: type,
    value: T,
) U
    where
        T: Display + Debug + Clone,
        U: From(T) + Default,
{
    // Implementation
}
```

### Const Generics

K supports compile-time constant parameters:

```k
// Generic over value (not just type)
fn FixedArray(comptime T: type, comptime N: usize) type {
    return struct {
        data: [N]T,

        pub fn init() @This() {
            return @This(){
                .data = undefined,
            };
        }

        pub fn len(self: &@This()) usize {
            return N;
        }

        pub fn get(self: &@This(), index: usize) ?T {
            if (index >= N) return null;
            return self.data[index];
        }
    };
}

// Usage
fn use_fixed_array() void {
    var arr = FixedArray(i32, 10).init();
    arr.data[0] = 42;

    std.debug.print("Length: {}\n", .{arr.len()});
}
```

### Generic Type Aliases

```k
// Type alias with generic parameters
const Vec = fn(comptime T: type) type {
    return ArrayList(T);
};

const StringMap = fn(comptime V: type) type {
    return HashMap([]const u8, V);
};

// Usage
fn use_aliases(allocator: Allocator) !void {
    var numbers = Vec(i32).init(allocator);
    var config = StringMap(i32).init(allocator);
}
```

### Pattern Matching on Generic Types

```k
fn generic_match(comptime T: type, value: T) void {
    const info = @typeInfo(T);

    match (info) {
        .Int => |int_info| {
            std.debug.print("Integer with {} bits\n", .{int_info.bits});
        },
        .Float => |float_info| {
            std.debug.print("Float with {} bits\n", .{float_info.bits});
        },
        .Struct => |struct_info| {
            std.debug.print("Struct with {} fields\n", .{struct_info.fields.len});
        },
        else => {
            std.debug.print("Other type\n", .{});
        },
    }
}
```

## Advanced Pattern Matching

### @ Bindings

Bind the whole value while destructuring:

```k
fn process_point(point @ { .x = x, .y = y }: Point) void {
    // Both 'point' and 'x', 'y' are available
    std.debug.print("Point: {any}, x={}, y={}\n", .{point, x, y});
}
```

### Ref Patterns

Match references without taking ownership:

```k
fn match_by_ref(value: &Result) void {
    match (value) {
        &.Ok => |ref val| {
            // val is &i32, not i32
            std.debug.print("Reference to ok value: {}\n", .{val.*});
        },
        &.Err => |ref msg| {
            // msg is &[]const u8
            std.debug.print("Reference to error: {s}\n", .{msg.*});
        },
    }
}
```

### Exhaustiveness Checking

K's compiler ensures all patterns are covered:

```k
const Color = enum {
    Red,
    Green,
    Blue,
};

fn match_color(color: Color) void {
    match (color) {
        .Red => std.debug.print("Red\n", .{}),
        .Green => std.debug.print("Green\n", .{}),
        // ERROR: non-exhaustive match, missing .Blue
    }
}

// Fix with else or explicit pattern
fn match_color_fixed(color: Color) void {
    match (color) {
        .Red => std.debug.print("Red\n", .{}),
        .Green => std.debug.print("Green\n", .{}),
        .Blue => std.debug.print("Blue\n", .{}),
    }
}
```

## Comparison with Rust and Zig

| Feature | Rust | Zig | K |
|---------|------|-----|---|
| Match expressions | Yes | Limited (switch) | Yes |
| If let | Yes | No | Yes |
| While let | Yes | No | Yes |
| Destructuring | Yes | Limited | Yes |
| Pattern guards | Yes | No | Yes |
| Comptime generics | No | Yes | Yes |
| Trait-based generics | Yes | No | Yes |
| Associated types | Yes | No | Yes |
| Const generics | Yes (limited) | Yes | Yes |
| HKT | No | No | Yes |

## Design Rationale

### Why Both Comptime and Traits?

1. **Comptime** - Zero-cost, Zig-style monomorphization for systems code
2. **Traits** - Ergonomic bounds, dynamic dispatch when needed
3. **Flexibility** - Choose the right tool for the job

### Why Powerful Pattern Matching?

1. **Ergonomics** - Destructuring reduces boilerplate
2. **Safety** - Exhaustiveness checking prevents bugs
3. **Expressiveness** - Complex data transformations are clear

### Why Higher-Kinded Types?

1. **Abstraction** - Generic over type constructors (Option, Result, etc.)
2. **Reusability** - Common patterns (Functor, Monad) work across types
3. **Advanced libraries** - Enable sophisticated generic libraries

## Examples

### Example 1: Generic Result Type with Pattern Matching

```k
fn Result(comptime T: type, comptime E: type) type {
    return enum {
        Ok: T,
        Err: E,

        pub fn map(self: @This(), comptime U: type, f: fn(T) U) Result(U, E) {
            return match (self) {
                .Ok => |value| Result(U, E){ .Ok = f(value) },
                .Err => |err| Result(U, E){ .Err = err },
            };
        }

        pub fn and_then(
            self: @This(),
            comptime U: type,
            f: fn(T) Result(U, E),
        ) Result(U, E) {
            return match (self) {
                .Ok => |value| f(value),
                .Err => |err| Result(U, E){ .Err = err },
            };
        }

        pub fn is_ok(self: @This()) bool {
            return match (self) {
                .Ok => true,
                .Err => false,
            };
        }
    };
}

fn example_result() void {
    const result = Result(i32, []const u8){ .Ok = 42 };

    const doubled = result.map(i32, fn(x: i32) i32 { return x * 2; });

    match (doubled) {
        .Ok => |value| std.debug.print("Result: {}\n", .{value}),
        .Err => |err| std.debug.print("Error: {s}\n", .{err}),
    }
}

// Note: For simple optional values, use built-in ?T type:
//   const maybe: ?i32 = 42;
//   if (maybe) |value| { ... }
```

### Example 2: Generic Tree with Trait Bounds

```k
fn BinaryTree(comptime T: type) type
    where T: Ord
{
    return struct {
        value: T,
        left: ?*@This(),
        right: ?*@This(),
        allocator: Allocator,

        pub fn insert(self: &mut @This(), value: T) !void {
            if (value < self.value) {
                if (self.left) |left| {
                    try left.insert(value);
                } else {
                    const node = try self.allocator.create(@This());
                    node.* = @This(){
                        .value = value,
                        .left = null,
                        .right = null,
                        .allocator = self.allocator,
                    };
                    self.left = node;
                }
            } else {
                // Similar for right
            }
        }
    };
}
```

## References

- [Rust Pattern Matching](https://doc.rust-lang.org/book/ch18-00-patterns.html)
- [Rust Generics](https://doc.rust-lang.org/book/ch10-00-generics.html)
- [Zig Comptime](https://ziglang.org/documentation/master/#comptime)
- [Haskell Type Classes](https://www.haskell.org/tutorial/classes.html)
