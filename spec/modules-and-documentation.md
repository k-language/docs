# Modules and Documentation in K Language

## Module System

K uses a file-based module system similar to Zig, with visibility control similar to Rust.

### Basic Module Structure

```k
// src/main.k
const std = @import("std");
const utils = @import("utils.k");
const math = @import("math/mod.k");

pub fn main() !void {
    const result = utils.calculate(42);
    const value = math.sqrt(16.0);
}
```

### File Organization

```
project/
├── src/
│   ├── main.k          # Entry point
│   ├── utils.k         # Utility module
│   ├── math/
│   │   ├── mod.k       # Module root
│   │   ├── vector.k    # Submodule
│   │   └── matrix.k    # Submodule
│   └── lib.k           # Library root
└── build.k             # Build configuration
```

### Visibility

K uses Rust-style visibility modifiers:

```k
// Default: private to module
fn internal_function() void {
    // Not visible outside this file
}

const INTERNAL_CONSTANT: i32 = 42;

// Public: visible to parent modules
pub fn public_function() void {
    // Visible to importers
}

pub const PUBLIC_CONSTANT: i32 = 100;

// Public to crate (entire project)
pub(crate) fn crate_function() void {
    // Visible anywhere in this crate
}

// Public to parent module
pub(super) fn parent_function() void {
    // Visible to parent module only
}

// Public within specific path
pub(in crate::utils) fn scoped_function() void {
    // Visible within utils module tree
}
```

### Module Declaration

```k
// math/mod.k
pub const vector = @import("vector.k");
pub const matrix = @import("matrix.k");

pub fn sqrt(x: f64) f64 {
    @sqrt(x)
}

// Re-export from submodules
pub const Vec3 = vector.Vec3;
pub const Mat4 = matrix.Mat4;
```

### Submodules

```k
// math/vector.k
const std = @import("std");

pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn new(x: f64, y: f64, z: f64) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn dot(self: &Vec3, other: &Vec3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }
};

// Private helper
fn internal_normalize(v: &Vec3) Vec3 {
    // Implementation
}
```

### Use Declarations

```k
// Import specific items
const { Vec3, Mat4 } = @import("math/mod.k");

// Import with alias
const utils = @import("utils.k");
const my_utils = @import("my_utils.k");

// Import everything (not recommended)
const std = @import("std");
const * = std.mem;  // All from std.mem
```

### Conditional Compilation

```k
// Platform-specific modules
const platform = switch (@import("builtin").os.tag) {
    .linux => @import("platform/linux.k"),
    .windows => @import("platform/windows.k"),
    .macos => @import("platform/macos.k"),
    else => @compileError("Unsupported platform"),
};

pub fn platform_specific() void {
    platform.init();
}
```

### Circular Dependencies

K detects circular module dependencies at compile time:

```k
// a.k
const b = @import("b.k");

pub fn function_a() void {
    b.function_b();
}

// b.k
const a = @import("a.k");  // ERROR: Circular dependency

pub fn function_b() void {
    a.function_a();
}
```

### Module Initialization

```k
// Modules can have initialization code
const allocator = init: {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    break :init gpa.allocator();
};

// Runs at module load time
comptime {
    std.debug.print("Module loading\n", .{});
}
```

## Documentation System

K provides a comprehensive documentation system with rustdoc-style comments.

### Documentation Comments

```k
/// Documentation comment for the following item.
/// Supports **markdown** formatting.
///
/// # Examples
///
/// ```k
/// const result = add(2, 3);
/// assert(result == 5);
/// ```
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

//! Module-level documentation.
//! Placed at the top of the file.
//!
//! # Overview
//!
//! This module provides mathematical utilities.
```

### Documentation Sections

```k
/// A growable array type.
///
/// # Type Parameters
///
/// * `T` - The type of elements stored in the vector
///
/// # Examples
///
/// ```k
/// var vec = Vec(i32).init(allocator);
/// defer vec.deinit();
///
/// try vec.push(1);
/// try vec.push(2);
/// try vec.push(3);
/// ```
///
/// # Safety
///
/// This type is `Send` and `Sync` if `T` is `Send` and `Sync`.
///
/// # Performance
///
/// Push operations are O(1) amortized.
///
/// # Panics
///
/// Methods may panic if allocation fails and the allocator
/// doesn't return an error.
pub fn Vec(comptime T: type) type {
    return struct {
        // Implementation
    };
}
```

### Common Documentation Sections

- `# Examples` - Usage examples (tested by doctest)
- `# Panics` - When the function panics
- `# Errors` - Error conditions
- `# Safety` - Safety requirements for unsafe code
- `# Performance` - Performance characteristics
- `# Type Parameters` - Generic parameter descriptions
- `# Lifetimes` - Lifetime parameter descriptions

### Documenting Struct Fields

```k
pub const Config = struct {
    /// The host address to bind to.
    ///
    /// Defaults to "127.0.0.1".
    host: []const u8,

    /// The port to listen on.
    ///
    /// Must be in range 1-65535.
    port: u16,

    /// Maximum number of concurrent connections.
    max_connections: usize,
};
```

### Documenting Enums

```k
/// Represents the result of an operation.
pub const Result = enum {
    /// The operation succeeded.
    Ok: T,

    /// The operation failed with an error.
    Err: E,
};
```

### Inline Code and Links

```k
/// Returns the square root of `x`.
///
/// Uses the `@sqrt` builtin for calculation.
/// See also: [`pow`] for exponentiation.
///
/// Calling `sqrt(4.0)` returns `2.0`.
pub fn sqrt(x: f64) f64 {
    return @sqrt(x);
}

/// Raises `base` to the power of `exp`.
///
/// See also: [`sqrt`]
pub fn pow(base: f64, exp: f64) f64 {
    // Implementation
}
```

## Documentation Testing (Doctest)

K includes a doctest system that automatically tests code examples in documentation:

### Basic Doctest

```k
/// Adds two numbers together.
///
/// # Examples
///
/// ```k
/// const result = add(2, 3);
/// assert(result == 5);
/// ```
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

When you run `k test`, this example is extracted and compiled as:

```k
test "add example" {
    const result = add(2, 3);
    assert(result == 5);
}
```

### Doctest with Setup

```k
/// A simple stack implementation.
///
/// # Examples
///
/// ```k
/// var stack = Stack(i32).init(allocator);
/// defer stack.deinit();
///
/// try stack.push(1);
/// try stack.push(2);
///
/// const top = stack.pop();
/// try std.testing.expectEqual(2, top);
/// ```
pub fn Stack(comptime T: type) type {
    // Implementation
}
```

### Doctest Attributes

```k
/// This example should compile but not run.
///
/// ```k,no_run
/// const file = try std.fs.cwd().openFile("missing.txt", .{});
/// defer file.close();
/// ```
pub fn open_file() void {}

/// This example should fail to compile.
///
/// ```k,should_fail
/// const x: i32 = "not a number";  // Type error
/// ```
pub fn type_checking_example() void {}

/// This example is ignored.
///
/// ```k,ignore
/// // Platform-specific code that might not compile everywhere
/// const win32 = @import("windows");
/// ```
pub fn platform_specific() void {}
```

### Testing Error Handling

```k
/// Attempts to parse an integer from a string.
///
/// # Examples
///
/// ```k
/// const value = try parse_int("42");
/// try std.testing.expectEqual(42, value);
///
/// const err = parse_int("not a number");
/// try std.testing.expectError(error.InvalidFormat, err);
/// ```
pub fn parse_int(str: []const u8) !i32 {
    // Implementation
}
```

### Hidden Lines in Doctests

```k
/// Multiplies two numbers.
///
/// # Examples
///
/// ```k
/// # const allocator = std.testing.allocator;
/// # var arena = std.heap.ArenaAllocator.init(allocator);
/// # defer arena.deinit();
/// const result = multiply(6, 7);
/// assert(result == 42);
/// ```
pub fn multiply(a: i32, b: i32) i32 {
    return a * b;
}
```

Lines starting with `#` are included in the test but hidden from documentation.

### Module-Level Doctests

```k
//! Utility functions for string manipulation.
//!
//! # Examples
//!
//! ```k
//! const std = @import("std");
//! const strings = @import("strings.k");
//!
//! pub fn main() !void {
//!     const result = strings.reverse("hello");
//!     std.debug.print("{s}\n", .{result});
//! }
//! ```
```

## Generating Documentation

### Command Line

```bash
# Generate HTML documentation
k doc

# Generate and open in browser
k doc --open

# Generate for specific module
k doc src/math/mod.k

# Include private items
k doc --document-private-items

# Generate JSON output (for tools)
k doc --output-format json
```

### Documentation Configuration

```k
// build.k
const std = @import("std");

pub fn build(b: *std.Build) void {
    const doc = b.addDoc("mylib", .{
        .root_source_file = .{ .path = "src/lib.k" },
        .title = "My Library Documentation",
        .include_private = false,
    });

    b.default_step.dependOn(&doc.step);
}
```

### Documentation Structure

Generated documentation includes:

- **Module overview** from `//!` comments
- **API reference** for all public items
- **Search functionality**
- **Source code links**
- **Tested examples** (marked with ✓)

## Advanced Features

### Intra-doc Links

```k
/// Computes the [`distance`] between two points.
///
/// Uses [`Vec3::dot`] internally.
///
/// See also: [`crate::math::vector`]
pub fn distance(a: &Vec3, b: &Vec3) f64 {
    // Implementation
}
```

### Doc Aliases

```k
/// This function is also known as "len".
#[doc(alias = "len")]
#[doc(alias = "size")]
pub fn length(slice: []const u8) usize {
    return slice.len;
}
```

### Feature Gates in Documentation

```k
/// Only available with the "advanced" feature.
///
/// ```k,feature = "advanced"
/// const result = advanced_feature();
/// ```
#[cfg(feature = "advanced")]
pub fn advanced_feature() void {}
```

### Documentation Coverage

```bash
# Check documentation coverage
k doc --coverage

# Fail if coverage is below threshold
k doc --coverage --coverage-threshold 80
```

## Comparison with Rust and Zig

| Feature | Rust | Zig | K |
|---------|------|-----|---|
| Module system | File-based + mod.rs | File-based | File-based |
| Visibility control | pub, pub(crate), etc. | pub only | pub, pub(crate), pub(super) |
| Documentation comments | /// and //! | /// and //! | /// and //! |
| Doctest | Yes | No | Yes |
| Generated docs | rustdoc (HTML) | autodoc (HTML) | kdoc (HTML/JSON) |
| Intra-doc links | Yes | Limited | Yes |
| Doc coverage | Yes | No | Yes |

## Best Practices

### Module Organization

1. **One module per file** - Keep modules focused
2. **Use mod.k for aggregation** - Re-export public API
3. **Minimize pub(crate)** - Prefer proper module boundaries
4. **Group related functionality** - Organize by feature, not type

### Documentation

1. **Document all public APIs** - No exceptions
2. **Include examples** - Show real usage
3. **Test your examples** - Use doctest
4. **Link related items** - Use intra-doc links
5. **Describe invariants** - Especially for unsafe code

### Doctests

1. **Keep examples focused** - One concept per example
2. **Use hidden lines** - Hide boilerplate setup
3. **Test error cases** - Show both success and failure
4. **Mark platform-specific** - Use attributes appropriately

## Example: Complete Module with Documentation

```k
//! Network utility functions.
//!
//! This module provides utilities for working with network addresses
//! and connections.
//!
//! # Examples
//!
//! ```k
//! const net = @import("network.k");
//!
//! const addr = try net.parse_address("192.168.1.1:8080");
//! std.debug.print("Host: {s}, Port: {}\n", .{addr.host, addr.port});
//! ```

const std = @import("std");

/// A network address with host and port.
pub const Address = struct {
    /// The host component (IP or hostname).
    host: []const u8,

    /// The port number (1-65535).
    port: u16,

    /// Creates a new address.
    ///
    /// # Examples
    ///
    /// ```k
    /// const addr = Address.new("localhost", 8080);
    /// try std.testing.expectEqualStrings("localhost", addr.host);
    /// try std.testing.expectEqual(8080, addr.port);
    /// ```
    pub fn new(host: []const u8, port: u16) Address {
        return Address{ .host = host, .port = port };
    }
};

/// Parses a network address from a string.
///
/// # Format
///
/// The string must be in the format `host:port` where:
/// - `host` is an IP address or hostname
/// - `port` is a number from 1 to 65535
///
/// # Examples
///
/// ```k
/// const addr = try parse_address("127.0.0.1:3000");
/// try std.testing.expectEqualStrings("127.0.0.1", addr.host);
/// try std.testing.expectEqual(3000, addr.port);
/// ```
///
/// # Errors
///
/// Returns an error if:
/// - The string doesn't contain a colon
/// - The port is not a valid number
/// - The port is out of range
///
/// ```k
/// try std.testing.expectError(
///     error.InvalidFormat,
///     parse_address("invalid"),
/// );
/// ```
pub fn parse_address(str: []const u8) !Address {
    // Implementation
}

// Tests (run with `k test`)
test "parse_address with valid input" {
    const addr = try parse_address("192.168.1.1:8080");
    try std.testing.expectEqualStrings("192.168.1.1", addr.host);
    try std.testing.expectEqual(8080, addr.port);
}

test "parse_address with invalid input" {
    try std.testing.expectError(
        error.InvalidFormat,
        parse_address("no-port"),
    );
}
```

## References

- [Rust Module System](https://doc.rust-lang.org/book/ch07-00-managing-growing-projects-with-packages-crates-and-modules.html)
- [rustdoc Documentation](https://doc.rust-lang.org/rustdoc/)
- [Zig Build System](https://ziglang.org/learn/build-system/)
- [Documentation Best Practices](https://rust-lang.github.io/api-guidelines/documentation.html)
