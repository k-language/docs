# Type Inference Strategy in K

## Problem Statement

**Question**: HKT를 지원하면서 HM (Hindley-Milner) 기반 타입 추론이 가능한가?

**Short Answer**: **HKT만 있으면 가능**, **하지만 traits (ad-hoc polymorphism) 추가하면 불가능**

## Background: Hindley-Milner Type Inference

### What HM Can Do

**HM type inference** is:
- ✅ **Complete**: If a type exists, it will be found
- ✅ **Principal**: The most general type is inferred
- ✅ **Decidable**: Algorithm always terminates

**HM works for**:
```k
// Parametric polymorphism - HM can infer this!
fn id(x) { return x; }  // Inferred: fn(comptime T: type, x: T) T

fn map(f, list) {
    // Inferred: fn(comptime A: type, comptime B: type, f: fn(A) B, list: []A) []B
    var result = [];
    for (list) |item| {
        result.append(f(item));
    }
    return result;
}
```

**Why it works**:
- Only parametric polymorphism (generics)
- No overloading
- No type classes/traits
- Type variables are unconstrained

---

### What Breaks HM

**Ad-hoc polymorphism (traits/type classes)** breaks completeness:

```k
// ❌ HM CANNOT infer this without annotations!
fn print_twice(x) {  // What is the type of x?
    x.print();       // x must implement Display trait
    x.print();
}

// Without trait bound, HM doesn't know:
// - What methods x has
// - What traits x implements
// - What the type of x is
```

**Why it breaks**:
- Type depends on trait implementations
- Requires constraint solving
- Not just unification anymore
- Can be undecidable

---

## HKT and Type Inference

### HKT Alone: Still Inferrable

**Pure HKT without traits** is still HM-compatible:

```k
// This CAN be inferred!
fn map_option(f, opt) {
    return match (opt) {
        .Some => |x| .Some(f(x)),
        .None => .None,
    };
}

// Inferred type:
// fn(comptime A: type, comptime B: type, f: fn(A) B, opt: Option(A)) Option(B)
```

**Why it works**:
- HKT is still parametric polymorphism
- `Option: type -> type` is just a higher-order type parameter
- No constraint solving needed
- Pure unification

---

### HKT + Traits: Not Inferrable

**But add traits**, and inference breaks:

```k
// ❌ CANNOT be fully inferred!
fn functor_map(f, container) {
    return container.map(f);  // Which Functor instance?
}

// Need explicit annotations:
fn functor_map(comptime F: type -> type, comptime A: type, comptime B: type, f: fn(A) B, container: F(A)) F(B)
    where F: Functor
{
    return container.map(f);
}
```

**Why it breaks**:
- Need to find the right `Functor` implementation
- Constraint solving required: `F: Functor`
- Higher-rank types make it worse
- Undecidable in general case

---

## Comparison: Other Languages

| Language | HKT | Traits/Type Classes | Inference Strategy |
|----------|-----|---------------------|-------------------|
| **Haskell** | ✅ Yes | ✅ Yes | **Bidirectional** + annotations |
| **Scala 3** | ✅ Yes | ✅ Yes (implicits) | **Local inference** only |
| **Rust** | ❌ No | ✅ Yes | **Local inference** + explicit signatures |
| **OCaml** | ❌ No | ❌ No (modules) | **Full HM inference** ✅ |
| **K (Current)** | ✅ Yes | ✅ Yes | ❓ **Not decided** |

---

## Type Inference in Presence of Traits

### Problem 1: Constraint Solving

```k
// Simple case - inferrable
fn add_ints(a: i32, b: i32) i32 {
    return a + b;  // Concrete types, no problem
}

// Complex case - NOT fully inferrable
fn generic_add(a, b) {  // ❌ Cannot infer!
    return a + b;  // Which Add trait instance?
}

// Need explicit type:
fn generic_add(comptime T: type, a: T, b: T) T
    where T: Add
{
    return a + b;  // Now we know which Add instance
}
```

**Issue**: Finding the right trait implementation requires constraint solving, which is undecidable in general.

---

### Problem 2: Higher-Rank Types

```k
// ❌ CANNOT infer rank-2 type!
fn apply_to_both(f) {
    const x = f(42);      // f: i32 -> ?
    const y = f("hello"); // f: []const u8 -> ?
    return (x, y);
}

// Must be annotated:
fn apply_to_both(f: fn(comptime T: type, T) T) (i32, []const u8) {
    const x = f(i32, 42);
    const y = f([]const u8, "hello");
    return (x, y);
}
```

**Issue**: Polymorphic function parameters (rank-2 types) require explicit annotation.

---

### Problem 3: Impredicative Instantiation

```k
// ❌ CANNOT infer!
fn weird_example() {
    const id_list = [id, id, id];  // List of polymorphic functions?
    // Type would be: [](fn(comptime T: type, T) T)
    // This is impredicative - type quantifier inside type constructor
}
```

**Issue**: Impredicative polymorphism (quantifiers on the right of arrows) is undecidable.

---

## K Language Inference Strategy

### Recommended Approach: Bidirectional Type Checking

**Combine**:
1. **Type synthesis** (inference) - bottom-up
2. **Type checking** (verification) - top-down

**Inspired by**:
- Haskell (bidirectional + extensions)
- Scala (local inference)
- Rust (local inference + explicit signatures)

---

### Level 1: Local Inference (Always Works)

**Within function bodies**, full inference:

```k
fn example(x: i32, y: i32) i32 {
    const z = x + y;           // z: i32 (inferred)
    const doubled = z * 2;     // doubled: i32 (inferred)
    const result = doubled + 1; // result: i32 (inferred)
    return result;             // ✅ All inferred!
}
```

**Rule**: If function signature is known, body inference is straightforward.

---

### Level 2: Comptime Inference (HM-Like)

**Pure generic code** without traits:

```k
// Can infer this!
fn identity(comptime T: type, x: T) T {
    return x;  // ✅ Trivial
}

fn pair(comptime A: type, comptime B: type, a: A, b: B) (A, B) {
    return (a, b);  // ✅ Can infer
}

fn map_option(comptime A: type, comptime B: type, opt: ?A, f: fn(A) B) ?B {
    return if (opt) |x| f(x) else null;  // ✅ Can infer
}
```

**Rule**: Parametric polymorphism without constraints is inferrable.

---

### Level 3: Trait Constraints (Requires Annotations)

**Trait bounds** require explicit types:

```k
// ❌ CANNOT fully infer - need trait bound annotation
fn print_all(items) {  // What is the type?
    for (items) |item| {
        item.display();  // item must implement Display
    }
}

// ✅ MUST annotate:
fn print_all(comptime T: type, items: []T) void
    where T: Display  // Explicit constraint
{
    for (items) |item| {
        item.display();  // Now we know T: Display
    }
}
```

**Rule**: Trait bounds must be explicit in function signatures.

---

### Level 4: Higher-Rank Types (Always Requires Annotations)

**Polymorphic parameters** need full annotation:

```k
// ❌ CANNOT infer rank-2 type
fn apply_twice(f) {
    f(42);
    f("hello");
}

// ✅ MUST annotate:
fn apply_twice(f: fn(comptime T: type, value: T) void) void {
    f(i32, 42);
    f([]const u8, "hello");
}
```

**Rule**: Higher-rank polymorphism requires explicit annotation.

---

## Inference Rules Summary

### When Inference Works (No Annotation Needed)

✅ **Local variables** within functions
```k
const x = 42;  // i32 (inferred)
```

✅ **Monomorphic code**
```k
fn add(a: i32, b: i32) i32 { return a + b; }
```

✅ **Parametric polymorphism** without constraints
```k
fn id(comptime T: type, x: T) T { return x; }
```

✅ **Simple generic instantiation**
```k
const list = Vec(i32).init();  // Vec(i32) (inferred from constructor)
```

---

### When Annotation Required

❌ **Trait bounds** (ad-hoc polymorphism)
```k
fn example(comptime T: type, x: T) void
    where T: Display  // ← MUST annotate
{ /* ... */ }
```

❌ **Higher-rank types** (rank-2+)
```k
fn example(f: fn(comptime T: type, T) T) void  // ← MUST annotate
{ /* ... */ }
```

❌ **Ambiguous trait instances**
```k
fn example(comptime T: type, x: T) void
    where T: Into(String)  // ← MUST annotate
{ /* ... */ }
```

❌ **Impredicative instantiation**
```k
const list: [](fn(comptime T: type, T) T) = [id, id];  // ← MUST annotate
```

---

## Specific HKT + Traits Issues

### Problem: Functor Map Inference

```k
// ❌ This CANNOT be fully inferred:
fn double_functor(container) {
    return container.map(fn(x) x * 2);
}

// What is the kind of container?
// - type -> type (Functor)
// What is the element type?
// - Must implement Mul
// Which Functor instance?
// - Could be Option, Vec, Result, etc.
```

**Solution**: Require explicit signature:
```k
fn double_functor(comptime F: type -> type, comptime A: type, container: F(A)) F(A)
    where F: Functor,
          A: Mul
{
    return container.map(fn(x: A) A { return x * 2; });
}
```

---

### Problem: Monad Transformer Inference

```k
// ❌ EXTREMELY difficult to infer!
fn run_app(action) {
    return action.run_state(initial_state)
                 .run_reader(config)
                 .run_except();
}

// Type of action?
// - StateT(ReaderT(ExceptT(IO)))(State)(A)
// This is VERY complex!
```

**Solution**: Explicit type aliases and annotations:
```k
const AppM = StateT(ReaderT(ExceptT(IO)));

fn run_app(comptime A: type, action: AppM(State)(A)) IO(Result(A, Error)) {
    return action.run_state(initial_state)
                 .run_reader(config)
                 .run_except();
}
```

---

## Practical Guidelines

### Design Principle: Explicit at Boundaries, Inferred Inside

**Public APIs**: Explicit types
```k
// ✅ Good: Explicit signature
pub fn process_data(comptime T: type, data: []T) !Result(Processed(T), Error)
    where T: Serialize + Validate
{
    const validated = try validate(data);  // Types inferred inside
    const processed = transform(validated); // Types inferred inside
    return serialize(processed);           // Types inferred inside
}
```

**Private code**: Let inference work
```k
fn helper(data: []i32) []i32 {
    const doubled = data.map(fn(x) x * 2);  // Inferred
    const filtered = doubled.filter(fn(x) x > 0);  // Inferred
    return filtered;  // Inferred
}
```

---

### When to Use Comptime

**Use `comptime` for**:
1. Type parameters
2. Compile-time constants
3. Generic functions

```k
fn max(comptime T: type, a: T, b: T) T
    where T: Ord
{
    return if (a > b) a else b;
}
```

**Don't need `comptime` for**:
1. Regular values
2. Runtime computations

```k
fn add(a: i32, b: i32) i32 {  // No comptime needed
    return a + b;
}
```

---

## Answer to Original Question

### "HKT 들어가도 HM 기반 타입 추론 문제 없어?"

**Answer**: HKT 자체는 문제없음, **하지만 K는 traits도 있어서 문제됨**

**Breakdown**:

1. ✅ **HKT only**: HM inference works
   ```k
   fn map_option(comptime A: type, comptime B: type, f: fn(A) B, opt: ?A) ?B
   ```
   - Still parametric polymorphism
   - Pure unification
   - Decidable

2. ❌ **HKT + Traits**: HM inference fails
   ```k
   fn functor_map(comptime F: type -> type, comptime A: type, f: fn(A) B, container: F(A)) F(B)
       where F: Functor  // ← This breaks HM
   ```
   - Requires constraint solving
   - Not decidable in general
   - Need annotations

### "adhoc polymorphism 안 쓰면 돼야 할텐데"

**Correct!** K has ad-hoc polymorphism (traits), so:

- ❌ **Cannot** have full HM inference like OCaml
- ✅ **Can** have local inference like Rust/Scala
- ✅ **Must** require explicit signatures for trait-bounded functions

**K's approach**:
```k
// Function signatures: EXPLICIT
fn process(comptime T: type, data: T) Result
    where T: Serialize  // ← Must be explicit
{
    // Function body: INFERRED
    const bytes = data.serialize();  // ✅ Inferred
    const compressed = compress(bytes);  // ✅ Inferred
    return Ok(compressed);  // ✅ Inferred
}
```

---

## Comparison: What We Sacrifice vs Gain

### We Sacrifice (compared to OCaml/ML)

❌ **Full global type inference**
- Cannot write functions without type signatures
- Need explicit trait bounds

❌ **No polymorphic let**
- Cannot infer polymorphic local functions easily

### We Gain (compared to OCaml/ML)

✅ **Ad-hoc polymorphism (traits)**
- Operator overloading
- Generic interfaces
- Ergonomic abstractions

✅ **Higher-kinded types**
- Functor, Monad, etc.
- Monad transformers
- Advanced abstractions

✅ **Better code reuse**
- Trait-based generic programming
- More expressive than ML modules

---

## Conclusion

### Type Inference Strategy for K

**Adopt**: **Bidirectional type checking** + **Local inference**

**Rules**:
1. **Function signatures**: Explicit types required (like Rust)
2. **Function bodies**: Full inference (like ML)
3. **Trait bounds**: Must be explicit (decidability)
4. **Higher-rank types**: Must be explicit (undecidable otherwise)

**Result**:
- ✅ Predictable type checking
- ✅ Good error messages
- ✅ Decidable algorithm
- ✅ Balances inference and control

**Trade-off**:
- ❌ Not full HM inference (due to traits)
- ✅ But more expressive type system (HKT + traits)
- ✅ Still better than C++ templates!

### Comparison

| Language | Inference | HKT | Traits | Result |
|----------|-----------|-----|--------|--------|
| **OCaml** | Full HM | ❌ | ❌ | Simple, fully inferrable |
| **Haskell** | Bidirectional | ✅ | ✅ | Complex, some annotations |
| **Rust** | Local only | ❌ | ✅ | Simple, many annotations |
| **Scala** | Local only | ✅ | ✅ | Complex, many annotations |
| **K** | **Local + Bidirectional** | ✅ | ✅ | **Best of both worlds?** |

K aims for: **Maximum expressiveness** (HKT + traits) with **practical inference** (local + bidirectional)!
