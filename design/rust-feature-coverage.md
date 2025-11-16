# Rust Feature Coverage Analysis

## Overview

This document analyzes how K Language covers Rust's core features, identifying what works well, what needs clarification, and what might be missing.

## Feature Comparison Matrix

| Rust Feature | K Support | Status | Notes |
|--------------|-----------|--------|-------|
| **Ownership & Borrowing** | ✅ Full | Complete | Same rules as Rust |
| **Lifetimes** | ✅ Full | Complete | Explicit when needed, inference |
| **Traits** | ✅ Full | Complete | Similar to Rust traits |
| **Pattern Matching** | ✅ Full | Complete | `match` with exhaustiveness |
| **Error Handling** | ✅ Enhanced | Complete | `!T` sugar + Result<T, E> |
| **Smart Pointers** | ⚠️ Partial | Needs Review | Arc/Rc defined, Box missing? |
| **Iterators** | ❌ Missing | TODO | No iterator trait defined |
| **Closures** | ❌ Missing | TODO | Not documented |
| **Async/Await** | ✅ Full | Complete | Library-based runtime |
| **Generics** | ✅ Enhanced | Complete | comptime + traits |
| **Associated Types** | ❓ Unclear | Needs Clarification | Not explicitly documented |
| **Impl Blocks** | ❓ Unclear | Needs Clarification | Syntax not clear |
| **Enums with Data** | ✅ Full | Complete | Tagged unions |
| **Deref Coercion** | ❌ Missing | TODO | Not documented |
| **Drop/RAII** | ✅ Enhanced | Complete | Drop + defer + nodrop |
| **Module System** | ✅ Full | Complete | File-based + visibility |
| **Macros** | ⚠️ Partial | Needs Review | comptime, but no macro syntax |
| **Send/Sync** | ✅ Full | Complete | Same as Rust |
| **Interior Mutability** | ✅ Full | Complete | Cell/RefCell defined |
| **Zero-Cost Abstractions** | ✅ Full | Complete | comptime + monomorphization |

## Critical Missing Features

### 1. Iterators ❌

**Problem**: No iterator trait or for-in loop semantics defined.

**Rust**:
```rust
trait Iterator {
    type Item;
    fn next(&mut self) -> Option<Self::Item>;
}

for item in collection {
    // ...
}
```

**K - Current**:
```k
// Only C-style loops documented
for (items) |item| {  // What trait does this use?
    process(item);
}
```

**Needed**:
```k
trait Iterator {
    type Item;
    fn next(self: &mut Self) ?Self.Item;
}

// for-in desugars to:
// while (iter.next()) |item| { ... }
```

**Impact**: HIGH - Iterators are fundamental to Rust ergonomics.

### 2. Closures ❌

**Problem**: No closure syntax or Fn/FnMut/FnOnce traits defined.

**Rust**:
```rust
let add = |x, y| x + y;
let mut acc = 0;
items.iter().for_each(|x| acc += x);
```

**K - Missing**:
```k
// How to write closures?
const add = fn(x: i32, y: i32) i32 { return x + y; };  // Function pointer only?

// How to capture environment?
var acc: i32 = 0;
items.iter().for_each(???);  // No closure syntax
```

**Needed**:
```k
// Closure syntax
const add = |x: i32, y: i32| -> i32 { x + y };

// Closure traits
trait Fn(Args) -> Output {
    fn call(self: &Self, args: Args) Output;
}

trait FnMut(Args) -> Output {
    fn call_mut(self: &mut Self, args: Args) Output;
}

trait FnOnce(Args) -> Output {
    fn call_once(self: Self, args: Args) Output;
}
```

**Impact**: HIGH - Closures are essential for functional patterns.

### 3. Box<T> (Heap Allocation) ⚠️

**Problem**: Arc/Rc documented, but not Box (unique owned heap pointer).

**Rust**:
```rust
let boxed: Box<i32> = Box::new(42);
```

**K - Missing**:
```k
// How to allocate single value on heap?
const allocator = get_allocator();
const ptr = try allocator.create(i32);  // Raw pointer, must free manually
defer allocator.destroy(ptr);

// Need Box for ownership transfer
```

**Needed**:
```k
const Box = struct(comptime T: type) {
    ptr: *mut T,
    allocator: Allocator,

    pub fn init(allocator: Allocator, value: T) !Box(T) {
        const ptr = try allocator.create(T);
        ptr.* = value;
        return Box(T){ .ptr = ptr, .allocator = allocator };
    }

    pub fn drop(self: &mut Box(T)) void {
        self.allocator.destroy(self.ptr);
    }
};

// Send+Sync bounds
impl Send for Box(T) where T: Send {}
impl Sync for Box(T) where T: Sync {}
```

**Impact**: MEDIUM - Box is common for recursive types and trait objects.

### 4. Deref Coercion ❌

**Problem**: No automatic deref for smart pointers.

**Rust**:
```rust
let boxed = Box::new(String::from("hello"));
let len = boxed.len();  // Auto-deref: Box<String> -> &String
```

**K - Missing**:
```k
const boxed = try Box.init(allocator, my_string);
const len = boxed.len();  // ERROR: Box has no len() method

// Must manually deref?
const len = boxed.ptr.*.len();  // Verbose
```

**Needed**:
```k
trait Deref {
    type Target;
    fn deref(self: &Self) &Self.Target;
}

impl Deref for Box(T) {
    type Target = T;
    fn deref(self: &Box(T)) &T {
        return self.ptr;
    }
}

// Compiler auto-inserts deref calls
const len = boxed.len();  // Desugars to: boxed.deref().len()
```

**Impact**: MEDIUM - Convenience feature, not critical for safety.

## Unclear Features (Need Clarification)

### 5. Associated Types ❓

**Current**:
```k
trait Iterator {
    type Item;  // Is this supported?
    fn next(self: &mut Self) ?Self.Item;
}
```

**Question**: Are associated types (`type Item`) supported, or only associated functions?

**If not supported**, need to use generics:
```k
trait Iterator(comptime T: type) {
    fn next(self: &mut Self) ?T;
}
```

**Recommendation**: Document associated type support explicitly.

### 6. Impl Blocks ❓

**Rust**:
```rust
impl MyType {
    fn new() -> Self { ... }
}

impl TraitName for MyType {
    fn method(&self) { ... }
}
```

**K - Current**:
```k
const MyType = struct {
    pub fn new() MyType { ... }  // Methods inside struct
};

impl TraitName for MyType {
    fn method(self: &MyType) void { ... }  // Separate impl block
}
```

**Questions**:
1. Can we have `impl MyType` blocks separate from struct definition?
2. Can we have multiple impl blocks for the same type?
3. Can we have generic impl blocks?

```k
// Is this allowed?
impl MyType {
    pub fn helper() void { ... }
}

// Generic impl?
impl Vec(T) where T: Display {
    pub fn print_all(self: &Vec(T)) void { ... }
}
```

**Recommendation**: Clarify impl block rules and scope.

### 7. Macro System ⚠️

**Rust**: Powerful macro system with `macro_rules!` and proc macros.

**K**: Has `comptime` for compile-time execution, but no macro syntax.

**Questions**:
1. Can comptime replace macros entirely?
2. Is there a declarative macro syntax?
3. Is there procedural macro support?

**Example Need**:
```k
// Rust: derive macros
#[derive(Debug, Clone, PartialEq)]
struct Point { x: i32, y: i32 }

// K: How to implement?
// Option 1: comptime functions
@derive(Debug, Clone, PartialEq)
const Point = struct { x: i32, y: i32 };

// Option 2: explicit impl
impl Debug for Point { ... }
impl Clone for Point { ... }
impl PartialEq for Point { ... }
```

**Recommendation**: Document comptime metaprogramming capabilities vs Rust macros.

## Features Needing Enhancement

### 8. String Type

**Problem**: No string type defined in documentation.

**Needed**:
```k
// String type (heap-allocated, growable)
const String = struct {
    bytes: Vec(u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) String { ... }
    pub fn from(allocator: Allocator, s: []const u8) !String { ... }
};

// String slice (borrowed)
// Already have: []const u8

// String literal type
const literal: []const u8 = "hello";  // Static lifetime
```

**Impact**: MEDIUM - Basic type needed for examples.

### 9. Vec<T> (Growable Array)

**Problem**: ArrayList mentioned in examples, but not formally defined.

**Needed in std-library-types.md**:
```k
const Vec = struct(comptime T: type) {
    items: []T,
    len: usize,
    capacity: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator) Vec(T) { ... }
    pub fn push(self: &mut Vec(T), item: T) !void { ... }
    pub fn pop(self: &mut Vec(T)) ?T { ... }

    pub fn drop(self: &mut Vec(T)) void {
        self.allocator.free(self.items);
    }
};

// Send+Sync bounds
impl Send for Vec(T) where T: Send {}
impl Sync for Vec(T) where T: Sync {}
```

**Impact**: MEDIUM - Fundamental collection type.

### 10. HashMap/HashSet

**Problem**: No hash-based collections defined.

**Needed**:
```k
const HashMap = struct(comptime K: type, comptime V: type) {
    // Implementation

    pub fn insert(self: &mut HashMap(K, V), key: K, value: V) !?V { ... }
    pub fn get(self: &HashMap(K, V), key: &K) ?&V { ... }
};

// Requires:
trait Hash {
    fn hash(self: &Self, hasher: &mut Hasher) void;
}

trait Eq {
    fn eq(self: &Self, other: &Self) bool;
}
```

**Impact**: MEDIUM - Common collection type.

## Features Working Well ✅

### 11. Ownership & Borrowing ✅

**Status**: Fully documented and consistent with Rust.

- Single owner
- Multiple immutable OR single mutable borrow
- Lifetimes with inference
- Non-lexical lifetimes (NLL)

**Example**:
```k
fn example() void {
    var data: [100]u8 = undefined;

    const ref1 = &data;  // Immutable borrow
    const ref2 = &data;  // OK: multiple immutable
    read(ref1);
    read(ref2);

    const mut_ref = &mut data;  // Mutable borrow
    write(mut_ref);  // OK: exclusive access
}
```

### 12. Send/Sync Traits ✅

**Status**: Fully defined with correct semantics.

```k
trait Send {}  // Can move between threads
trait Sync {}  // Can share &T between threads

// Arc bounds (correct)
impl Send for Arc(T) where T: Send + Sync {}
impl Sync for Arc(T) where T: Send + Sync {}

// Mutex bounds (correct)
impl Send for Mutex(T) where T: Send {}
impl Sync for Mutex(T) where T: Send {}
```

### 13. Pattern Matching ✅

**Status**: Full support with exhaustiveness checking.

```k
match (value) {
    .Ok => |v| process(v),
    .Err => |e| handle(e),
}

// if let
if (maybe) |value| {
    use(value);
}

// while let
while (iter.next()) |item| {
    process(item);
}
```

### 14. Defer System ✅

**Status**: Enhanced beyond Rust with pattern-based and labelled defer.

```k
defer cleanup();                  // Always
defer on .Err cleanup();          // Conditional
defer :label cleanup();           // Block-scoped
defer :label on .Err cleanup();   // Both
```

**Better than Rust**: Block-scoped cleanup without extra RAII types.

## Recommendations

### Priority 1 (Critical)

1. **Define Iterator trait** - Fundamental for for-loops
2. **Define Closure syntax and Fn traits** - Essential for functional patterns
3. **Clarify associated types** - Needed for trait design

### Priority 2 (Important)

4. **Document Box<T>** - Standard heap allocation
5. **Define Vec<T> formally** - Core collection
6. **Document impl block rules** - Clarify syntax and scoping
7. **String type** - Basic string handling

### Priority 3 (Nice to have)

8. **Deref trait and coercion** - Convenience
9. **HashMap/HashSet** - Common collections
10. **Macro/comptime capabilities** - Metaprogramming clarity

## Summary

**Strong Areas** ✅:
- Ownership, borrowing, lifetimes
- Send/Sync trait system
- Pattern matching
- Defer system (enhanced)
- Type sugar system
- Async/await

**Gaps** ❌:
- Iterator trait
- Closures (syntax + traits)
- Deref coercion

**Needs Clarification** ❓:
- Associated types
- Impl block rules
- Comptime vs macros

**Missing Standard Library** ⚠️:
- Box<T>
- Vec<T> (formal definition)
- String
- HashMap/HashSet

## Conclusion

K Language covers most of Rust's safety features well, with some enhancements (defer system, type sugar). The main gaps are:

1. **Functional programming features**: Iterators, closures
2. **Standard library types**: Box, Vec, String, HashMap
3. **Documentation clarity**: Associated types, impl blocks, comptime

These are solvable and don't represent fundamental design issues. The core safety model (ownership, borrowing, Send/Sync) is solid.
