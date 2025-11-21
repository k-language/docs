# Type Reflection System in K

## Overview

This document describes K's type reflection capabilities, from compile-time introspection to user-implemented runtime reflection.

## Current Status Analysis

### ✅ What We Have

#### 1. @typeInfo() - Basic Type Introspection

**Status**: ✅ Documented and working

```k
fn analyze_type(comptime T: type) void {
    const info = @typeInfo(T);

    match (info) {
        .Int => |int_info| {
            std.debug.print("Int: {} bits\n", .{int_info.bits});
        },
        .Struct => |struct_info| {
            std.debug.print("Struct: {} fields\n", .{struct_info.fields.len});
        },
        .Enum => |enum_info| {
            std.debug.print("Enum: {} variants\n", .{enum_info.fields.len});
        },
        else => {},
    }
}
```

**What @typeInfo() returns**:
```k
const TypeInfo = enum {
    Type,
    Void,
    Bool,
    Int: struct {
        signedness: Signedness,
        bits: u16,
    },
    Float: struct {
        bits: u16,
    },
    Pointer: struct {
        // pointer details
    },
    Array: struct {
        len: usize,
        child: type,
    },
    Struct: struct {
        fields: []const FieldInfo,
        decls: []const DeclInfo,
        is_tuple: bool,
    },
    Enum: struct {
        fields: []const FieldInfo,
        tag_type: type,
        is_exhaustive: bool,
    },
    Union: struct {
        fields: []const FieldInfo,
        tag_type: ?type,
    },
    Fn: struct {
        params: []const ParamInfo,
        return_type: type,
        is_async: bool,
    },
    Optional: struct {
        child: type,
    },
    ErrorUnion: struct {
        error_set: type,
        payload: type,
    },
    // ... more variants
};
```

#### 2. Higher-Kinded Types (HKT)

**Status**: ✅ Documented and working

```k
// HKT: type -> type
trait Functor(F: type -> type) {
    fn map(
        comptime A: type,
        comptime B: type,
        self: F(A),
        f: fn(A) B,
    ) F(B);
}

// HKT: (type, type) -> type
trait Bifunctor(F: (type, type) -> type) {
    fn bimap(
        comptime A: type,
        comptime B: type,
        comptime C: type,
        comptime D: type,
        self: F(A, B),
        f: fn(A) C,
        g: fn(B) D,
    ) F(C, D);
}

// Usage
impl Functor(Option) for Option {
    fn map(comptime A: type, comptime B: type, self: ?A, f: fn(A) B) ?B {
        return if (self) |value| f(value) else null;
    }
}
```

**This is EXCELLENT** - K can represent type constructors as first-class values!

### ❌ What We're Missing (CRITICAL)

#### 1. @hasField() and @hasDecl() - Duck Typing Checks

**Status**: ❌ NOT documented

**Needed**:
```k
fn requiresXField(comptime T: type) void {
    comptime {
        if (!@hasField(T, "x")) {
            @compileError("Type must have field 'x'");
        }
    }
}

fn requiresInitMethod(comptime T: type) void {
    comptime {
        if (!@hasDecl(T, "init")) {
            @compileError("Type must have 'init' method");
        }
    }
}
```

**Why critical**: Essential for structural typing and duck typing checks.

---

#### 2. @field() - Dynamic Field Access

**Status**: ❌ NOT documented

**Needed**:
```k
fn getField(value: anytype, comptime field_name: []const u8) @TypeOf(@field(value, field_name)) {
    return @field(value, field_name);
}

fn setField(value: &mut anytype, comptime field_name: []const u8, new_value: anytype) void {
    @field(value, field_name) = new_value;
}

// Generic field iteration
fn printAllFields(comptime T: type, value: T) void {
    const info = @typeInfo(T).Struct;
    inline for (info.fields) |field| {
        const field_value = @field(value, field.name);
        std.debug.print("{s}: {any}\n", .{field.name, field_value});
    }
}
```

**Why critical**: Needed for generic serialization, deserialization, and metaprogramming.

---

#### 3. @fieldType() - Get Field Type

**Status**: ❌ NOT documented

**Needed**:
```k
fn getFieldType(comptime T: type, comptime field_name: []const u8) type {
    return @fieldType(T, field_name);
}

// Usage
const Point = struct { x: f32, y: f32 };
const XType = @fieldType(Point, "x"); // f32
```

---

#### 4. @Type() - Construct Types Programmatically

**Status**: ❌ NOT documented

**Needed**:
```k
fn makeIntType(comptime signedness: Signedness, comptime bits: u16) type {
    return @Type(.{
        .Int = .{
            .signedness = signedness,
            .bits = bits,
        },
    });
}

const i47 = makeIntType(.signed, 47); // Custom 47-bit signed integer!

// Generate struct at compile time
fn makeStruct(comptime fields: []const FieldDef) type {
    return @Type(.{
        .Struct = .{
            .fields = fields,
            .decls = &[_]DeclInfo{},
            .is_tuple = false,
        },
    });
}
```

**Why critical**: Essential for advanced metaprogramming and type-level computations.

---

#### 5. @unionInit() - Construct Union Values

**Status**: ❌ NOT documented

**Needed**:
```k
const MyUnion = union(enum) {
    Int: i32,
    Float: f64,
    String: []const u8,
};

fn createUnion(comptime tag: []const u8, value: anytype) MyUnion {
    return @unionInit(MyUnion, tag, value);
}

const x = createUnion("Int", 42);
const y = createUnion("Float", 3.14);
```

---

#### 6. @tagName() - Get Enum Tag Name

**Status**: ❌ NOT documented

**Needed**:
```k
const Color = enum { Red, Green, Blue };

fn printColor(color: Color) void {
    std.debug.print("Color: {s}\n", .{@tagName(color)});
}

printColor(.Red); // "Color: Red"
```

---

#### 7. @enumToInt() and @intToEnum() - Enum Conversions

**Status**: ❌ NOT documented

**Needed**:
```k
const Status = enum(u8) {
    Pending = 0,
    Running = 1,
    Complete = 2,
};

const status: Status = .Running;
const int_value = @enumToInt(status); // 1

const status2 = @intToEnum(Status, 2); // .Complete
```

---

## What You Asked About

### Question 1: "타입을 imperative하게 다룰 수 있게 하는 intrinsic operation 다 있는 거 맞지?"

**Answer**: ❌ **부분적으로만 있음**

**Currently have**:
- ✅ `@typeInfo(T)` - Read type information
- ✅ `@This()` - Get current type
- ✅ `@import()` - Load modules

**Missing (CRITICAL)**:
- ❌ `@hasField(T, "field")` - Check field existence
- ❌ `@hasDecl(T, "decl")` - Check declaration existence
- ❌ `@field(value, "field")` - Dynamic field access
- ❌ `@fieldType(T, "field")` - Get field type
- ❌ `@Type(type_info)` - Construct types
- ❌ `@unionInit(Union, "tag", value)` - Construct unions
- ❌ `@tagName(enum_value)` - Get enum tag name
- ❌ `@enumToInt(enum)` / `@intToEnum(T, int)` - Enum conversions

**Conclusion**: 기본적인 introspection은 있지만, **imperative하게 조작하는 기능들이 대부분 빠져있음**.

---

### Question 2: "HKT도 나타낼 수 있고?"

**Answer**: ✅ **YES!** HKT는 이미 지원됨

```k
// Type constructor as parameter
trait Functor(F: type -> type) {
    fn map(comptime A: type, comptime B: type, self: F(A), f: fn(A) B) F(B);
}

// Multi-parameter type constructor
trait Bifunctor(F: (type, type) -> type) {
    fn bimap(
        comptime A: type,
        comptime B: type,
        comptime C: type,
        comptime D: type,
        self: F(A, B),
        f: fn(A) C,
        g: fn(B) D,
    ) F(C, D);
}

// Implementation
impl Functor(Option) for Option { /* ... */ }
impl Bifunctor(Result) for Result { /* ... */ }
```

**This is a MAJOR advantage over Zig and even Rust!**

---

### Question 3: "컴파일 타임 리플렉션 비슷한 걸 구현할 수 있고?"

**Answer**: ⚠️ **부분적으로만 가능** (필요한 intrinsics 추가 필요)

**Currently possible**:
```k
// Read-only reflection via @typeInfo
fn analyzeStruct(comptime T: type) void {
    const info = @typeInfo(T);

    comptime {
        if (info != .Struct) {
            @compileError("Expected struct type");
        }

        for (info.Struct.fields) |field| {
            std.debug.print("Field: {s}, Type: {}\n", .{field.name, field.type});
        }
    }
}
```

**What we CANNOT do yet** (need missing intrinsics):
```k
// ❌ Cannot access fields dynamically
fn getAllFields(value: anytype) []FieldValue {
    const T = @TypeOf(value);
    const info = @typeInfo(T).Struct;

    var result: [info.fields.len]FieldValue = undefined;

    // ❌ MISSING: @field() to access dynamically
    inline for (info.fields, 0..) |field, i| {
        result[i] = .{
            .name = field.name,
            .value = @field(value, field.name), // ❌ NOT AVAILABLE
        };
    }

    return &result;
}

// ❌ Cannot construct types dynamically
fn makeType(comptime fields: []FieldDef) type {
    return @Type(.{ .Struct = /* ... */ }); // ❌ NOT AVAILABLE
}
```

**To make it fully work**, we need:
1. `@field()` for dynamic field access
2. `@Type()` for type construction
3. `@hasField()` for structural checks
4. `@unionInit()` for union construction

---

### Question 4: "그걸 기반으로 런타임 리플렉션을 유저가 쉽게 구현할 수 있고?"

**Answer**: ⚠️ **가능하지만 현재는 제한적** (intrinsics 추가 후 완벽히 가능)

**Strategy**: Compile-time reflection → Generate runtime metadata

#### Example: User-Implemented Runtime Reflection

```k
// Compile-time: Generate type metadata
const TypeMetadata = struct {
    name: []const u8,
    size: usize,
    align: usize,
    fields: []const FieldMetadata,
};

const FieldMetadata = struct {
    name: []const u8,
    type_name: []const u8,
    offset: usize,
    size: usize,
};

// Generate metadata at compile time
fn generateMetadata(comptime T: type) TypeMetadata {
    const info = @typeInfo(T).Struct;

    var fields: [info.fields.len]FieldMetadata = undefined;

    inline for (info.fields, 0..) |field, i| {
        fields[i] = .{
            .name = field.name,
            .type_name = @typeName(field.type), // ❌ NEED @typeName
            .offset = @offsetOf(T, field.name),  // ✅ Have this
            .size = @sizeOf(field.type),         // ✅ Have this
        };
    }

    return TypeMetadata{
        .name = @typeName(T), // ❌ NEED @typeName
        .size = @sizeOf(T),
        .align = @alignOf(T),
        .fields = &fields,
    };
}

// Usage: Store metadata in global const
const Point = struct { x: f32, y: f32 };
const point_meta = comptime generateMetadata(Point);

// Runtime: Use metadata
fn printType(ptr: *const anyopaque, meta: TypeMetadata) void {
    std.debug.print("Type: {s} ({} bytes)\n", .{meta.name, meta.size});

    for (meta.fields) |field| {
        std.debug.print("  {s}: {s} at offset {}\n",
            .{field.name, field.type_name, field.offset});
    }
}

// Runtime reflection!
const p = Point{ .x = 1.0, .y = 2.0 };
printType(&p, point_meta);
```

**What's needed to make this work**:
1. ✅ `@typeInfo()` - Already have
2. ✅ `@sizeOf()`, `@alignOf()`, `@offsetOf()` - Need to add (in comptime-comparison.md)
3. ❌ `@typeName()` - Need to add
4. ❌ `@field()` - Need for dynamic field access

---

#### More Advanced: Serialization via Reflection

```k
// Compile-time: Generate serializer
fn generateSerializer(comptime T: type) type {
    return struct {
        pub fn serialize(value: T, writer: anytype) !void {
            const info = @typeInfo(T).Struct;

            try writer.writeInt(usize, info.fields.len);

            inline for (info.fields) |field| {
                // Write field name
                try writer.writeAll(field.name);

                // Write field value (needs @field!)
                const field_value = @field(value, field.name); // ❌ NEED THIS
                try serializeValue(field_value, writer);
            }
        }

        pub fn deserialize(reader: anytype) !T {
            var result: T = undefined;

            const field_count = try reader.readInt(usize);
            if (field_count != info.fields.len) return error.InvalidFormat;

            inline for (info.fields) |field| {
                const name = try reader.readString();
                if (!std.mem.eql(u8, name, field.name)) return error.InvalidFormat;

                // Read field value (needs @field!)
                @field(result, field.name) = try deserializeValue(field.type, reader); // ❌ NEED THIS
            }

            return result;
        }
    };
}

// Usage
const PointSerializer = generateSerializer(Point);

const p = Point{ .x = 1.0, .y = 2.0 };
try PointSerializer.serialize(p, writer);

const p2 = try PointSerializer.deserialize(reader);
```

---

#### Runtime Type Registry

```k
// Compile-time: Build type registry
const TypeRegistry = struct {
    types: []const TypeMetadata,

    pub fn findByName(self: TypeRegistry, name: []const u8) ?TypeMetadata {
        for (self.types) |t| {
            if (std.mem.eql(u8, t.name, name)) return t;
        }
        return null;
    }
};

// Generate registry at compile time
fn buildRegistry(comptime types: []const type) TypeRegistry {
    var metadata: [types.len]TypeMetadata = undefined;

    inline for (types, 0..) |T, i| {
        metadata[i] = generateMetadata(T);
    }

    return TypeRegistry{ .types = &metadata };
}

// Usage
const registry = comptime buildRegistry(&[_]type{
    Point,
    Color,
    Player,
    // ... more types
});

// Runtime lookup
const maybe_meta = registry.findByName("Point");
if (maybe_meta) |meta| {
    std.debug.print("Found type: {s}\n", .{meta.name});
}
```

---

## Complete Intrinsics Needed

### Tier 1: Critical (Must Have)

| Intrinsic | Purpose | Priority |
|-----------|---------|----------|
| `@field(value, "name")` | Dynamic field access | **CRITICAL** |
| `@hasField(T, "name")` | Check field existence | **CRITICAL** |
| `@hasDecl(T, "name")` | Check declaration existence | **CRITICAL** |
| `@sizeOf(T)` | Type size | **CRITICAL** |
| `@alignOf(T)` | Type alignment | **CRITICAL** |
| `@offsetOf(T, "field")` | Field offset | **CRITICAL** |
| `@typeName(T)` | Get type name string | **CRITICAL** |

### Tier 2: Important (Should Have)

| Intrinsic | Purpose | Priority |
|-----------|---------|----------|
| `@Type(type_info)` | Construct types | HIGH |
| `@fieldType(T, "field")` | Get field type | HIGH |
| `@tagName(enum_value)` | Get enum tag name | HIGH |
| `@unionInit(U, "tag", val)` | Construct union | HIGH |
| `@enumToInt(enum)` | Enum to integer | MEDIUM |
| `@intToEnum(T, int)` | Integer to enum | MEDIUM |

### Tier 3: Nice to Have

| Intrinsic | Purpose | Priority |
|-----------|---------|----------|
| `@fieldParentPtr(T, "field", ptr)` | Container intrusion | LOW |
| `@bitSizeOf(T)` | Bit-level size | LOW |
| `@bitOffsetOf(T, "field")` | Bit-level offset | LOW |

---

## Implementation Roadmap

### Phase 1: Essential Intrinsics (IMMEDIATE)

Add these to enable basic compile-time reflection:

1. `@sizeOf(T)` - Already documented in comptime-comparison.md as needed
2. `@alignOf(T)` - Already documented
3. `@offsetOf(T, "field")` - Already documented
4. `@hasField(T, "field")` - Already documented
5. `@hasDecl(T, "decl")` - Already documented
6. `@typeName(T)` - Already documented

**Result**: Users can generate metadata tables at compile time.

---

### Phase 2: Dynamic Access (HIGH PRIORITY)

Add these to enable compile-time metaprogramming:

1. `@field(value, "name")` - **Most critical**
2. `@fieldType(T, "field")`
3. `@tagName(enum_value)`

**Result**: Users can write generic serializers, validators, etc.

---

### Phase 3: Type Construction (ADVANCED)

Add these for advanced metaprogramming:

1. `@Type(type_info)` - Construct types programmatically
2. `@unionInit(Union, "tag", value)`
3. `@enumToInt()` / `@intToEnum()`

**Result**: Full metaprogramming capabilities, DSL creation, etc.

---

## Real-World Use Cases

### 1. Serialization Framework

```k
// User writes:
const Player = struct {
    name: []const u8,
    health: i32,
    position: Point,
};

// Framework generates automatically:
const PlayerSerializer = comptime generateSerializer(Player);

// Usage:
const p = Player{ /* ... */ };
const json = try PlayerSerializer.toJson(p);
const p2 = try PlayerSerializer.fromJson(json);
```

### 2. ORM / Database Mapping

```k
const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
};

// Generate SQL at compile time
const UserTable = comptime generateTable(User, .{
    .table_name = "users",
    .primary_key = "id",
});

// Usage:
const users = try UserTable.select(db, .{ .where = "email = ?", .args = .{email} });
```

### 3. Validation Framework

```k
const CreateUserRequest = struct {
    name: []const u8,
    email: []const u8,
    age: u32,
};

const validator = comptime generateValidator(CreateUserRequest, .{
    .name = .{ .min_len = 1, .max_len = 100 },
    .email = .{ .format = .email },
    .age = .{ .min = 13, .max = 120 },
});

// Usage:
const request = /* ... */;
try validator.validate(request);
```

### 4. RPC Framework

```k
const MathService = struct {
    pub fn add(a: i32, b: i32) i32 {
        return a + b;
    }

    pub fn multiply(a: i32, b: i32) i32 {
        return a * b;
    }
};

// Generate RPC server/client at compile time
const server = comptime generateRpcServer(MathService);
const client = comptime generateRpcClient(MathService);

// Server:
try server.serve(MathService{}, port);

// Client:
const result = try client.add(5, 3); // Remote call!
```

### 5. GUI Property Inspector

```k
// Runtime reflection for property editors
fn createPropertyInspector(comptime T: type) PropertyInspector {
    const meta = comptime generateMetadata(T);

    return PropertyInspector{
        .metadata = meta,
        .getValue = generateGetter(T),
        .setValue = generateSetter(T),
    };
}

// Usage in editor:
const inspector = createPropertyInspector(Player);
inspector.render(player_instance, ui);
```

---

## Comparison: K vs Others

| Feature | Rust | Zig | K (Current) | K (With Intrinsics) |
|---------|------|-----|-------------|---------------------|
| **Compile-time reflection** | ❌ No | ✅ Yes | ⚠️ Partial | ✅ Yes |
| **Runtime reflection** | ⚠️ Limited (derive macros) | ❌ No | ❌ No | ✅ User-impl |
| **HKT** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Type construction** | ❌ No | ✅ @Type | ❌ No | ✅ Yes |
| **Dynamic field access** | ❌ No | ✅ @field | ❌ No | ✅ Yes |
| **Type introspection** | ⚠️ Via macros | ✅ @typeInfo | ✅ Yes | ✅ Yes |
| **Trait-based generics** | ✅ Yes | ❌ No | ✅ Yes | ✅ Yes |

**K's Advantage**: HKT + Traits + Compile-time reflection = **Most powerful metaprogramming**

---

## Conclusion

### Current State

**What works**:
- ✅ `@typeInfo()` for type introspection
- ✅ HKT for type-level programming (MAJOR advantage!)
- ✅ Pattern matching on type info

**What's missing** (CRITICAL):
- ❌ `@field()` - Cannot access fields dynamically
- ❌ `@hasField()`/`@hasDecl()` - Cannot check structure
- ❌ `@sizeOf()`/`@alignOf()`/`@offsetOf()` - Cannot query layout
- ❌ `@typeName()` - Cannot get type names
- ❌ `@Type()` - Cannot construct types

### After Adding Intrinsics

With the missing intrinsics, K would have:

1. **Compile-time reflection**: Full access to type structure
2. **Runtime reflection**: Users can generate metadata at compile time
3. **HKT**: Type-level programming (already have!)
4. **Zero-cost**: All metadata generated at compile time
5. **Type-safe**: Compiler verifies all reflection code

**Result**: K would have the **most powerful** metaprogramming system among systems languages:
- **Better than Rust**: No macros needed, full compile-time reflection
- **Better than Zig**: HKT + Traits + same compile-time power
- **Better than C++**: No template error hell, clean syntax

### Recommendation

**Priority**: **CRITICAL**

Implement Phase 1 intrinsics immediately:
1. `@sizeOf()`, `@alignOf()`, `@offsetOf()`
2. `@hasField()`, `@hasDecl()`
3. `@field()`
4. `@typeName()`

This would enable:
- ✅ Serialization frameworks
- ✅ ORMs and database mappers
- ✅ Validation frameworks
- ✅ RPC frameworks
- ✅ Property inspectors
- ✅ User-implemented runtime reflection

**Impact**: Would make K the **best systems language for metaprogramming** while maintaining zero-cost abstractions!
