# Comptime Feature Comparison: K vs Zig

## Overview

This document compares K Language's `comptime` features with Zig's comptime capabilities to identify gaps and ensure K provides a comprehensive compile-time programming system.

## Zig's Comptime Features

### 1. Comptime Parameters

**Zig**:
```zig
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
```

**K**: ✅ Fully supported
```k
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
```

**Status**: Complete parity

---

### 2. Comptime Variables

**Zig**:
```zig
comptime var x: i32 = 1;
x += 1;
comptime {
    x += 1;
}
// x is now 3 at compile time
```

**K**: ❌ Not documented
```k
// Missing: comptime variables
comptime var counter: usize = 0;
```

**Status**: **MISSING** - Need to add comptime variable support

---

### 3. Comptime Blocks

**Zig**:
```zig
fn fibonacci(comptime n: u32) u32 {
    comptime {
        if (n <= 1) return n;
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}

const fib10 = fibonacci(10); // Computed at compile time
```

**K**: ⚠️ Partially supported through constraints
```k
// Currently only in constraints:
fn sum(comptime T: type, slice: []const T) T
    comptime {
        const info = @typeInfo(T);
        if (info != .Int and info != .Float) {
            @compileError("sum() requires numeric type");
        }
    }
{
    // function body
}
```

**Status**: **INCOMPLETE** - Need standalone comptime blocks

---

### 4. Comptime Type Introspection

**Zig**:
```zig
const std = @import("std");

fn printTypeInfo(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .Int => |int| std.debug.print("Int: {} bits\n", .{int.bits}),
        .Float => |float| std.debug.print("Float: {} bits\n", .{float.bits}),
        .Struct => |s| std.debug.print("Struct: {} fields\n", .{s.fields.len}),
        else => std.debug.print("Other\n", .{}),
    }
}
```

**K**: ✅ Supported
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

**Status**: Complete parity

---

### 5. @compileError

**Zig**:
```zig
fn onlyInts(comptime T: type) void {
    if (@typeInfo(T) != .Int) {
        @compileError("Only integer types allowed");
    }
}
```

**K**: ✅ Supported (shown in constraints example)
```k
fn sum(comptime T: type, slice: []const T) T
    comptime {
        const info = @typeInfo(T);
        if (info != .Int and info != .Float) {
            @compileError("sum() requires numeric type");
        }
    }
{
    // ...
}
```

**Status**: Complete parity

---

### 6. @compileLog

**Zig**:
```zig
fn debugComptime(comptime T: type) void {
    @compileLog("Type is: ", T);
    @compileLog("Size is: ", @sizeOf(T));
}
```

**K**: ❌ Not documented
```k
// Missing: @compileLog builtin
```

**Status**: **MISSING** - Need @compileLog for debugging

---

### 7. Inline Loops (comptime for)

**Zig**:
```zig
inline for ([_]type{ i8, i16, i32, i64 }) |T| {
    std.debug.print("Size of {s}: {}\n", .{ @typeName(T), @sizeOf(T) });
}
```

**K**: ❌ Not documented
```k
// Missing: inline for loops
comptime for ([_]type{ i8, i16, i32, i64 }) |T| {
    // Unrolled at compile time
}
```

**Status**: **MISSING** - Critical feature for metaprogramming

---

### 8. Inline While

**Zig**:
```zig
comptime var i: usize = 0;
inline while (i < 4) : (i += 1) {
    // Loop unrolled at compile time
}
```

**K**: ❌ Not documented

**Status**: **MISSING**

---

### 9. @Type() - Runtime Type Construction

**Zig**:
```zig
const std = @import("std");
const builtin = @import("builtin");

fn makeIntType(comptime signedness: builtin.Signedness, comptime bits: u16) type {
    return @Type(.{
        .Int = .{
            .signedness = signedness,
            .bits = bits,
        },
    });
}

const MyInt = makeIntType(.signed, 47); // Custom 47-bit signed integer!
```

**K**: ❌ Not documented
```k
// Missing: @Type() for runtime type construction
```

**Status**: **MISSING** - Advanced feature for type-level programming

---

### 10. @field() - Compile-time Field Access

**Zig**:
```zig
const Point = struct {
    x: f32,
    y: f32,
};

fn getField(point: Point, comptime field_name: []const u8) f32 {
    return @field(point, field_name);
}

const p = Point{ .x = 1.0, .y = 2.0 };
const x_value = getField(p, "x"); // 1.0
```

**K**: ❌ Not documented

**Status**: **MISSING** - Useful for generic code

---

### 11. @hasField(), @hasDecl()

**Zig**:
```zig
fn requiresXField(comptime T: type) void {
    if (!@hasField(T, "x")) {
        @compileError("Type must have field 'x'");
    }
}

fn requiresInit(comptime T: type) void {
    if (!@hasDecl(T, "init")) {
        @compileError("Type must have 'init' function");
    }
}
```

**K**: ❌ Not documented

**Status**: **MISSING** - Important for duck typing checks

---

### 12. @fieldParentPtr() - Container Intrusion

**Zig**:
```zig
const Node = struct {
    data: i32,
    next: ?*Node,
};

fn getContainingNode(data_ptr: *i32) *Node {
    return @fieldParentPtr(Node, "data", data_ptr);
}
```

**K**: ❌ Not documented

**Status**: **MISSING** - Advanced use case (intrusive lists)

---

### 13. @sizeOf(), @alignOf(), @offsetOf()

**Zig**:
```zig
const Point = struct {
    x: f64,
    y: f64,
};

comptime {
    std.debug.assert(@sizeOf(Point) == 16);
    std.debug.assert(@alignOf(Point) == 8);
    std.debug.assert(@offsetOf(Point, "y") == 8);
}
```

**K**: ❌ Not explicitly documented
```k
// Need: @sizeOf, @alignOf, @offsetOf builtins
```

**Status**: **MISSING** - Essential for FFI and low-level code

---

### 14. @bitSizeOf(), @bitOffsetOf()

**Zig**:
```zig
const Flags = packed struct {
    a: bool,
    b: bool,
    c: u6,
};

comptime {
    std.debug.assert(@bitSizeOf(Flags) == 8);
    std.debug.assert(@bitOffsetOf(Flags, "c") == 2);
}
```

**K**: ❌ Not documented

**Status**: **MISSING** - For packed structs and bit-level manipulation

---

### 15. Comptime Function Calls

**Zig**:
```zig
fn factorial(n: u32) u32 {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

const fac5 = comptime factorial(5); // 120, computed at compile time
```

**K**: ⚠️ Implied but not documented
```k
// Should work but not documented:
const fac5 = comptime factorial(5);
```

**Status**: **UNCLEAR** - Need explicit documentation

---

### 16. @as() - Type Coercion

**Zig**:
```zig
const x = @as(f32, 5); // Explicit cast to f32
```

**K**: ❌ Not documented
```k
// Missing: @as() builtin for explicit casts
// Currently use: const x: f32 = 5;
```

**Status**: **MISSING** - Convenience feature

---

### 17. @import() - Compile-time Module Loading

**Zig**:
```zig
const std = @import("std");
const my_module = @import("my_module.zig");
```

**K**: ✅ Documented
```k
const std = @import("std");
const utils = @import("utils.k");
```

**Status**: Complete parity

---

### 18. @embedFile() - Embed Files at Compile Time

**Zig**:
```zig
const shader_code = @embedFile("shader.glsl");
const config = @embedFile("config.json");
```

**K**: ❌ Not documented
```k
// Missing: @embedFile() for embedding file contents
```

**Status**: **MISSING** - Useful for assets, shaders, configs

---

### 19. @This() - Get Current Type

**Zig**:
```zig
const MyStruct = struct {
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }
};
```

**K**: ✅ Documented
```k
fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn init() Self {
            return Self{ /* ... */ };
        }
    };
}
```

**Status**: Complete parity

---

### 20. @typeName() - Get Type Name as String

**Zig**:
```zig
fn printTypeName(comptime T: type) void {
    std.debug.print("Type: {s}\n", .{@typeName(T)});
}

printTypeName(i32); // "i32"
printTypeName(Point); // "Point"
```

**K**: ❌ Not documented

**Status**: **MISSING** - Useful for debugging

---

### 21. @typeInfo() Enum Variants

**Zig**: Complete set of type info variants
```zig
const TypeInfo = enum {
    Type,
    Void,
    Bool,
    NoReturn,
    Int,
    Float,
    Pointer,
    Array,
    Struct,
    ComptimeFloat,
    ComptimeInt,
    Undefined,
    Null,
    Optional,
    ErrorUnion,
    ErrorSet,
    Enum,
    Union,
    Fn,
    BoundFn,
    Opaque,
    Frame,
    AnyFrame,
    Vector,
    EnumLiteral,
};
```

**K**: ⚠️ Partially shown, needs complete documentation

**Status**: **INCOMPLETE** - Need full @typeInfo documentation

---

### 22. Generic Return Types Based on Arguments

**Zig**:
```zig
fn ReturnType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Int => f64,
        .Float => i64,
        else => T,
    };
}

fn convert(comptime T: type, value: T) ReturnType(T) {
    // Return type depends on input type
}
```

**K**: ⚠️ Should work but not documented
```k
fn ReturnType(comptime T: type) type {
    return match (@typeInfo(T)) {
        .Int => f64,
        .Float => i64,
        else => T,
    };
}
```

**Status**: **UNCLEAR** - Need documentation

---

### 23. @setEvalBranchQuota() - Control Compile-time Execution Limits

**Zig**:
```zig
comptime {
    @setEvalBranchQuota(10000); // Allow more compile-time branches
}
```

**K**: ❌ Not documented

**Status**: **MISSING** - Needed for complex comptime computation

---

### 24. @call() - Modify Function Call Behavior

**Zig**:
```zig
const result = @call(.{}, myFunction, .{arg1, arg2});
```

**K**: ❌ Not documented

**Status**: **MISSING** - Advanced feature

---

## Comparison Matrix

| Feature | Zig | K | Status | Priority |
|---------|-----|---|--------|----------|
| **comptime parameters** | ✅ | ✅ | Complete | - |
| **comptime variables** | ✅ | ❌ | Missing | HIGH |
| **comptime blocks** | ✅ | ⚠️ | Partial | HIGH |
| **@typeInfo()** | ✅ | ✅ | Complete | - |
| **@compileError()** | ✅ | ✅ | Complete | - |
| **@compileLog()** | ✅ | ❌ | Missing | MEDIUM |
| **inline for** | ✅ | ❌ | Missing | HIGH |
| **inline while** | ✅ | ❌ | Missing | MEDIUM |
| **@Type()** | ✅ | ❌ | Missing | LOW |
| **@field()** | ✅ | ❌ | Missing | MEDIUM |
| **@hasField()/@hasDecl()** | ✅ | ❌ | Missing | HIGH |
| **@sizeOf()/@alignOf()/@offsetOf()** | ✅ | ❌ | Missing | HIGH |
| **@bitSizeOf()/@bitOffsetOf()** | ✅ | ❌ | Missing | LOW |
| **comptime function calls** | ✅ | ⚠️ | Unclear | HIGH |
| **@as()** | ✅ | ❌ | Missing | MEDIUM |
| **@import()** | ✅ | ✅ | Complete | - |
| **@embedFile()** | ✅ | ❌ | Missing | MEDIUM |
| **@This()** | ✅ | ✅ | Complete | - |
| **@typeName()** | ✅ | ❌ | Missing | MEDIUM |
| **@setEvalBranchQuota()** | ✅ | ❌ | Missing | LOW |
| **@fieldParentPtr()** | ✅ | ❌ | Missing | LOW |
| **Generic return types** | ✅ | ⚠️ | Unclear | HIGH |

## Critical Missing Features

### 1. Comptime Variables (HIGH PRIORITY)

**Problem**: Cannot define compile-time mutable state

**Example Need**:
```k
// Want: Generate array of sizes at compile time
comptime var sizes: [10]usize = undefined;
comptime for (0..10) |i| {
    sizes[i] = @sizeOf(i32) * (i + 1);
}
```

**Impact**: Limits metaprogramming capabilities

---

### 2. Inline For Loops (HIGH PRIORITY)

**Problem**: Cannot unroll loops at compile time

**Example Need**:
```k
// Want: Generate function for multiple types
fn printSizes() void {
    inline for ([_]type{ i8, i16, i32, i64 }) |T| {
        std.debug.print("{}: {}\n", .{ @typeName(T), @sizeOf(T) });
    }
}
```

**Impact**: Essential for code generation patterns

---

### 3. @hasField() and @hasDecl() (HIGH PRIORITY)

**Problem**: Cannot check if type has field/declaration

**Example Need**:
```k
fn requiresInit(comptime T: type) void {
    comptime {
        if (!@hasDecl(T, "init")) {
            @compileError("Type must have init() method");
        }
    }
}
```

**Impact**: Critical for duck typing and generic constraints

---

### 4. @sizeOf(), @alignOf(), @offsetOf() (HIGH PRIORITY)

**Problem**: Cannot query type layout at compile time

**Example Need**:
```k
fn allocateAligned(comptime T: type, allocator: Allocator) !*T {
    const alignment = @alignOf(T);
    const size = @sizeOf(T);
    return try allocator.allocWithAlignment(T, size, alignment);
}
```

**Impact**: Essential for FFI, allocators, and low-level code

---

### 5. Standalone Comptime Blocks (HIGH PRIORITY)

**Problem**: Comptime blocks only work in constraints, not as standalone

**Example Need**:
```k
// Want: Compute constants at compile time
const lookup_table = comptime {
    var table: [256]u8 = undefined;
    for (0..256) |i| {
        table[i] = compute_crc(i);
    }
    return table;
};
```

**Impact**: Needed for precomputed tables, optimizations

---

## Medium Priority Features

### 6. @embedFile() (MEDIUM)

**Use Case**: Embed shaders, configs, assets

```k
const vertex_shader = @embedFile("shaders/vertex.glsl");
const fragment_shader = @embedFile("shaders/fragment.glsl");
```

---

### 7. @typeName() (MEDIUM)

**Use Case**: Debugging, error messages

```k
fn debug_print(comptime T: type, value: T) void {
    std.debug.print("{s}: {any}\n", .{ @typeName(T), value });
}
```

---

### 8. @field() (MEDIUM)

**Use Case**: Generic field access

```k
fn getField(value: anytype, comptime field_name: []const u8) @TypeOf(@field(value, field_name)) {
    return @field(value, field_name);
}
```

---

### 9. @compileLog() (MEDIUM)

**Use Case**: Debugging compile-time code

```k
comptime {
    @compileLog("Processing type: ", T);
    @compileLog("Size: ", @sizeOf(T));
}
```

---

## Low Priority Features

### 10. @Type() (LOW)

**Use Case**: Advanced type-level programming

```k
const MyInt = @Type(.{
    .Int = .{ .signedness = .signed, .bits = 47 }
});
```

**Note**: Complex feature, only needed for advanced metaprogramming

---

### 11. @fieldParentPtr() (LOW)

**Use Case**: Intrusive data structures

**Note**: Niche use case, can be deferred

---

## K-Specific Enhancements

K has features Zig doesn't:

### 1. Traits + Comptime (K > Zig)

**K**:
```k
fn process(comptime T: type, value: T) void
    where T: Display + Debug
{
    // Best of both worlds: comptime + trait bounds
}
```

**Zig**: No traits, only comptime duck typing

---

### 2. Higher-Kinded Types (K > Zig)

**K**:
```k
trait Functor(F: type -> type) {
    fn map(comptime A: type, comptime B: type, self: F(A), f: fn(A) B) F(B);
}
```

**Zig**: No HKT support

---

### 3. Associated Types (K > Zig)

**K**:
```k
trait Iterator {
    type Item;  // Associated type
    fn next(self: &mut Self) ?Self.Item;
}
```

**Zig**: No associated types

---

## Recommendations

### Phase 1: Critical Features (Immediate)

1. **Document existing comptime capabilities**
   - comptime parameters ✅
   - @typeInfo() ✅
   - @compileError() ✅
   - Clarify what already works

2. **Add missing core builtins**:
   - `@sizeOf(T)` - type size in bytes
   - `@alignOf(T)` - type alignment
   - `@offsetOf(T, field)` - field offset
   - `@hasField(T, "field")` - check field existence
   - `@hasDecl(T, "decl")` - check declaration existence
   - `@typeName(T)` - get type name string

3. **Implement inline for loops**:
   ```k
   inline for (array) |item| {
       // Unrolled at compile time
   }
   ```

4. **Implement comptime variables**:
   ```k
   comptime var counter: usize = 0;
   ```

5. **Implement standalone comptime blocks**:
   ```k
   const table = comptime {
       var data: [100]u8 = undefined;
       // ... compute
       return data;
   };
   ```

### Phase 2: Medium Priority (Near-term)

1. **@embedFile()** - embed file contents
2. **@field()** - dynamic field access
3. **@compileLog()** - debug comptime code
4. **inline while** - unroll while loops
5. **@as()** - explicit type coercion

### Phase 3: Low Priority (Future)

1. **@Type()** - construct types at compile time
2. **@fieldParentPtr()** - intrusive containers
3. **@bitSizeOf()/@bitOffsetOf()** - packed struct support
4. **@setEvalBranchQuota()** - control limits

### Phase 4: Documentation

Create comprehensive comptime documentation:

1. **design/comptime-programming.md** - Complete guide
2. **spec/comptime-reference.md** - Builtin reference
3. **examples/comptime_examples.k** - Real-world examples

## Conclusion

**Current State**:
- K has basic comptime support (parameters, @typeInfo, constraints)
- Missing critical builtins (@sizeOf, @hasField, etc.)
- Missing inline loops (critical for metaprogramming)
- No standalone comptime blocks

**Strengths**:
- ✅ K has traits + comptime (better than Zig)
- ✅ K has HKT (better than Zig)
- ✅ K has associated types (better than Zig)

**Gaps to Fill**:
- ❌ Need @sizeOf, @alignOf, @offsetOf
- ❌ Need @hasField, @hasDecl
- ❌ Need inline for/while
- ❌ Need comptime variables
- ❌ Need standalone comptime blocks

**Priority**: HIGH - These features are essential for systems programming and compete with Zig's strengths.

**Action**: Implement Phase 1 features immediately to reach feature parity with Zig while maintaining K's advantages (traits, HKT).
