# K Language

**Systems programming with predictable performance and memory safety.**

K is a low-level systems programming language that combines Zig's explicit control with Rust's compile-time safety guarantees.  
It's designed for kernel development, embedded systems, and performance-critical infrastructure where every CPU cycle counts.

## Philosophy

- **Optional hidden control flow** - What you see is what executes if you want it to
- **Explicit memory management** - All allocations are optionally visible
- **Compile-time safety** - Borrow checking without runtime cost
- **Zero-cost abstractions** - High-level features with no overhead

## Key Features

- **Comptime everything** - Powerful compile-time execution for zero-cost generics and metaprogramming
- **Optional automatic cleanup** - RAII via Drop trait, with `nodrop` for manual control
- **Explicit error handling** - Errors are values, with `?` operator for ergonomics
- **Higher-kinded types** - Advanced type system features at compile time
- **No panic unwinding** - Panics abort immediately, no hidden stack unwinding

## When to Use K

- Operating system kernels and drivers
- Embedded systems and firmware
- Real-time systems with hard timing requirements
- Performance-critical libraries and infrastructure

## The Complete Pair

K and J together form a **minimal but complete** programming environment.

**K handles the metal:**
- Operating systems and kernels
- Device drivers and firmware
- Real-time and embedded systems
- Performance-critical infrastructure
- Virtual machines and runtimes

**J handles everything else:**
- Web services and APIs
- Command-line tools
- Desktop and mobile apps
- Scripting and automation
- Plugins and extensions

**Two languages. 99.999% coverage.**

K is designed to be minimal - you only reach for it when you need absolute control. For everything else, J provides the productivity and safety you need without the systems-level complexity.
