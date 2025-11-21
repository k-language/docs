// Lifetime Examples in K Language
// Demonstrates lifetime annotations, elision, and lifetime bounds

const std = @import("std");

// Example 1: Basic Lifetime Annotation
// The returned reference has the same lifetime as the input
fn first_word<'a>(text: &'a []const u8) &'a []const u8 {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text.*[i] == ' ') {
            return &text.*[0..i];
        }
    }
    return text.*;
}

// Example 2: Multiple Lifetime Parameters
// Returned reference can come from either parameter, both need same lifetime
fn longest<'a>(x: &'a []const u8, y: &'a []const u8) &'a []const u8 {
    if (x.len > y.len) {
        return x.*;
    } else {
        return y.*;
    }
}

// Example 3: Different Lifetimes
// When returned reference clearly comes from one parameter
fn first_or_default<'a, 'b>(
    first: &'a []const u8,
    default: &'b []const u8,
    use_first: bool
) &'a []const u8 {
    // Can only return 'a, not 'b
    if (use_first) {
        return first.*;
    } else {
        // This would be an error - cannot return 'b when 'a is expected
        // return default.*;
        return first.*;
    }
}

// Example 4: Lifetime Elision
// No annotations needed - compiler infers the lifetime
fn get_middle(slice: &[i32]) &i32 {
    const mid = slice.len / 2;
    return &slice[mid];
}

// Equivalent explicit form:
fn get_middle_explicit<'a>(slice: &'a [i32]) &'a i32 {
    const mid = slice.len / 2;
    return &slice[mid];
}

// Example 5: Struct with Lifetime
// The struct holds a reference, so it needs a lifetime parameter
const Parser<'a> = struct {
    input: &'a []const u8,
    position: usize,

    pub fn init(input: &'a []const u8) Parser<'a> {
        return Parser<'a>{
            .input = input,
            .position = 0,
        };
    }

    pub fn current(self: &Parser<'a>) ?u8 {
        if (self.position >= self.input.len) return null;
        return self.input.*[self.position];
    }

    pub fn advance(self: &mut Parser<'a>) void {
        if (self.position < self.input.len) {
            self.position += 1;
        }
    }

    // Method returns a reference with the same lifetime as the struct's data
    pub fn remaining(self: &Parser<'a>) &'a []const u8 {
        return &self.input.*[self.position..];
    }
};

fn parser_lifetime_example() void {
    std.debug.print("=== Parser Lifetime Example ===\n", .{});

    const text = "Hello World";
    var parser = Parser.init(&text);

    while (parser.current()) |ch| {
        std.debug.print("{c}", .{ch});
        parser.advance();
    }
    std.debug.print("\n", .{});

    // ERROR: Cannot do this because parser holds a reference to text
    // If text were to be freed here, parser would have a dangling reference
}

// Example 6: Multiple Structs with Related Lifetimes
const Context<'a> = struct {
    data: &'a []const u8,
};

const Processor<'a> = struct {
    context: &'a Context<'a>,
    position: usize,

    pub fn init(ctx: &'a Context<'a>) Processor<'a> {
        return Processor<'a>{
            .context = ctx,
            .position = 0,
        };
    }

    pub fn get_data(self: &Processor<'a>) &'a []const u8 {
        return self.context.data;
    }
};

// Example 7: Static Lifetime
// 'static means the reference lives for the entire program
const GLOBAL_MESSAGE: &'static []const u8 = "This lives forever";

fn get_static_string() &'static []const u8 {
    return GLOBAL_MESSAGE;
}

// Example 8: Lifetime Bounds in Generic Functions
fn process_slice<'a, T>(
    slice: &'a []T,
    predicate: fn(&T) bool
) ?&'a T {
    for (slice.*) |*item| {
        if (predicate(item)) {
            return item;
        }
    }
    return null;
}

fn is_positive(x: &i32) bool {
    return x.* > 0;
}

// Example 9: Iterator with Lifetime
const SliceIterator<'a, T> = struct {
    slice: &'a []T,
    index: usize,

    pub fn init(slice: &'a []T) SliceIterator<'a, T> {
        return SliceIterator<'a, T>{
            .slice = slice,
            .index = 0,
        };
    }

    pub fn next(self: &mut SliceIterator<'a, T>) ?&'a T {
        if (self.index >= self.slice.len) return null;

        const item = &self.slice.*[self.index];
        self.index += 1;
        return item;
    }
};

fn iterator_lifetime_example() void {
    std.debug.print("\n=== Iterator Lifetime Example ===\n", .{});

    const numbers = [_]i32{1, 2, 3, 4, 5};
    var iter = SliceIterator(i32).init(&numbers);

    while (iter.next()) |num| {
        std.debug.print("{} ", .{num.*});
    }
    std.debug.print("\n", .{});
}

// Example 10: Lifetime Subtyping
// 'a must outlive 'b (written as 'a: 'b)
const Holder<'a, 'b> = struct
    where 'a: 'b  // 'a must outlive 'b
{
    long_lived: &'a []const u8,
    short_lived: &'b []const u8,

    pub fn get_long(self: &Holder<'a, 'b>) &'a []const u8 {
        return self.long_lived.*;
    }

    pub fn get_short(self: &Holder<'a, 'b>) &'b []const u8 {
        return self.short_lived.*;
    }
};

// Example 11: Complex Lifetime Scenarios
const nodrop StringPool<'a> = struct {
    arena: &'a std.heap.ArenaAllocator,

    pub fn init(arena: &'a std.heap.ArenaAllocator) StringPool<'a> {
        return StringPool<'a>{ .arena = arena };
    }

    pub fn alloc_string(self: &StringPool<'a>, content: []const u8) !&'a []u8 {
        const allocator = self.arena.allocator();
        return try allocator.dupe(u8, content);
    }

    // All strings allocated through this pool live as long as the arena
};

// Example 12: Lifetime in Trait Implementations
trait Formatter<'a> {
    fn format(self: &Self, output: &'a mut []u8) ![]const u8;
}

impl<'a> Formatter<'a> for i32 {
    fn format(self: &i32, output: &'a mut []u8) ![]const u8 {
        return std.fmt.bufPrint(output, "{}", .{self.*});
    }
}

// Example 13: Function Pointers with Lifetimes
const Callback<'a> = fn(&'a []const u8) void;

fn register_callback<'a>(
    data: &'a []const u8,
    callback: Callback<'a>
) void {
    callback(data);
}

fn print_data(data: &[]const u8) void {
    std.debug.print("Data: {s}\n", .{data.*});
}

// Example 14: Avoiding Lifetime Issues
// BAD: This would not compile
// fn broken_reference() &[]const u8 {
//     const local = "local string";
//     return &local;  // ERROR: returning reference to local variable
// }

// GOOD: Return owned data or use 'static
fn working_reference() []const u8 {
    return "static string";  // String literal has 'static lifetime
}

fn working_reference_static() &'static []const u8 {
    const STATIC_DATA: &'static []const u8 = "static";
    return STATIC_DATA;
}

// Example 15: Practical Example - Configuration Parser
const Config<'a> = struct {
    source: &'a []const u8,
    values: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: &'a []const u8) Config<'a> {
        return Config<'a>{
            .source = source,
            .values = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: &mut Config<'a>) void {
        self.values.deinit();
    }

    // Returns slices into the original source - tied to lifetime 'a
    pub fn get_value(self: &Config<'a>, key: []const u8) ?&'a []const u8 {
        if (self.values.get(key)) |value| {
            // Assuming value points into source
            return &value;
        }
        return null;
    }

    pub fn parse(self: &mut Config<'a>) !void {
        var lines = std.mem.split(u8, self.source.*, "\n");

        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "=")) |eq_pos| {
                const key = std.mem.trim(u8, line[0..eq_pos], " \t");
                const value = std.mem.trim(u8, line[eq_pos + 1..], " \t");

                try self.values.put(key, value);
            }
        }
    }
};

fn config_example(allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Config Lifetime Example ===\n", .{});

    const config_source =
        \\host = localhost
        \\port = 8080
        \\debug = true
    ;

    var config = Config.init(allocator, &config_source);
    defer config.deinit();

    try config.parse();

    if (config.get_value("host")) |host| {
        std.debug.print("Host: {s}\n", .{host.*});
    }

    if (config.get_value("port")) |port| {
        std.debug.print("Port: {s}\n", .{port.*});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Lifetime Examples ===\n\n", .{});

    const text = "Hello World from K Language";
    const word = first_word(&text);
    std.debug.print("First word: {s}\n", .{word});

    const str1 = "short";
    const str2 = "much longer string";
    const longer = longest(&str1, &str2);
    std.debug.print("Longest: {s}\n", .{longer});

    parser_lifetime_example();
    iterator_lifetime_example();

    const numbers = [_]i32{-3, -1, 2, 5, -7, 9};
    if (process_slice(i32, &numbers, is_positive)) |first_pos| {
        std.debug.print("\nFirst positive number: {}\n", .{first_pos.*});
    }

    try config_example(allocator);

    std.debug.print("\n=== All lifetime examples completed ===\n", .{});
}
