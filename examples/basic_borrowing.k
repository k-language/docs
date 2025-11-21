// Basic Borrowing Examples in K Language

const std = @import("std");

// Example 1: Immutable Borrowing
// Multiple immutable references are allowed simultaneously
fn immutable_borrowing_example() void {
    var data = [_]u8{1, 2, 3, 4, 5};

    // Create multiple immutable references
    const ref1: &[u8] = &data;
    const ref2: &[u8] = &data;
    const ref3: &[u8] = &data;

    // All can read simultaneously
    std.debug.print("ref1[0] = {}\n", .{ref1[0]});
    std.debug.print("ref2[1] = {}\n", .{ref2[1]});
    std.debug.print("ref3[2] = {}\n", .{ref3[2]});
}

// Example 2: Mutable Borrowing
// Only one mutable reference allowed at a time
fn mutable_borrowing_example() void {
    var counter: i32 = 0;

    {
        const mut_ref = &mut counter;
        mut_ref.* += 1;
        std.debug.print("Counter: {}\n", .{mut_ref.*});
    } // mut_ref goes out of scope

    {
        const another_mut_ref = &mut counter;
        another_mut_ref.* += 1;
        std.debug.print("Counter: {}\n", .{another_mut_ref.*});
    } // another_mut_ref goes out of scope

    std.debug.print("Final: {}\n", .{counter});
}

// Example 3: Borrowing Rules Enforcement
fn borrowing_rules_example() void {
    var numbers = [_]i32{1, 2, 3, 4, 5};

    // Multiple immutable borrows - OK
    const view1 = &numbers;
    const view2 = &numbers;
    sum(view1);
    sum(view2);

    // Single mutable borrow - OK
    const mut_view = &mut numbers;
    increment_all(mut_view);

    // ERROR: Cannot have both immutable and mutable borrows
    // const read_view = &numbers;      // Immutable borrow
    // const write_view = &mut numbers; // ERROR: Cannot borrow as mutable
}

fn sum(slice: &[i32]) i32 {
    var total: i32 = 0;
    for (slice) |num| {
        total += num;
    }
    return total;
}

fn increment_all(slice: &mut [i32]) void {
    for (slice) |*num| {
        num.* += 1;
    }
}

// Example 4: Freezing During Borrow
fn freezing_example() void {
    var temperature: f32 = 20.0;

    // Create immutable reference - freezes the original
    const temp_ref = &temperature;

    // ERROR: Cannot modify while immutably borrowed
    // temperature = 25.0;  // Compile error!

    std.debug.print("Temperature: {}\n", .{temp_ref.*});

    // Borrow ends here - can modify again
    temperature = 25.0;
    std.debug.print("New temperature: {}\n", .{temperature});
}

// Example 5: Scope-Based Borrowing
fn scope_based_example() void {
    var buffer = [_]u8{0} ** 100;

    {
        // First mutable borrow
        const writer1 = &mut buffer[0..50];
        fill_pattern(writer1, 0xAA);
    } // writer1 scope ends

    {
        // Second mutable borrow - allowed because previous ended
        const writer2 = &mut buffer[50..100];
        fill_pattern(writer2, 0xBB);
    } // writer2 scope ends

    // Now we can read the entire buffer
    const reader = &buffer;
    print_hex(reader);
}

fn fill_pattern(slice: &mut [u8], pattern: u8) void {
    for (slice) |*byte| {
        byte.* = pattern;
    }
}

fn print_hex(slice: &[u8]) void {
    for (slice) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});
}

// Example 6: Returning References
// The returned reference must have a valid lifetime
fn get_first_element(slice: &[i32]) &i32 {
    return &slice[0];
}

// ERROR: Cannot return reference to local variable
// fn dangling_reference() &i32 {
//     const local: i32 = 42;
//     return &local;  // ERROR: local is dropped at function end
// }

// Example 7: Struct with Borrowed Data
const Parser = struct {
    input: &[u8],
    position: usize,

    pub fn init(input: &[u8]) Parser {
        return Parser{
            .input = input,
            .position = 0,
        };
    }

    pub fn peek(self: &Parser) ?u8 {
        if (self.position >= self.input.len) return null;
        return self.input[self.position];
    }

    pub fn advance(self: &mut Parser) void {
        if (self.position < self.input.len) {
            self.position += 1;
        }
    }

    pub fn slice(self: &Parser) &[u8] {
        return self.input[self.position..];
    }
};

fn parser_example() void {
    const input = "Hello, World!";

    var parser = Parser.init(input);

    while (parser.peek()) |ch| {
        std.debug.print("{c}", .{ch});
        parser.advance();
    }
    std.debug.print("\n", .{});
}

pub fn main() void {
    std.debug.print("=== Immutable Borrowing ===\n", .{});
    immutable_borrowing_example();

    std.debug.print("\n=== Mutable Borrowing ===\n", .{});
    mutable_borrowing_example();

    std.debug.print("\n=== Scope-Based Borrowing ===\n", .{});
    scope_based_example();

    std.debug.print("\n=== Parser Example ===\n", .{});
    parser_example();
}
