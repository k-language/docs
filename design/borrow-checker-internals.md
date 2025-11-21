# Borrow Checker Internals: How It Works

## Overview

This document explains the internal workings of K Language's borrow checker - how the compiler analyzes code to enforce memory safety at compile time.

## Compilation Pipeline

The borrow checker operates as part of the compiler's middle-end:

```
Source Code
    ↓
Lexing & Parsing → AST (Abstract Syntax Tree)
    ↓
Name Resolution → Resolve all identifiers
    ↓
Type Checking → Infer and check types
    ↓
BORROW CHECKING → Check ownership & lifetimes ← We are here
    ↓
MIR (Mid-level IR) → Simplified representation
    ↓
Optimization → LLVM optimizations
    ↓
Code Generation → Machine code
```

## Core Concepts

### 1. Lifetimes

Every reference has a lifetime - the scope for which it is valid.

```k
fn example() {
    let x = 5;           // 'x starts here (lifetime 'a)
    {
        let y = &x;      // 'y starts here (lifetime 'b)
        // 'b must be contained within 'a
    }                    // 'b ends here
}                        // 'a ends here
```

The borrow checker ensures: **'b ⊆ 'a** (lifetime 'b is subset of 'a)

### 2. Borrow Constraints

The compiler generates constraints while analyzing code:

```k
fn longest(x: &'a str, y: &'a str) -> &'a str {
    if (x.len > y.len) x else y
}
```

Constraints generated:
- Input 'a must be valid for entire function body
- Return value has lifetime 'a
- 'a must outlive the call site

### 3. Points in the Control Flow Graph

The borrow checker tracks borrows at specific program points:

```k
fn example() {
    let mut x = 5;
    // Point 1: No active borrows

    let y = &x;
    // Point 2: Immutable borrow of 'x active

    // x = 6;  // ERROR: Cannot modify while borrowed
    // Point 3: Still borrowed

    println!("{}", y);
    // Point 4: Last use of 'y

    x = 6;  // OK: Borrow ended at Point 4
    // Point 5: No active borrows
}
```

## Borrow Checking Algorithm

### Phase 1: Control Flow Graph Construction

The compiler builds a CFG (Control Flow Graph) representing all possible execution paths:

```k
fn conditional_borrow(flag: bool) {
    let mut x = 5;

    if (flag) {
        let y = &x;    // Borrow in this branch
        use(y);
    } else {
        x = 10;        // Modify in this branch
    }

    // Paths merge here
}
```

CFG:
```
    [Start]
       ↓
   [let x = 5]
       ↓
   [if flag]
    ↙     ↘
[let y=&x] [x=10]
    ↘     ↙
    [Merge]
       ↓
    [End]
```

### Phase 2: Liveness Analysis

Determine which variables are "live" at each program point:

```k
fn liveness_example() {
    let x = 5;        // 'x becomes live
    let y = x + 1;    // 'x read (last use)
    use(y);           // 'y read (last use)
    // 'x and 'y are dead here
}
```

A variable is live from its declaration until its last use.

### Phase 3: Borrow Analysis

Track all active borrows at each program point:

```k
fn borrow_analysis() {
    let mut data = vec![1, 2, 3];
    // Borrows: {}

    let slice = &data[..];
    // Borrows: {data ← &}

    // data.push(4);  // ERROR: data borrowed
    // Borrows: {data ← &}

    println!("{}", slice.len());
    // Last use of 'slice'

    data.push(4);  // OK
    // Borrows: {}
}
```

For each borrow `b`:
- Track what is borrowed
- Track borrow type (shared `&` or mutable `&mut`)
- Track lifetime of the borrow

### Phase 4: Constraint Generation

Generate constraints for each borrow:

```k
fn constraints_example<'a>(x: &'a i32, y: &'a i32) -> &'a i32 {
    if (*x > *y) {
        return x;  // Constraint: 'a outlives return point
    }
    return y;      // Constraint: 'a outlives return point
}
```

Constraints:
1. `'a: 'return` (lifetime 'a must outlive return)
2. Return value must not outlive 'a

### Phase 5: Constraint Solving

The compiler solves the constraint system to check validity:

```k
// This fails constraint solving:
fn dangling<'a>() -> &'a i32 {
    let x = 5;           // Lifetime 'local
    return &x;           // ERROR: 'local does not outlive 'a
}
// Constraint: 'local: 'a
// But 'local ends at function exit, 'a must extend beyond
// Contradiction! → Compile error
```

## Non-Lexical Lifetimes (NLL)

K uses NLL for more precise borrow checking based on actual usage, not just scopes.

### Old (Lexical) Lifetimes

```k
fn lexical_problem() {
    let mut x = 5;

    {
        let y = &x;      // Borrow starts
        use(y);          // Last use of y
    }                    // Borrow ends here (lexical scope)

    x = 10;  // OK
}
```

### Non-Lexical Lifetimes

```k
fn nll_benefit() {
    let mut x = 5;

    let y = &x;          // Borrow starts
    use(y);              // Last use of y - borrow ends HERE

    x = 10;  // OK: Borrow already ended
    // No extra scope needed!
}
```

NLL Algorithm:
1. Build CFG with all program points
2. Track last use of each borrow
3. End borrows at last use, not end of scope
4. More permissive but still safe

## Two-Phase Borrows

Handles method calls where `self` is borrowed mutably:

```k
fn two_phase_example() {
    let mut vec = Vec::new();

    vec.push(vec.len());  // Looks like it borrows twice!
    // But it's OK with two-phase borrows
}
```

How it works:
1. **Reservation phase**: `vec.push` reserves mutable access
2. **Evaluation phase**: `vec.len()` reads (using shared access)
3. **Activation phase**: Push writes to vec (mutable access activated)

## Move Semantics

The borrow checker also tracks moves:

```k
fn move_example() {
    let s1 = String::from("hello");
    let s2 = s1;  // s1 moved to s2

    // println!("{}", s1);  // ERROR: s1 was moved
    println!("{}", s2);     // OK
}
```

Move tracking:
- Each value has exactly one owner
- When moved, old binding becomes invalid
- Compiler tracks move state at each program point

```
[s1 initialized]
    ↓
[s1 moved to s2] → s1 state: MOVED
    ↓             → s2 state: VALID
[use s2] → OK
[use s1] → ERROR
```

## Copy Types

Types implementing `Copy` are copied instead of moved:

```k
fn copy_example() {
    let x: i32 = 5;  // i32 implements Copy
    let y = x;       // x is copied, not moved

    println!("{}", x);  // OK: x still valid
    println!("{}", y);  // OK: y valid too
}
```

Copy rules:
- `Copy` types are bitwise copyable
- No resources requiring cleanup (no allocations, file handles, etc.)
- Examples: integers, floats, booleans, `Copy` structs

## Interior Mutability

Special handling for types like `Cell` and `RefCell`:

```k
const Cell = struct {
    value: i32,

    pub fn get(self: &Cell) i32 {
        return self.value;
    }

    pub fn set(self: &Cell, value: i32) void {
        // Interior mutability: mutating through & reference
        @constCast(self).value = value;
    }
};
```

Borrow checker behavior:
- `Cell<T>` is `!Sync` (not thread-safe)
- Runtime borrow checking for `RefCell<T>`
- Compile-time checking cannot prevent all issues

## Error Messages

The borrow checker produces detailed error messages:

```k
fn error_example() {
    let mut x = 5;
    let y = &x;
    x = 10;  // ERROR
    use(y);
}
```

Error output:
```
error[E0506]: cannot assign to `x` because it is borrowed
  --> example.k:3:5
   |
2  |     let y = &x;
   |             -- borrow of `x` occurs here
3  |     x = 10;
   |     ^^^^^^ assignment to borrowed `x` occurs here
4  |     use(y);
   |         - borrow later used here

help: consider ending the borrow before assignment
   |
3  |     drop(y);
3  |     x = 10;
   |
```

Error components:
1. **Error code**: E0506 (standardized error)
2. **Location**: Line and column numbers
3. **Context**: Relevant source code
4. **Explanation**: What went wrong
5. **Suggestion**: How to fix it

## Polonius: Next-Generation Borrow Checker

K's future borrow checker will use the Polonius algorithm for even more precision:

### Current Limitations

```k
fn limitation() {
    let mut map: HashMap<i32, String> = HashMap::new();

    match map.get(&22) {
        Some(value) => {
            // Current borrow checker: map is borrowed here
            // map.insert(44, String::new());  // ERROR
        }
        None => {
            map.insert(44, String::new());  // OK
        }
    }
}
```

### With Polonius

```k
fn with_polonius() {
    let mut map: HashMap<i32, String> = HashMap::new();

    match map.get(&22) {
        Some(value) => {
            // Polonius: borrow only used in this arm
            // Can determine map is NOT borrowed here
            // map.insert(44, String::new());  // OK with Polonius!
        }
        None => {
            map.insert(44, String::new());  // OK
        }
    }
}
```

Polonius uses:
- **Datalog**: Logic programming for constraint solving
- **Origin tracking**: Track where borrows originate
- **Path-sensitive analysis**: Different paths have different borrow states
- **More precise**: Accepts more correct programs

## Implementation Details

### Borrow Set Representation

The compiler tracks borrows using a set data structure:

```rust
struct BorrowSet {
    borrows: HashMap<Location, BorrowData>,
}

struct BorrowData {
    borrowed_place: Place,       // What is borrowed (e.g., x, x.field)
    kind: BorrowKind,            // Shared, Mutable, or Unique
    region: Region,              // Lifetime of the borrow
    assigned_place: Place,       // Where the reference is stored
}

enum BorrowKind {
    Shared,     // &T
    Mutable,    // &mut T
    Unique,     // For two-phase borrows
}
```

### Place Abstraction

A "place" represents a memory location:

```k
x          // Variable
x.field    // Field access
x[i]       // Index
*x         // Dereference
```

Place representation:
```rust
struct Place {
    local: Local,              // Base variable
    projection: Vec<PlaceElem>, // How to reach the place
}

enum PlaceElem {
    Field(FieldIdx),
    Index,
    Deref,
}
```

### Path Analysis

The compiler checks if two places might overlap:

```k
fn overlap_check() {
    let mut x = Point { a: 1, b: 2 };

    let r1 = &mut x.a;
    let r2 = &mut x.b;  // OK: Different fields

    // let r3 = &mut x;  // ERROR: Overlaps with r1 and r2
}
```

Overlap rules:
- `x` and `x.field` overlap
- `x` and `*x` overlap
- `x.a` and `x.b` do NOT overlap (disjoint fields)
- `x[i]` and `x[j]` might overlap (conservative)

## Debugging Borrow Checker Issues

### Technique 1: Explicit Lifetimes

Add explicit lifetime annotations to understand inference:

```k
// Original
fn problematic(x: &str) -> &str {
    // ...
}

// With explicit lifetimes
fn problematic<'a>(x: &'a str) -> &'a str {
    // Now clearer what the constraint is
}
```

### Technique 2: Scope Reduction

Introduce scopes to end borrows early:

```k
fn fix_with_scope() {
    let mut x = 5;

    {
        let y = &x;
        use(y);
    }  // Borrow ends here

    x = 10;  // OK
}
```

### Technique 3: Clone When Needed

Sometimes cloning is the simplest solution:

```k
fn use_clone() {
    let s = String::from("hello");

    let s_clone = s.clone();
    consume(s);  // Moves s

    // Can still use s_clone
    println!("{}", s_clone);
}
```

### Technique 4: Refactor to Avoid Conflicts

Restructure code to avoid borrow conflicts:

```k
// Before: Conflict
fn conflicted(self: &mut Self) {
    let x = &self.field1;
    self.field2 = 10;  // ERROR: self already borrowed
    use(x);
}

// After: Separate accesses
fn fixed(self: &mut Self) {
    let x = self.field1;  // Copy the value
    self.field2 = 10;     // OK: self not borrowed
    use(x);
}
```

## Performance Considerations

Borrow checking has compile-time cost but zero runtime cost:

### Compile Time

- **O(n²)** in worst case for constraint solving
- Optimized with incremental compilation
- Cached between builds
- Parallel checking of independent functions

### Runtime

- **Zero overhead**: All checks are compile-time
- No reference counting
- No garbage collection
- Direct memory access

## Advanced Features

### Variance

How lifetime parameters relate in generic types:

```k
// Covariant: &'a T can be used as &'b T if 'a: 'b
fn covariant<'a, 'b>(x: &'a i32) -> &'b i32
    where 'a: 'b  // 'a outlives 'b
{
    x  // OK: can shorten lifetime
}

// Invariant: &mut T is invariant in T
// Cannot change lifetime of &mut
```

### Higher-Rank Trait Bounds (HRTB)

For all lifetimes:

```k
fn with_hrtb<F>(f: F)
    where F: for<'a> Fn(&'a i32) -> &'a i32
{
    // F works for ANY lifetime 'a
}
```

### Subtyping

Lifetime subtyping:

```
'static: 'a  for any 'a
// 'static outlives everything

'a: 'b  // 'a outlives 'b
// Can use &'a T where &'b T is expected
```

## Summary

The K Language borrow checker:

1. **Builds CFG** from source code
2. **Tracks lifetimes** of all references
3. **Generates constraints** for borrows
4. **Solves constraints** to verify safety
5. **Reports errors** with helpful messages
6. **Zero runtime cost** - all checks compile-time

Key algorithms:
- Non-lexical lifetimes for precision
- Two-phase borrows for convenience
- Move analysis for ownership
- Polonius (future) for even more precision

The result: **Memory safety without garbage collection!**

## References

- [Rust RFC 2094: Non-lexical lifetimes](https://rust-lang.github.io/rfcs/2094-nll.html)
- [Polonius](https://github.com/rust-lang/polonius)
- [MIR Borrow Check](https://rustc-dev-guide.rust-lang.org/borrow_check.html)
- [How to Read Rust Functions](http://web.mit.edu/rust-lang_v1.25/arch/amd64_ubuntu1404/share/doc/rust/html/book/first-edition/lifetimes.html)
