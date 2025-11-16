# K Language Syntax Specification

## Overview

K Language syntax is inspired by both Zig and Rust, favoring explicitness and readability for systems programming.

## Lexical Structure

### Keywords

```
// Control flow
if else switch match while for break continue return let

// Functions and types
fn struct enum union const var pub async await

// Memory and ownership
mut ref defer errdefer unsafe nodrop

// Compile-time
comptime inline

// Error handling
try catch error

// Special
void unreachable undefined

// Type system
type trait impl where Self

// Concurrency
Send Sync

// Primitive types
i8 i16 i32 i64 i128 isize
u8 u16 u32 u64 u128 usize
f32 f64
bool
```

### Operators

```
// Arithmetic
+ - * / %

// Comparison
== != < > <= >=

// Logical
and or not

// Bitwise
& | ^ ~ << >>

// Assignment
= += -= *= /= %= &= |= ^= <<= >>=

// Other
. .. ... ? ! @ & * &mut
```

### Comments

```k
// Single-line comment

/// Documentation comment for the following item
pub fn example() void {}

//! Module-level documentation
```

## Types

### Primitive Types

```k
// Integers
const a: i32 = -42;
const b: u64 = 1000;
const c: usize = 0; // Pointer-sized unsigned

// Floating point
const pi: f64 = 3.14159;
const small: f32 = 1.0;

// Boolean
const flag: bool = true;

// Unit type
const unit: void = {};
```

### Arrays

```k
// Fixed-size arrays
const array: [5]i32 = [1, 2, 3, 4, 5];
const zeros: [100]u8 = [0] ** 100;  // Repeat syntax

// Array with undefined values
var buffer: [1024]u8 = undefined;
```

### Slices

```k
// Slices are fat pointers: { ptr: *T, len: usize }
const slice: []const u8 = "hello";
var mut_slice: []u8 = &buffer[0..100];

// Slicing syntax
const sub = slice[1..4];  // Elements 1, 2, 3
const from = slice[5..];  // From index 5 to end
const to = slice[..10];   // From start to index 10
```

### Pointers

```k
// Immutable pointer
const ptr: *const i32 = &value;

// Mutable pointer
const mut_ptr: *mut i32 = &mut value;

// Optional pointer (nullable)
const opt_ptr: ?*i32 = null;

// Pointer dereference
const val = ptr.*;
mut_ptr.* = 42;
```

### References (Borrowed Pointers)

```k
// Immutable reference (borrow)
fn read_data(data: &[u8]) void {
    // Can read but not modify
}

// Mutable reference (mutable borrow)
fn modify_data(data: &mut [u8]) void {
    data[0] = 42;
}

// Reference syntax
var x: i32 = 10;
const ref = &x;      // Immutable reference
const mut_ref = &mut x;  // Mutable reference
```

### Type Sugar

K provides concise syntax for common generic types. All sugar desugars to standard library generic types.

```k
// Optional Types
const maybe: ?i32 = 42;              // Sugar
const maybe: Option<i32> = 42;       // Desugared form (equivalent)

if (maybe) |value| {
    print("{}", .{value});
}

// Error Unions
fn parse() !i32 { ... }              // Sugar for Result<i32, Error>
fn parse() Result<i32, Error> { ... } // Desugared form

const result = try parse();           // Unwrap or propagate error

// Arrays and Slices
const arr: [5]i32 = ...;             // Sugar for Array<i32, 5>
const slice: []i32 = ...;            // Sugar for Slice<i32>

// Pointers and References
const ptr: *i32 = ...;               // Sugar for Ptr<i32>
const ref: &i32 = ...;               // Sugar for Ref<i32>
const mref: &mut i32 = ...;          // Sugar for RefMut<i32>
```

**Complete Sugar Table**:

| Sugar      | Desugars To          | Description                |
|------------|----------------------|----------------------------|
| `?T`       | `Option<T>`          | Optional value             |
| `!T`       | `Result<T, Error>`   | Error union (inferred set) |
| `[N]T`     | `Array<T, N>`        | Fixed-size array           |
| `[]T`      | `Slice<T>`           | Dynamically-sized view     |
| `*T`       | `Ptr<T>`             | Raw pointer                |
| `&T`       | `Ref<T>`             | Immutable reference        |
| `&mut T`   | `RefMut<T>`          | Mutable reference          |

**Why Sugar?**
- **Consistency**: Everything is a library type, no compiler magic
- **Simplicity**: Concise syntax for common cases
- **Transparency**: Can use explicit form for clarity
- **Extensibility**: Understand the underlying generic system

### Structs

```k
// Basic struct
const Point = struct {
    x: f64,
    y: f64,

    // Methods
    pub fn distance(self: &Point) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn move(self: &mut Point, dx: f64, dy: f64) void {
        self.x += dx;
        self.y += dy;
    }
};

// Instantiation
var p = Point{ .x = 3.0, .y = 4.0 };
const dist = p.distance();
p.move(1.0, 1.0);
```

### Enums

```k
// Simple enum
const Color = enum {
    Red,
    Green,
    Blue,
};

// Enum with payloads (tagged unions)
const Result = enum {
    Ok: i32,
    Err: []const u8,
};

// Pattern matching
const result = Result{ .Ok = 42 };
switch (result) {
    .Ok => |value| print("Success: {}", .{value}),
    .Err => |msg| print("Error: {s}", .{msg}),
}
```

### Unions

```k
// Untagged union (unsafe)
const Value = union {
    int: i64,
    float: f64,
    ptr: *void,
};

// Tagged union (safe)
const SafeValue = union(enum) {
    Int: i64,
    Float: f64,
    String: []const u8,
};
```

### Option Types

```k
// Built-in optional type
const maybe_value: ?i32 = null;

// Unwrapping
if (maybe_value) |value| {
    // value is i32 here
    print("{}", .{value});
} else {
    print("No value");
}

// With error handling
const result = try_get_value() orelse return error.NotFound;
```

## Functions

### Function Declaration

```k
// Basic function
fn add(a: i32, b: i32) i32 {
    return a + b;
}

// No return value
fn print_hello() void {
    print("Hello, World!");
}

// Generic function (comptime)
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
```

### Function Pointers

```k
// Function pointer type
const BinaryOp = fn(i32, i32) i32;

// Assign function to variable
const operation: BinaryOp = add;

// Call through pointer
const result = operation(5, 3);
```

### Methods

```k
const Buffer = struct {
    data: []u8,
    allocator: Allocator,

    // Takes &self (immutable)
    pub fn len(self: &Buffer) usize {
        return self.data.len;
    }

    // Takes &mut self (mutable)
    pub fn clear(self: &mut Buffer) void {
        @memset(self.data, 0);
    }

    // Takes self (consumes ownership)
    pub fn into_vec(self: Buffer) []u8 {
        return self.data;
    }
};
```

## Control Flow

### If Expressions

```k
// If statement
if (condition) {
    do_something();
}

// If-else
if (x > 0) {
    positive();
} else if (x < 0) {
    negative();
} else {
    zero();
}

// If as expression
const sign = if (x >= 0) 1 else -1;

// If with optional unwrapping
if (try_get()) |value| {
    use(value);
}
```

### Match Expressions

K uses `match` for exhaustive pattern matching:

```k
// Match on values
const digit = match (n) {
    0 => "zero",
    1 => "one",
    2 => "two",
    3...10 => "small",
    else => "other",
};

// Match on enums
match (color) {
    .Red => print("Red"),
    .Green => print("Green"),
    .Blue => print("Blue"),
}

// Match with payloads
match (result) {
    .Ok => |value| process(value),
    .Err => |msg| handle_error(msg),
}

// Match with guards
match (x) {
    n if (n < 0) => print("Negative"),
    n if (n == 0) => print("Zero"),
    n => print("Positive: {}", .{n}),
}

// Match with destructuring
match (point) {
    { .x = 0.0, .y = 0.0 } => print("Origin"),
    { .x = x, .y = 0.0 } => print("On X axis: {}", .{x}),
    { .x = 0.0, .y = y } => print("On Y axis: {}", .{y}),
    { .x = x, .y = y } => print("Point: ({}, {})", .{x, y}),
}

// Or patterns
match (day) {
    .Saturday | .Sunday => print("Weekend"),
    else => print("Weekday"),
}
```

### If Let

Pattern matching in conditional expressions:

```k
// Match optional values - direct unwrapping (Zig-style)
if (maybe_value) |value| {
    print("Got: {}", .{value});
} else {
    print("Nothing");
}

// Match enum variants with if let
if let (.Ok = result = try_operation()) {
    print("Success: {}", .{result});
}

// With destructuring
if let ({ .x = x, .y = y } = get_point()) {
    print("Point: ({}, {})", .{x, y});
}
```

### While Let

Loop while pattern matches:

```k
// Drain an iterator - direct unwrapping
while (iter.next()) |item| {
    process(item);
}

// Match until error with while let
while let (.Ok = value = read_next()) {
    handle(value);
}
```

### Loops

```k
// While loop
while (condition) {
    do_work();
}

// While with continue expression
var i: usize = 0;
while (i < 10) : (i += 1) {
    print("{}", .{i});
}

// For loop (over ranges)
for (0..10) |i| {
    print("{}", .{i});
}

// For loop (over slices)
const items = [_]i32{1, 2, 3, 4, 5};
for (items) |item| {
    print("{}", .{item});
}

// For with index
for (items, 0..) |item, idx| {
    print("[{}] = {}", .{idx, item});
}

// Break and continue
while (true) {
    if (should_skip()) continue;
    if (should_stop()) break;
    process();
}

// Break with value
const result = while (get_next()) |value| {
    if (is_target(value)) break value;
} else null;
```

## Memory Management

### Allocators

```k
const std = @import("std");
const Allocator = std.mem.Allocator;

fn example(allocator: Allocator) !void {
    // Allocate
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer);  // Cleanup

    // Use buffer
    process(buffer);
}
```

### Defer and Errdefer

```k
fn resource_example() !void {
    const file = try open_file("data.txt");
    defer close_file(file);  // Always executed

    const buffer = try allocate_buffer();
    errdefer free_buffer(buffer);  // Only on error

    try process_file(file, buffer);
    free_buffer(buffer);  // Manual cleanup on success
}
```

### Drop Trait (RAII)

```k
// Automatic cleanup
const File = struct {
    handle: FileHandle,

    pub fn open(path: []const u8) !File {
        const handle = try open_file_handle(path);
        return File{ .handle = handle };
    }

    // Called automatically when File goes out of scope
    pub fn drop(self: &mut File) void {
        close_file_handle(self.handle);
    }
};

// Opt-out with nodrop
const nodrop RawBuffer = struct {
    ptr: [*]u8,
    len: usize,

    // Must call manually
    pub fn deinit(self: &RawBuffer) void {
        raw_free(self.ptr);
    }
};
```

## Error Handling

### Error Sets

```k
// Define error set
const FileError = error {
    NotFound,
    PermissionDenied,
    AlreadyExists,
};

// Function that can return errors
fn open_file(path: []const u8) !FileHandle {
    if (!exists(path)) return error.NotFound;
    if (!has_permission(path)) return error.PermissionDenied;

    return try do_open(path);
}
```

### Try and Catch

```k
// Try operator - propagates errors
fn caller() !void {
    const file = try open_file("data.txt");
    defer file.close();

    try write_data(file);
}

// Catch specific errors
fn with_fallback() void {
    const file = open_file("data.txt") catch |err| {
        switch (err) {
            error.NotFound => return open_default(),
            else => unreachable,
        }
    };
}

// Catch with default value
const value = parse_int(str) catch 0;
```

## Compile-Time Programming

### Comptime

```k
// Compile-time variables
comptime const SIZE: usize = 1024;

// Compile-time function execution
fn fibonacci(n: u32) u32 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

comptime const FIB_10 = fibonacci(10);  // Computed at compile time

// Generic via comptime
fn create_array(comptime T: type, comptime size: usize) [size]T {
    var array: [size]T = undefined;
    return array;
}
```

### Type Reflection

```k
fn print_type_info(comptime T: type) void {
    const info = @typeInfo(T);

    switch (info) {
        .Struct => |s| {
            print("Struct with {} fields", .{s.fields.len});
        },
        .Int => |i| {
            print("Integer: {} bits, signed: {}", .{i.bits, i.signedness == .signed});
        },
        else => {},
    }
}
```

## Lifetimes

### Lifetime Annotations

```k
// Explicit lifetime 'a
fn longest<'a>(x: &'a str, y: &'a str) &'a str {
    if (x.len > y.len) return x else return y;
}

// Multiple lifetimes
fn choose<'a, 'b>(first: &'a str, second: &'b str, flag: bool) &'a str {
    return if (flag) first else first;  // Only returns 'a
}

// Lifetime in structs
const Container<'a> = struct {
    data: &'a [u8],

    pub fn get(self: &Container<'a>) &'a [u8] {
        return self.data;
    }
};
```

### Lifetime Elision

K follows Rust's lifetime elision rules:

```k
// No annotation needed - inferred
fn first(slice: &[i32]) &i32 {
    return &slice[0];
}

// Equivalent explicit form
fn first_explicit<'a>(slice: &'a [i32]) &'a i32 {
    return &slice[0];
}
```

## Unsafe

```k
// Unsafe block for low-level operations
fn raw_pointer_example() void {
    var x: i32 = 42;

    unsafe {
        const ptr: *mut i32 = &mut x;
        const raw_ptr = @ptrToInt(ptr);
        const back = @intToPtr(*mut i32, raw_ptr);
        back.* = 100;
    }

    // x is now 100
}

// Unsafe functions must be called in unsafe blocks
unsafe fn raw_memory_copy(dest: *void, src: *const void, len: usize) void {
    @memcpy(dest, src, len);
}

fn caller() void {
    unsafe {
        raw_memory_copy(dest_ptr, src_ptr, 100);
    }
}
```

## Traits

```k
// Define a trait
trait Display {
    fn fmt(self: &Self, buffer: &mut Buffer) !void;
}

// Implement trait for type
impl Display for Point {
    fn fmt(self: &Point, buffer: &mut Buffer) !void {
        try buffer.print("({}, {})", .{self.x, self.y});
    }
}

// Generic function with trait bound
fn print_value(comptime T: type, value: &T) !void
    where T: Display
{
    var buffer = Buffer.init();
    try value.fmt(&mut buffer);
    print("{s}", .{buffer.items});
}
```

## Async/Await

Asynchronous programming with async functions and await:

```k
// Async function returns a Future
async fn fetch_data(url: []const u8) ![]u8 {
    const response = await http_get(url);
    return response.body;
}

// Await suspends until future completes
async fn process() !void {
    const data = await fetch_data("https://example.com");
    defer allocator.free(data);

    print("Got {} bytes\n", .{data.len});
}

// Run multiple async tasks concurrently
async fn download_all(urls: [][]const u8) !void {
    var tasks = ArrayList(Future([]u8)).init(allocator);

    for (urls) |url| {
        try tasks.append(async fetch_data(url));
    }

    for (tasks.items) |task| {
        const data = await task;
        defer allocator.free(data);
        process_data(data);
    }
}

// Select - wait for first to complete
async fn race() !void {
    const task1 = async operation1();
    const task2 = async operation2();

    const result = select(.{task1, task2});

    match (result) {
        .task1 => |val| print("Task 1: {}\n", .{val}),
        .task2 => |val| print("Task 2: {}\n", .{val}),
    }
}
```

## Concurrency

Thread safety with Send/Sync traits:

```k
// Send: safe to transfer between threads
// Sync: safe to share references between threads

// Atomic types are both Send and Sync
const Counter = struct {
    value: AtomicI32,
};

impl Send for Counter {}
impl Sync for Counter {}

// Opt-out of Send/Sync
const !Send !Sync LocalData = struct {
    ptr: *void,
};

// Spawn threads
fn spawn_worker() !void {
    const handle = try Thread.spawn(.{}, worker, .{42});
    handle.join();
}

// Mutex for shared state
const SharedData = struct {
    mutex: Mutex,
    value: i32,

    pub fn increment(self: &SharedData) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
    }
};
```

## Modules and Imports

```k
// Import standard library
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// Import local module
const utils = @import("utils.k");

// Public declarations
pub const VERSION = "0.1.0";

pub fn init() !void {
    // Initialization code
}

// Public to crate (entire project)
pub(crate) fn internal_api() void {
    // Visible anywhere in this crate
}

// Public to parent module
pub(super) fn parent_only() void {
    // Visible to parent module only
}

// Private by default
const internal_constant = 42;

fn internal_helper() void {
    // Not visible outside this module
}
```

## Built-in Functions

```k
// Type operations
@typeInfo(T)      // Get type information
@TypeOf(value)    // Get type of value
@sizeOf(T)        // Size in bytes
@alignOf(T)       // Alignment requirement

// Memory operations
@memset(dest, value)
@memcpy(dest, src, len)
@memcmp(a, b, len)

// Math operations
@sqrt(x)
@sin(x)
@cos(x)
@floor(x)
@ceil(x)

// Compile-time operations
@compileError(msg)
@compileLog(value)

// Pointer operations
@ptrToInt(ptr)
@intToPtr(T, int)
@ptrCast(T, ptr)

// Bit operations
@bitCast(T, value)
@byteSwap(value)
@clz(value)  // Count leading zeros
@ctz(value)  // Count trailing zeros
```

## Naming Conventions

- **Types**: PascalCase (`Point`, `ArrayList`)
- **Functions**: snake_case (`do_work`, `get_value`)
- **Constants**: SCREAMING_SNAKE_CASE (`MAX_SIZE`, `DEFAULT_TIMEOUT`)
- **Variables**: snake_case (`buffer_size`, `user_name`)
- **Lifetimes**: lowercase single letter (`'a`, `'b`)

## Example: Complete Program

```k
const std = @import("std");
const Allocator = std.mem.Allocator;

const Buffer = struct {
    data: []u8,
    len: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, capacity: usize) !Buffer {
        const data = try allocator.alloc(u8, capacity);
        return Buffer{
            .data = data,
            .len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: &mut Buffer) void {
        self.allocator.free(self.data);
    }

    pub fn push(self: &mut Buffer, byte: u8) !void {
        if (self.len >= self.data.len) return error.BufferFull;
        self.data[self.len] = byte;
        self.len += 1;
    }

    pub fn as_slice(self: &Buffer) []const u8 {
        return self.data[0..self.len];
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer = try Buffer.init(allocator, 1024);
    defer buffer.deinit();

    try buffer.push('H');
    try buffer.push('i');

    const slice = buffer.as_slice();
    std.debug.print("{s}\n", .{slice});
}
```

## References

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Rust Reference](https://doc.rust-lang.org/reference/)
- [Rust Book](https://doc.rust-lang.org/book/)
