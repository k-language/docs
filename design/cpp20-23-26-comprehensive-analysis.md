# C++20/23/26 Comprehensive Feature Analysis for K Language

## Executive Summary

This document analyzes **all major features** from C++20, C++23, and C++26 to determine which features should be added to K language.

**Key Question**: Are contracts meaningful even with borrow checking?
**Answer**: ✅ **YES! Contracts and borrow checking are complementary.**

---

## Part 1: Why Contracts Matter Even With Borrow Checking

### What Borrow Checking Guarantees

Rust-style borrow checking (which K has) guarantees:
- ✅ **Memory safety**: No use-after-free, no double-free
- ✅ **Data race freedom**: No concurrent mutable access
- ✅ **Reference validity**: References always point to valid data
- ✅ **Lifetime correctness**: References don't outlive their referents

### What Contracts Guarantee (That Borrow Checking CANNOT)

Contracts express **semantic invariants** that type systems cannot capture:

#### 1. Value Range Constraints
```k
fn divide(a: i32, b: i32) i32
  pre (b != 0)  // ❌ Borrow checking can't enforce this!
{
  return a / b;
}

fn set_age(person: &mut Person, age: i32) void
  pre (age >= 0 and age <= 150)  // ❌ Type system can't enforce this!
{
  person.age = age;
}
```

**Why borrow checking can't help**: `i32` is a valid type, but not all `i32` values are valid ages.

#### 2. Algorithm Invariants
```k
fn binary_search<T>(array: []const T, target: T) ?usize
  pre (is_sorted(array))  // ❌ Borrow checking can't verify sorting!
  post (result: result == null or array[result.?] == target)
{
  // ...
}

fn sqrt(x: f64) f64
  pre (x >= 0.0)  // ❌ Type system can't enforce non-negative!
  post (result: abs(result * result - x) < 1e-10)
{
  // ...
}
```

#### 3. Pointer Aliasing (Beyond Borrow Checking)
```k
fn swap(a: &mut T, b: &mut T) void
  pre (!ptr.eq(a, b))  // ❌ Borrow checking allows this (same lifetime)!
{
  const tmp = a.*;
  a.* = b.*;
  b.* = tmp;
}
```

**Note**: Borrow checking ensures `a` and `b` are valid and exclusive, but can't prevent them from being the **same address** (e.g., via unsafe code or external C calls).

#### 4. Collection Invariants
```k
fn get(self: &Self, index: usize) &T
  pre (index < self.len())  // ❌ Borrow checking can't check bounds!
{
  return &self.items[index];
}

fn push(self: &mut Self, value: T) void
  pre (self.len() < self.capacity())  // ❌ Can't express this in types!
{
  self.items[self.len_] = value;
  self.len_ += 1;
}
```

#### 5. Business Logic Invariants
```k
fn withdraw(account: &mut Account, amount: f64) !void
  pre (amount > 0.0)
  pre (account.balance >= amount)  // ❌ Type system can't check this!
  post (account.balance == @old(account.balance) - amount)
{
  account.balance -= amount;
}

fn transfer(from: &mut Account, to: &mut Account, amount: f64) !void
  pre (!ptr.eq(from, to))
  pre (amount > 0.0)
  pre (from.balance >= amount)
  post (from.balance + to.balance ==
        @old(from.balance) + @old(to.balance))  // ❌ Conservation law!
{
  from.balance -= amount;
  to.balance += amount;
}
```

### Conclusion: Contracts Are Essential

| Concern | Borrow Checking | Contracts |
|---------|----------------|-----------|
| Memory safety | ✅ | ❌ |
| Data race freedom | ✅ | ❌ |
| Value range constraints | ❌ | ✅ |
| Algorithm preconditions | ❌ | ✅ |
| Business logic invariants | ❌ | ✅ |
| Conservation laws | ❌ | ✅ |
| Sorted/ordered data | ❌ | ✅ |

**Verdict**: ✅ **Contracts and borrow checking solve different problems. K needs both.**

---

## Part 2: C++20 Features Analysis

### Language Features

#### 1. Concepts ⚠️

**C++ Syntax**:
```cpp
template<typename T>
concept Integral = std::is_integral_v<T>;

template<Integral T>
T add(T a, T b) { return a + b; }
```

**K Status**: ✅ **K already has traits** (which are better than C++ concepts)

**K equivalent**:
```k
fn add<T: Integral>(a: T, b: T) T {
  return a + b;
}
```

**Recommendation**: ❌ **No action needed** - K's traits are more powerful

---

#### 2. Three-Way Comparison (`<=>`) ⭐

**C++ Syntax**:
```cpp
struct Point {
  int x, y;
  auto operator<=>(const Point&) const = default;
};
// Generates all 6 comparison operators
```

**K Status**: ⚠️ **Should consider**

**Recommendation**: ✅ **Add spaceship operator to K**

**Proposed K syntax**:
```k
const Point = struct {
  x: i32,
  y: i32,

  fn compare(self: Self, other: Self) Ordering {
    return self.x.compare(other.x)
      .then(self.y.compare(other.y));
  }
};

// Or auto-derive
const Point = struct {
  x: i32,
  y: i32,
} derive(Ord, Eq);
```

**Why useful**:
- ✅ Single comparison generates all 6 operators (`<`, `<=`, `>`, `>=`, `==`, `!=`)
- ✅ Reduces boilerplate
- ✅ Rust has similar with `Ord` trait

---

#### 3. Ranges ⭐⭐⭐

**C++ Syntax**:
```cpp
auto even = [](int i) { return i % 2 == 0; };
auto square = [](int i) { return i * i; };

for (int i : std::views::iota(1, 10)
           | std::views::filter(even)
           | std::views::transform(square)) {
  std::cout << i << ' ';  // 4 16 36 64
}
```

**K Status**: ❌ **NOT designed yet**

**Recommendation**: ✅ **HIGHLY RECOMMENDED** - Add ranges/iterators library

**Proposed K syntax**:
```k
const result = range(1, 10)
  .filter(|x| x % 2 == 0)
  .map(|x| x * x)
  .collect();

// Or with pipe operator
const result = range(1, 10)
  |> filter(|x| x % 2 == 0)
  |> map(|x| x * x)
  |> collect();

// Lazy evaluation
const evens = range(1, 100)
  .filter(|x| x % 2 == 0);  // No work done yet

for (evens) |x| {  // Evaluated on demand
  std.debug.print("{}\n", .{x});
}
```

**Why essential**:
- ✅ Composable transformations
- ✅ Lazy evaluation (no intermediate allocations)
- ✅ Better than manual loops
- ✅ Rust has this (`Iterator` trait)

**Integration with K**:
```k
// K already has Iterator in std-library-types.md!
trait Iterator {
  type Item;
  fn next(self: &mut Self) ?Self.Item;
}

// Add range adaptors
impl Iterator for Range<T> { ... }
impl Iterator for Filter<I, F> { ... }
impl Iterator for Map<I, F> { ... }

// Chainable methods
trait IteratorExt: Iterator {
  fn filter<F>(self, predicate: F) Filter<Self, F> { ... }
  fn map<F>(self, func: F) Map<Self, F> { ... }
  fn take(self, n: usize) Take<Self> { ... }
  fn skip(self, n: usize) Skip<Self> { ... }
  fn collect<C: FromIterator>(self) C { ... }
}
```

---

#### 4. Coroutines ⭐⭐

**C++ Syntax**:
```cpp
generator<int> fibonacci() {
  int a = 0, b = 1;
  while (true) {
    co_yield a;
    auto next = a + b;
    a = b;
    b = next;
  }
}
```

**K Status**: ❌ **NOT designed yet**

**Recommendation**: ✅ **HIGHLY RECOMMENDED** - Design with async/await

**Proposed K syntax**:
```k
fn fibonacci() Generator<i32> {
  var a: i32 = 0;
  var b: i32 = 1;
  while (true) {
    yield a;
    const next = a + b;
    a = b;
    b = next;
  }
}

// Usage
const fib = fibonacci();
for (fib.take(10)) |n| {
  std.debug.print("{}\n", .{n});
}
```

**Integration with async/await**:
```k
async fn fetch_pages(urls: []const []const u8) AsyncGenerator<!Response> {
  for (urls) |url| {
    yield await http.get(url);
  }
}

// Usage
const pages = fetch_pages(urls);
for (await pages) |page| {
  try process(page);
}
```

---

#### 5. Modules ❌

**C++ Syntax**:
```cpp
// math.cppm
export module math;

export int add(int a, int b) {
  return a + b;
}

// main.cpp
import math;
int result = add(1, 2);
```

**K Status**: ✅ **K already has `@import`** (Zig-style)

**K equivalent**:
```k
// math.k
pub fn add(a: i32, b: i32) i32 {
  return a + b;
}

// main.k
const math = @import("math.k");
const result = math.add(1, 2);
```

**Recommendation**: ❌ **No action needed** - K's module system is already good

---

#### 6. Designated Initializers ❌

**C++ Syntax**:
```cpp
struct Point { int x, y; };
Point p = { .x = 10, .y = 20 };
```

**K Status**: ✅ **K already has this**

**K syntax**:
```k
const Point = struct { x: i32, y: i32 };
const p = Point{ .x = 10, .y = 20 };
```

**Recommendation**: ❌ **No action needed**

---

#### 7. `consteval` / `constinit` ❌

**C++ Syntax**:
```cpp
consteval int square(int n) {
  return n * n;  // MUST evaluate at compile time
}

constinit int global = square(5);  // MUST initialize at compile time
```

**K Status**: ✅ **K already has `comptime`**

**K equivalent**:
```k
fn square(comptime n: i32) i32 {
  return n * n;
}

const global = comptime square(5);
```

**Recommendation**: ❌ **No action needed** - K's comptime is more flexible

---

### C++20 Library Features

#### 1. `std::format` ❌

**C++ Syntax**:
```cpp
std::string msg = std::format("Hello, {}! Age: {}", name, age);
```

**K Status**: ✅ **K already has string interpolation**

**K syntax**:
```k
const msg = "Hello, {name}! Age: {age}";
```

**Recommendation**: ❌ **No action needed**

---

#### 2. `std::span` ❌

**C++ Syntax**:
```cpp
void process(std::span<int> data) {
  for (int x : data) { ... }
}
```

**K Status**: ✅ **K already has slices**

**K syntax**:
```k
fn process(data: []const i32) void {
  for (data) |x| { ... }
}
```

**Recommendation**: ❌ **No action needed**

---

#### 3. `std::jthread` + Synchronization ⭐⭐

**C++ Syntax**:
```cpp
std::jthread worker([]() {
  // Auto-joins on destruction
});

std::latch done(3);
// ... workers call done.count_down()
done.wait();

std::barrier sync(3);
// ... workers call sync.arrive_and_wait()
```

**K Status**: ⚠️ **Basic concurrency, needs more**

**Recommendation**: ✅ **HIGHLY RECOMMENDED** - Add `std.sync` primitives

**Proposed K additions**:
```k
// std.sync module
const Thread = struct {
  fn spawn(func: fn() void) Thread { ... }
  fn join(self: &mut Self) void { ... }
  // Auto-join in destructor (via defer in scope)
};

const Latch = struct {
  fn init(count: usize) Latch { ... }
  fn count_down(self: &Self) void { ... }
  fn wait(self: &Self) void { ... }
};

const Barrier = struct {
  fn init(count: usize) Barrier { ... }
  fn arrive_and_wait(self: &Self) void { ... }
};

const Semaphore = struct {
  fn init(count: usize) Semaphore { ... }
  fn acquire(self: &Self) void { ... }
  fn release(self: &Self) void { ... }
};
```

---

#### 4. Calendar and Time Zones ⭐

**C++ Syntax**:
```cpp
auto now = std::chrono::system_clock::now();
auto ymd = std::chrono::year_month_day{now};
auto tz = std::chrono::locate_zone("America/New_York");
```

**K Status**: ⚠️ **Basic time support**

**Recommendation**: ✅ **RECOMMENDED** - Add `std.time` with calendar/timezone

**Proposed K design**:
```k
const std = @import("std");
const time = std.time;

// Current time
const now = time.now();

// Date components
const date = time.Date.from_timestamp(now);
std.debug.print("{}-{}-{}\n", .{date.year, date.month, date.day});

// Timezone support
const tz = time.Timezone.load("America/New_York");
const local = tz.to_local(now);

// Duration arithmetic
const tomorrow = now + time.Duration.days(1);
const deadline = now + time.Duration.hours(24);
```

---

#### 5. Bit Operations ⚠️

**C++ Syntax**:
```cpp
std::popcount(0b1101);  // 3
std::rotl(0b1100, 1);   // 0b1001
std::bit_cast<float>(0x3f800000);  // 1.0f
```

**K Status**: ⚠️ **Should have bit utilities**

**Recommendation**: ✅ **Low priority** - Add `std.bit` module

**Proposed K design**:
```k
const std = @import("std");
const bit = std.bit;

const count = bit.popcount(0b1101);  // 3
const rotated = bit.rotl(u8, 0b1100, 1);
const f = bit.cast(f32, 0x3f800000);  // Type-safe bit cast
```

---

## Part 3: C++23 Features Analysis

### Language Features

#### 1. Deducing This (Explicit Object Parameter) ⭐⭐

**C++ Syntax**:
```cpp
struct Container {
  // One function handles both lvalue and rvalue
  template<typename Self>
  auto get(this Self&& self, size_t i) {
    return std::forward<Self>(self).data[i];
  }
};
```

**K Status**: ⚠️ **Interesting for trait design**

**Recommendation**: ✅ **RECOMMENDED** - Consider for K's `self` parameter

**Why useful**:
- Eliminates duplicate code for `&self` vs `&mut self` vs `self`
- Better method chaining
- Could integrate with K's traits

**Proposed K exploration**:
```k
// Current K: need separate methods
fn get(self: &Self, i: usize) &T { ... }
fn get_mut(self: &mut Self, i: usize) &mut T { ... }

// With deducing this:
fn get<ref Self>(self: ref Self, i: usize) ref T { ... }
// Where 'ref' is inferred as &, &mut, or owned
```

**Decision**: ⚠️ **Needs more design work** - Could simplify trait implementations

---

#### 2. Multidimensional Subscript ⭐

**C++ Syntax**:
```cpp
matrix[1, 2] = 42;  // Instead of matrix[1][2]
```

**K Status**: ❌ **NOT supported**

**Recommendation**: ✅ **RECOMMENDED** - Add multi-dimensional indexing

**Proposed K syntax**:
```k
const Matrix = struct {
  // Overload subscript with multiple indices
  fn index(self: &Self, row: usize, col: usize) &T {
    return &self.data[row * self.cols + col];
  }
};

// Usage
const m = Matrix.init(3, 3);
m[1, 2] = 42;  // Cleaner than m.at(1, 2) or m[1][2]
```

---

#### 3. `if consteval` ❌

**C++ Syntax**:
```cpp
int f() {
  if consteval {
    return compile_time_value();
  } else {
    return runtime_value();
  }
}
```

**K Status**: ✅ **K already has `comptime if`**

**K equivalent**:
```k
fn f() i32 {
  if (comptime @inComptime()) {
    return compile_time_value();
  } else {
    return runtime_value();
  }
}
```

**Recommendation**: ❌ **No action needed**

---

#### 4. Static `operator[]` / `operator()` ⚠️

**C++ Syntax**:
```cpp
struct Factory {
  static int operator()(int x) { return x * 2; }
};

Factory{}(5);  // 10
```

**K Status**: ⚠️ **Not applicable** - K has regular static functions

**Recommendation**: ❌ **Skip** - K doesn't need this

---

### C++23 Library Features

#### 1. `std::expected` ❌

**C++ Syntax**:
```cpp
std::expected<int, Error> divide(int a, int b) {
  if (b == 0) return std::unexpected(Error::DivByZero);
  return a / b;
}
```

**K Status**: ✅ **K already has `!T`**

**K equivalent**:
```k
fn divide(a: i32, b: i32) !i32 {
  if (b == 0) return error.DivByZero;
  return a / b;
}
```

**Recommendation**: ❌ **No action needed** - K's `!T` is better

---

#### 2. `std::mdspan` ⭐⭐

**C++ Syntax**:
```cpp
std::mdspan<double, std::dextents<2>> matrix(data, 3, 4);
matrix[1, 2] = 3.14;
```

**K Status**: ❌ **NOT designed yet**

**Recommendation**: ✅ **HIGHLY RECOMMENDED** - Essential for linear algebra

**Proposed K design**:
```k
// Multi-dimensional span
const MdSpan = struct(T: type, comptime rank: usize) {
  data: []T,
  extents: [rank]usize,

  fn init(data: []T, extents: [rank]usize) MdSpan(T, rank) { ... }

  fn index(self: &Self, indices: [rank]usize) &T {
    var offset: usize = 0;
    var stride: usize = 1;
    for (0..rank) |i| {
      const dim = rank - 1 - i;
      offset += indices[dim] * stride;
      stride *= self.extents[dim];
    }
    return &self.data[offset];
  }
};

// Usage
const data = [_]f64{0} ** 12;
const matrix = MdSpan(f64, 2).init(data[0..], .{3, 4});
matrix.at(.{1, 2}) = 3.14;

// Or with multidimensional subscript:
matrix[1, 2] = 3.14;
```

**Integration with linear algebra**:
```k
const linalg = std.linalg;
const A = MdSpan(f64, 2).init(a_data, .{3, 3});
const B = MdSpan(f64, 2).init(b_data, .{3, 3});
const C = linalg.matmul(A, B);
```

---

#### 3. `std::print` / `std::println` ❌

**C++ Syntax**:
```cpp
std::print("Hello, {}!\n", name);
std::println("Value: {}", value);
```

**K Status**: ✅ **K already has this**

**K equivalent**:
```k
std.debug.print("Hello, {s}!\n", .{name});
std.debug.print("Value: {}\n", .{value});
```

**Recommendation**: ❌ **No action needed**

---

#### 4. `std::flat_map` / `std::flat_set` ⭐

**C++ Syntax**:
```cpp
std::flat_map<int, std::string> map;
map[1] = "one";
// Stored as sorted vector, better cache locality
```

**K Status**: ❌ **NOT designed yet**

**Recommendation**: ✅ **RECOMMENDED** - Add to standard library

**Why useful**:
- ✅ Better cache locality than tree-based map
- ✅ Faster iteration
- ✅ Lower memory overhead
- ✅ Good for small/medium collections

**Proposed K design**:
```k
const FlatMap = struct(K: type, V: type) {
  keys: []K,
  values: []V,

  fn get(self: &Self, key: K) ?&V {
    const idx = binary_search(self.keys, key);
    if (idx) |i| return &self.values[i];
    return null;
  }

  fn insert(self: &mut Self, key: K, value: V) !void {
    const idx = binary_search_insert_pos(self.keys, key);
    try self.keys.insert(idx, key);
    try self.values.insert(idx, value);
  }
};
```

---

#### 5. `std::generator` ⭐

**C++ Syntax**:
```cpp
std::generator<int> range(int start, int end) {
  for (int i = start; i < end; ++i) {
    co_yield i;
  }
}
```

**K Status**: ❌ **NOT designed yet**

**Recommendation**: ✅ **RECOMMENDED** - Add with coroutines

**See**: Coroutines section in C++20

---

#### 6. `std::stacktrace` ⭐

**C++ Syntax**:
```cpp
auto trace = std::stacktrace::current();
for (const auto& frame : trace) {
  std::cout << frame << '\n';
}
```

**K Status**: ⚠️ **Should have debug utilities**

**Recommendation**: ✅ **RECOMMENDED** - Add `std.debug.stacktrace()`

**Proposed K design**:
```k
const std = @import("std");

fn crash_handler() void {
  const trace = std.debug.stacktrace();
  for (trace.frames) |frame| {
    std.debug.print("  at {s}:{}\n", .{frame.file, frame.line});
  }
}
```

---

#### 7. Monadic Operations ⭐⭐

**C++ Syntax**:
```cpp
std::optional<int> x = 42;
auto result = x
  .transform([](int n) { return n * 2; })
  .and_then([](int n) -> std::optional<int> {
    if (n > 50) return n;
    return std::nullopt;
  });
```

**K Status**: ⚠️ **Should add to `Option<T>` and `!T`**

**Recommendation**: ✅ **HIGHLY RECOMMENDED** - Add monadic methods

**Proposed K design**:
```k
// Add to Option<T>
impl Option<T> {
  fn map<U>(self, func: fn(T) U) Option<U> {
    return match (self) {
      .Some => |value| .Some(func(value)),
      .None => .None,
    };
  }

  fn and_then<U>(self, func: fn(T) Option<U>) Option<U> {
    return match (self) {
      .Some => |value| func(value),
      .None => .None,
    };
  }

  fn or_else(self, func: fn() Option<T>) Option<T> {
    return match (self) {
      .Some => |value| .Some(value),
      .None => func(),
    };
  }
}

// Add to Result<T, E> (which is !T in K)
impl Result<T, E> {
  fn map<U>(self, func: fn(T) U) Result<U, E> { ... }
  fn map_err<F>(self, func: fn(E) F) Result<T, F> { ... }
  fn and_then<U>(self, func: fn(T) Result<U, E>) Result<U, E> { ... }
  fn or_else<F>(self, func: fn(E) Result<T, F>) Result<T, F> { ... }
}

// Usage
const result = parse_int(input)
  .map(|x| x * 2)
  .and_then(|x| validate_positive(x))
  .or_else(|_| default_value());
```

**Why essential**:
- ✅ Enables functional error handling
- ✅ Chainable operations
- ✅ Cleaner than nested match expressions
- ✅ Rust has this

---

#### 8. Range Adaptors ⭐

**C++ Syntax**:
```cpp
auto result = vec
  | std::views::zip(other)
  | std::views::enumerate
  | std::views::chunk(3);
```

**K Status**: ❌ **NOT designed yet**

**Recommendation**: ✅ **RECOMMENDED** - Add with Ranges

**See**: Ranges section in C++20

**Proposed K additions**:
```k
// Additional iterator adaptors
trait IteratorExt: Iterator {
  fn zip<I: Iterator>(self, other: I) Zip<Self, I> { ... }
  fn enumerate(self) Enumerate<Self> { ... }
  fn chunk(self, size: usize) Chunk<Self> { ... }
  fn windows(self, size: usize) Windows<Self> { ... }
  fn chain<I: Iterator>(self, other: I) Chain<Self, I> { ... }
  fn flatten(self) Flatten<Self> { ... }
}
```

---

## Part 4: C++26 Features (Revisited with More Context)

See `cpp26-features-analysis.md` for full details. Key additions:

### High Priority
1. ⭐⭐⭐ **Contracts** (`pre`, `post`, `contract_assert`)
2. ⭐⭐⭐ **Sender/Receiver** (async/await)
3. ⭐⭐⭐ **Hazard Pointers + RCU** (lock-free)
4. ⭐⭐ **Linear Algebra** (`std.linalg`)

### Already Covered
- ✅ **Reflection** - K has better design
- ✅ **Pattern Matching** - K already complete

---

## Part 5: Complete Recommendations Summary

### ⭐⭐⭐ Highest Priority (Must Add)

| Feature | From | Status | Document to Create |
|---------|------|--------|-------------------|
| **Contracts** | C++26 | ❌ Missing | `contracts.md` |
| **Ranges/Iterators** | C++20 | ⚠️ Partial | `ranges-iterators.md` |
| **Async/Await + Sender/Receiver** | C++26 | ❌ Missing | `async-concurrency.md` |
| **Hazard Pointers + RCU** | C++26 | ❌ Missing | `lock-free-primitives.md` |
| **Monadic Operations** | C++23 | ❌ Missing | Update `std-library-types.md` |

### ⭐⭐ High Priority (Should Add)

| Feature | From | Status | Document to Create |
|---------|------|--------|-------------------|
| **Coroutines/Generators** | C++20/23 | ❌ Missing | `coroutines.md` |
| **Linear Algebra** | C++26 | ❌ Missing | `linear-algebra.md` |
| **std::mdspan** | C++23 | ❌ Missing | Update `std-library-types.md` |
| **Synchronization Primitives** | C++20 | ⚠️ Partial | Update `std-library-types.md` |
| **std::flat_map/set** | C++23 | ❌ Missing | Update `std-library-types.md` |

### ⭐ Medium Priority (Nice to Have)

| Feature | From | Status | Document to Create |
|---------|------|--------|-------------------|
| **Three-way comparison** | C++20 | ⚠️ Consider | Update `operators.md` |
| **Multidimensional subscript** | C++23 | ❌ Missing | Update `operators.md` |
| **Deducing this** | C++23 | ⚠️ Needs design | Explore in `traits.md` |
| **Calendar/Timezone** | C++20 | ⚠️ Basic | `std-time.md` |
| **std::stacktrace** | C++23 | ❌ Missing | Update `std-library-types.md` |
| **Bit operations** | C++20 | ⚠️ Basic | Update `std-library-types.md` |
| **@embedFile** | C++26 | ❌ Missing | `compile-time-embedding.md` |
| **Debug breakpoint** | C++26 | ❌ Missing | Update `std-library-types.md` |

### ❌ Not Needed (Already Have Better)

| Feature | From | K Has |
|---------|------|-------|
| **Concepts** | C++20 | ✅ Traits |
| **Modules** | C++20 | ✅ `@import` |
| **std::format** | C++20 | ✅ String interpolation |
| **std::span** | C++20 | ✅ Slices |
| **Designated initializers** | C++20 | ✅ Struct literals |
| **consteval/constinit** | C++20 | ✅ `comptime` |
| **if consteval** | C++23 | ✅ `comptime if` |
| **std::expected** | C++23 | ✅ `!T` |
| **std::print** | C++23 | ✅ `std.debug.print` |
| **Reflection** | C++26 | ✅ `@typeInfo()` etc |
| **Pattern Matching** | C++26 | ✅ `match` + trait-based if-let |

---

## Part 6: Proposed Implementation Order

### Phase 1: Foundation (Immediate)
1. **Contracts** - Most impactful for correctness
2. **Monadic operations** - Easy to add, high value
3. **Ranges/Iterators** - Extends existing Iterator trait

### Phase 2: Concurrency (Next)
4. **Coroutines/Generators** - Foundation for async
5. **Async/Await + Sender/Receiver** - Modern concurrency
6. **Lock-free primitives** - Hazard pointers + RCU
7. **Synchronization primitives** - Latch, Barrier, Semaphore

### Phase 3: Advanced Features (Later)
8. **Linear Algebra + mdspan** - Scientific computing
9. **std::flat_map/set** - Collection improvements
10. **Multidimensional subscript** - Better array syntax
11. **Three-way comparison** - Operator improvements

### Phase 4: Quality of Life (Nice to Have)
12. **Calendar/Timezone** - Better time handling
13. **std::stacktrace** - Better debugging
14. **@embedFile** - Compile-time resources
15. **Bit operations** - Low-level utilities

---

## Conclusion

**Key Insights**:

1. ✅ **Contracts are essential even with borrow checking** - They solve different problems
2. ✅ **K already leads in many areas**: reflection, pattern matching, comptime, error handling, borrow checking
3. ✅ **C++20/23/26 has valuable additions**: contracts, ranges, async, lock-free, monadic ops

**Next Steps**:
1. Design contracts system
2. Extend Iterator trait with range adaptors
3. Add monadic operations to Option<T> and Result<T, E>
4. Design async/await + structured concurrency
5. Add lock-free primitives
6. Add coroutines/generators

With these additions, K will be a **truly comprehensive systems programming language** combining the best of Rust, Zig, C++, and functional programming.
