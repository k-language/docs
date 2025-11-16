# Kind System Design for K Language

## Problem Statement

**Question**: How do we represent arbitrarily complex kinds like `((type, u8) -> type) -> ((type, u8) -> type)`?

Currently, K supports:
- ✅ `type -> type` (Functor)
- ✅ `(type, type) -> type` (Bifunctor)

But what about:
- ❓ `(type -> type) -> (type -> type)` (Monad transformers)
- ❓ `((type, u8) -> type) -> ((type, u8) -> type)` (Indexed transformers)
- ❓ Arbitrary nesting of kinds

## Background: What Are Kinds?

In type theory, **kinds** are the "types of types":

| Term | Type | Kind | Sort |
|------|------|------|------|
| `42` | `i32` | `type` | - |
| `i32` | `type` | `*` (kind) | □ |
| `Option` | `type -> type` | `* -> *` | □ |
| `Result` | `(type, type) -> type` | `* -> * -> *` | □ |
| `Functor` | `(type -> type) -> Constraint` | `(* -> *) -> Constraint` | □ |

**Haskell notation**:
- `*` = concrete type (i32, String, etc.)
- `* -> *` = unary type constructor (Option, Vec, etc.)
- `* -> * -> *` = binary type constructor (Result, HashMap, etc.)
- `(* -> *) -> (* -> *)` = type constructor transformer (monad transformers)

**K notation** (current):
- `type` = concrete type
- `type -> type` = unary type constructor
- `(type, type) -> type` = binary type constructor
- `(type -> type) -> (type -> type)` = ❓ **Not defined**

## Current State in K

### What Works

```k
// Simple kinds
trait Functor(F: type -> type) {
    fn map(comptime A: type, comptime B: type, self: F(A), f: fn(A) B) F(B);
}

// Multi-parameter kinds
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
```

### What Doesn't Work (Yet)

```k
// Higher-order kinds - NOT DEFINED
trait MonadTrans(T: (type -> type) -> (type -> type)) {
    fn lift(comptime M: type -> type, comptime A: type, m: M(A)) T(M)(A);
}

// Mixed kinds - NOT DEFINED
trait IndexedTrans(T: ((type, u8) -> type) -> ((type, u8) -> type)) {
    // ...
}
```

## Proposed Design

### Option 1: Explicit Kind Annotations (Haskell-like)

**Syntax**: Use explicit kind signatures

```k
// Define kind aliases
const Kind = enum {
    Type,                           // *
    Arrow: struct {                 // * -> *
        param: Kind,
        result: Kind,
    },
    Tuple: []const Kind,            // (*, *)
};

// Explicit kind annotation
trait MonadTrans(T: (type -> type) -> (type -> type)) {
    fn lift(comptime M: type -> type, comptime A: type, m: M(A)) T(M)(A);
}

// More complex
trait IndexedMonadTrans(T: ((type, u8) -> type) -> ((type, u8) -> type)) {
    fn ilift(
        comptime M: (type, u8) -> type,
        comptime A: type,
        comptime i: u8,
        m: M(A, i)
    ) T(M)(A, i);
}
```

**Pros**:
- ✅ Explicit and clear
- ✅ Direct translation from Haskell
- ✅ Type checker can verify kinds

**Cons**:
- ❌ Verbose
- ❌ Requires understanding of kind system

---

### Option 2: Kind Inference (Scala-like)

**Syntax**: Let compiler infer kinds from usage

```k
// Compiler infers kind from usage
trait MonadTrans(comptime T) {
    fn lift(comptime M, comptime A: type, m: M(A)) T(M)(A);
    //            ↑ Compiler infers M: type -> type from M(A)
}

// Usage determines kind
impl MonadTrans(StateT) for StateT {
    fn lift(comptime M, comptime A: type, m: M(A)) StateT(M)(A) {
        // ...
    }
}
```

**Pros**:
- ✅ Concise
- ✅ Less annotation burden
- ✅ Familiar to users (like Rust's generics)

**Cons**:
- ❌ Less explicit
- ❌ Harder to debug when inference fails
- ❌ Requires sophisticated inference algorithm

---

### Option 3: Kind Aliases (Pragmatic)

**Syntax**: Define kind aliases for common patterns

```k
// Predefine common kind patterns
const TypeCtor = type -> type;                                  // * -> *
const TypeCtor2 = (type, type) -> type;                         // * -> * -> *
const TypeCtorTrans = TypeCtor -> TypeCtor;                     // (* -> *) -> (* -> *)
const IndexedTypeCtor = (type, u8) -> type;                     // *, Nat -> *
const IndexedTypeCtorTrans = IndexedTypeCtor -> IndexedTypeCtor;// (*, Nat -> *) -> (*, Nat -> *)

// Use aliases in trait definitions
trait MonadTrans(T: TypeCtorTrans) {
    fn lift(comptime M: TypeCtor, comptime A: type, m: M(A)) T(M)(A);
}

trait IndexedMonadTrans(T: IndexedTypeCtorTrans) {
    fn ilift(
        comptime M: IndexedTypeCtor,
        comptime A: type,
        comptime i: u8,
        m: M(A, i)
    ) T(M)(A, i);
}
```

**Pros**:
- ✅ Readable
- ✅ Self-documenting
- ✅ Explicit but not verbose
- ✅ Easy to extend with new patterns

**Cons**:
- ❌ Requires defining aliases upfront
- ❌ May not cover all cases

---

### Option 4: Dependent Kinds (Full Power)

**Syntax**: First-class kinds with dependent types

```k
// Kind is a first-class type
const Kind: type = comptime {
    return enum {
        Type,
        Fun: struct { param: *Kind, result: *Kind },
    };
};

// Define kinds as values
const k_type: Kind = .Type;
const k_functor: Kind = .{ .Fun = .{ .param = k_type, .result = k_type } };
const k_monad_trans: Kind = .{
    .Fun = .{
        .param = k_functor,
        .result = k_functor,
    }
};

// Use kind values in traits
trait MonadTrans(comptime k: Kind, T: k) where k == k_monad_trans {
    // ...
}
```

**Pros**:
- ✅ Maximum expressiveness
- ✅ First-class kinds
- ✅ Can compute kinds at compile time

**Cons**:
- ❌ Very complex
- ❌ Steep learning curve
- ❌ Overkill for most use cases

---

## Recommended Approach: Hybrid System

**Combine Option 2 (Inference) + Option 3 (Aliases) for best UX**

### Phase 1: Kind Inference (Default)

For most cases, let the compiler infer kinds:

```k
trait MonadTrans(comptime T) {
    fn lift(comptime M, comptime A: type, m: M(A)) T(M)(A);
    // Compiler infers:
    // - M: type -> type (from M(A))
    // - T: (type -> type) -> (type -> type) (from T(M)(A))
}
```

**Inference rules**:
1. If `F(X)` appears, infer `F: type -> type`
2. If `F(X, Y)` appears, infer `F: (type, type) -> type`
3. If `F(M)(X)` where `M: type -> type`, infer `F: (type -> type) -> (type -> type)`
4. And so on...

### Phase 2: Kind Aliases (Explicit when needed)

Provide aliases for complex kinds:

```k
// Standard library provides common kind aliases
const std.kinds = struct {
    const TypeCtor = type -> type;
    const TypeCtor2 = (type, type) -> type;
    const TypeCtorTrans = TypeCtor -> TypeCtor;

    // For indexed types
    const IxTypeCtor = (type, comptime_int) -> type;
    const IxTypeCtorTrans = IxTypeCtor -> IxTypeCtor;

    // For effect systems
    const Effect = (type, type) -> type;  // (Input, Output) -> Computation
};

// Use when inference is insufficient or for documentation
trait MonadTrans(T: std.kinds.TypeCtorTrans) {
    fn lift(comptime M: std.kinds.TypeCtor, comptime A: type, m: M(A)) T(M)(A);
}
```

### Phase 3: Explicit Kinds (Advanced)

For very complex cases, allow explicit kind syntax:

```k
// Explicit kind for clarity or when inference fails
trait ComplexTrait(T: ((type, u8) -> type) -> ((type, u8) -> type)) {
    // Explicit kind annotation
}
```

---

## Real-World Examples

### Example 1: StateT Monad Transformer

```k
// StateT: (type -> type) -> type -> type -> type
fn StateT(comptime M: type -> type) type {
    return fn(comptime S: type) type {
        return fn(comptime A: type) type {
            return struct {
                run_state: fn(S) M((A, S)),
            };
        };
    };
}

// MonadTrans for StateT
impl MonadTrans(StateT) for StateT {
    fn lift(comptime M: type -> type, comptime A: type, m: M(A)) StateT(M)(S)(A) {
        return StateT(M)(S)(A){
            .run_state = fn(s: S) M((A, S)) {
                return M.map(A, (A, S), m, fn(a: A) (A, S) {
                    return (a, s);
                });
            },
        };
    }
}
```

**Kind inference**:
- `M: type -> type` ✅ inferred from `M(A)`
- `StateT: (type -> type) -> type -> type -> type` ✅ inferred from usage

---

### Example 2: Indexed State Monad

```k
// IxStateT: (type -> type) -> type -> type -> type -> type
//           ^M             ^S      ^I      ^O      ^A
fn IxStateT(comptime M: type -> type) type {
    return fn(comptime S: type) type {
        return fn(comptime I: type) type {
            return fn(comptime O: type) type {
                return fn(comptime A: type) type {
                    return struct {
                        run_ix_state: fn(S) M((A, O)),
                    };
                };
            };
        };
    };
}

// This gets complex, so use alias:
const IxStateTKind = (
    std.kinds.TypeCtor ->  // M
    type ->                // S
    type ->                // I
    type ->                // O
    type ->                // A
    type
);
```

---

### Example 3: Free Monad

```k
// Free: (type -> type) -> type -> type
fn Free(comptime F: type -> type) type {
    return fn(comptime A: type) type {
        return enum {
            Pure: A,
            Free: F(Free(F)(A)),
        };
    };
}

// Compiler infers:
// F: type -> type (from F(X))
// Free: (type -> type) -> type -> type (from Free(F)(A))
```

---

## Comparison with Other Languages

| Language | Kind System | Explicit Kinds | Inference | Higher-Order Kinds |
|----------|-------------|----------------|-----------|-------------------|
| **Haskell** | ✅ Full | ✅ Yes | ✅ Yes | ✅ Yes |
| **Scala 3** | ✅ Full | ⚠️ Partial | ✅ Yes | ✅ Yes |
| **Rust** | ❌ No | ❌ No | ❌ No | ❌ No |
| **Zig** | ❌ No | ❌ No | ❌ No | ❌ No |
| **K (Proposed)** | ✅ Full | ✅ Yes | ✅ Yes | ✅ Yes |

**K's Advantage**:
- Better than Rust/Zig (they have no HKT at all)
- Competitive with Haskell/Scala 3
- Comptime + kinds = unique combination

---

## Syntax Summary

### Tier 1: Simple Kinds (Already Working)

```k
type                        // Concrete type (i32, String, etc.)
type -> type                // Unary type constructor (Option, Vec)
(type, type) -> type        // Binary type constructor (Result, HashMap)
```

### Tier 2: Higher-Order Kinds (Proposed)

```k
(type -> type) -> (type -> type)                    // Monad transformer
((type, u8) -> type) -> ((type, u8) -> type)        // Indexed transformer
(type -> type, type -> type) -> (type -> type)      // Product of functors
```

### Tier 3: Mixed Kinds (Advanced)

```k
(type, comptime_int) -> type                        // Indexed by compile-time value
((type, type) -> type, type) -> (type -> type)      // Partial application
```

---

## Implementation Strategy

### Phase 1: Document Current Capabilities (IMMEDIATE)

Document what already works:
- `type -> type`
- `(type, type) -> type`
- `(type, type, type) -> type`

### Phase 2: Add Kind Inference (HIGH PRIORITY)

Implement kind inference algorithm:
1. Collect kind constraints from usage
2. Solve constraints via unification
3. Report errors for unsolvable constraints

### Phase 3: Add Kind Aliases (MEDIUM PRIORITY)

Add standard library of kind aliases:
```k
const std.kinds = struct {
    const TypeCtor = type -> type;
    const TypeCtor2 = (type, type) -> type;
    const TypeCtorTrans = TypeCtor -> TypeCtor;
    // ... more
};
```

### Phase 4: Explicit Kind Syntax (LOW PRIORITY)

Allow explicit kind annotations when needed:
```k
trait Foo(T: ((type, u8) -> type) -> ((type, u8) -> type)) {
    // Explicit for complex cases
}
```

### Phase 5: First-Class Kinds (FUTURE)

Explore first-class kinds if demand exists:
```k
const Kind: type = /* ... */;
```

---

## Practical Guidelines

### When to Use Each Approach

**Use inference** (default):
```k
trait MonadTrans(comptime T) {
    fn lift(comptime M, comptime A: type, m: M(A)) T(M)(A);
}
```
- Most common case
- Compiler figures it out
- Concise and clean

**Use aliases** (for documentation):
```k
trait MonadTrans(T: std.kinds.TypeCtorTrans) {
    fn lift(comptime M: std.kinds.TypeCtor, comptime A: type, m: M(A)) T(M)(A);
}
```
- When kind is complex
- For public APIs
- Self-documenting code

**Use explicit kinds** (when inference fails):
```k
trait ComplexTrait(T: ((type, u8) -> type) -> ((type, u8) -> type)) {
    // Compiler can't infer this
}
```
- Rare cases
- Very complex kinds
- Edge cases in type system

---

## Error Messages

Good error messages are critical:

```k
trait Foo(T: type -> type) {
    fn bar(comptime A: type, x: T(A, i32)) void;
    //                         ^^^^^^^^
    //                         ERROR: Kind mismatch
}
```

**Error**:
```
error: kind mismatch in trait Foo
  --> src/main.k:42:36
   |
42 |     fn bar(comptime A: type, x: T(A, i32)) void;
   |                                    ^^^^^^^
   |
   = note: T has kind: type -> type
   = note: but is used with 2 arguments
   = help: did you mean T(A)?
   = help: or did you mean to declare T: (type, type) -> type?
```

---

## Infinite Kinds Problem

**Question**: How do we handle arbitrarily complex kinds?

**Answer**: Practical limit + inference

```k
// Practically limited by nesting depth
type -> type                                    // Depth 1
(type -> type) -> (type -> type)                // Depth 2
((type -> type) -> (type -> type)) -> (...)     // Depth 3
// ... up to reasonable limit (say, depth 10)
```

**Implementation**:
1. Compiler has max kind depth (e.g., 10)
2. Inference automatically figures out depth
3. Explicit annotation if you hit the limit
4. Error if you exceed the limit

**In practice**: Depth > 3 is extremely rare. Monad transformers are depth 2, which covers 99% of real-world use cases.

---

## Conclusion

### Current State

✅ **Working**: Simple kinds (`type -> type`, `(type, type) -> type`)
❌ **Missing**: Higher-order kinds, kind inference, kind aliases

### Proposed Solution

1. **Kind inference** (default) - compiler figures it out
2. **Kind aliases** (documentation) - `std.kinds.TypeCtorTrans`
3. **Explicit kinds** (edge cases) - `((type, u8) -> type) -> ...`

### Benefits

- ✅ Covers all practical use cases
- ✅ Inference makes common cases easy
- ✅ Aliases make complex cases readable
- ✅ Explicit syntax for full control
- ✅ Better than Rust/Zig (they have nothing)
- ✅ Competitive with Haskell/Scala 3

### Priority

**HIGH** - This is essential for advanced generic programming and library design.

**Action Items**:
1. Document current kind support
2. Design kind inference algorithm
3. Create `std.kinds` module with aliases
4. Implement explicit kind syntax
5. Write comprehensive examples (monad transformers, etc.)

With this system, K would have the **most powerful kind system** among systems programming languages!
