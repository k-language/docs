// Pattern Matching Examples in K Language

const std = @import("std");

// Example 1: Basic Match Expression
const Color = enum {
    Red,
    Green,
    Blue,
};

fn match_color(color: Color) void {
    match (color) {
        .Red => std.debug.print("Color is Red\n", .{}),
        .Green => std.debug.print("Color is Green\n", .{}),
        .Blue => std.debug.print("Color is Blue\n", .{}),
    }
}

// Example 2: Match with Values
fn categorize_number(n: i32) []const u8 {
    return match (n) {
        0 => "zero",
        1 => "one",
        2 => "two",
        3...10 => "small",
        11...100 => "medium",
        else => "large",
    };
}

// Example 3: Enum with Payloads
const Result = enum {
    Ok: i32,
    Err: []const u8,
};

fn process_result(result: Result) void {
    match (result) {
        .Ok => |value| {
            std.debug.print("Success: {}\n", .{value});
        },
        .Err => |msg| {
            std.debug.print("Error: {s}\n", .{msg});
        },
    }
}

// Example 4: If Let
fn check_option(maybe: ?i32) void {
    // Direct optional unwrapping (Zig-style)
    if (maybe) |value| {
        std.debug.print("Got value: {}\n", .{value});
    } else {
        std.debug.print("No value\n", .{});
    }
}

fn check_result(result: Result) void {
    if let (.Ok = value = result) {
        std.debug.print("Processing: {}\n", .{value});
    }
}

// Example 5: While Let
const Iterator = struct {
    items: []const i32,
    index: usize,

    pub fn init(items: []const i32) Iterator {
        return Iterator{ .items = items, .index = 0 };
    }

    pub fn next(self: &mut Iterator) ?i32 {
        if (self.index >= self.items.len) return null;

        const value = self.items[self.index];
        self.index += 1;
        return value;
    }
};

fn drain_iterator() void {
    const numbers = [_]i32{1, 2, 3, 4, 5};
    var iter = Iterator.init(&numbers);

    // Direct optional unwrapping with while
    while (iter.next()) |item| {
        std.debug.print("Item: {}\n", .{item});
    }
}

// Example 6: Struct Destructuring
const Point = struct {
    x: f64,
    y: f64,
};

fn destructure_point(point: Point) void {
    const { .x = px, .y = py } = point;
    std.debug.print("Point: x={d:.2}, y={d:.2}\n", .{px, py});
}

// In function parameters
fn distance({ .x = x1, .y = y1 }: Point, { .x = x2, .y = y2 }: Point) f64 {
    const dx = x2 - x1;
    const dy = y2 - y1;
    return @sqrt(dx * dx + dy * dy);
}

// Example 7: Nested Destructuring
const Person = struct {
    name: []const u8,
    age: u32,
    address: Address,
};

const Address = struct {
    city: []const u8,
    country: []const u8,
};

fn nested_destructure(person: Person) void {
    const {
        .name = name,
        .age = age,
        .address = { .city = city, .country = country }
    } = person;

    std.debug.print("{s}, {} years old, from {s}, {s}\n",
        .{name, age, city, country});
}

// Example 8: Array Destructuring
fn destructure_array() void {
    const arr = [_]i32{1, 2, 3, 4, 5};

    match (arr) {
        [first, second, ..rest] => {
            std.debug.print("First: {}, Second: {}\n", .{first, second});
            std.debug.print("Rest has {} elements\n", .{rest.len});
        },
        else => {},
    }
}

fn match_specific_array() void {
    const arr = [_]i32{1, 2, 3};

    match (arr) {
        [1, 2, 3] => std.debug.print("Exact match!\n", .{}),
        [1, ..] => std.debug.print("Starts with 1\n", .{}),
        [.., 3] => std.debug.print("Ends with 3\n", .{}),
        else => std.debug.print("Other pattern\n", .{}),
    }
}

// Example 9: Pattern Guards
fn match_with_guard(x: i32) void {
    match (x) {
        n if (n < 0) => std.debug.print("Negative: {}\n", .{n}),
        n if (n == 0) => std.debug.print("Zero\n", .{}),
        n if (n > 0 and n < 10) => std.debug.print("Small positive: {}\n", .{n}),
        n if (n >= 10 and n < 100) => std.debug.print("Medium: {}\n", .{n}),
        n => std.debug.print("Large: {}\n", .{n}),
    }
}

// Example 10: Or Patterns
const Day = enum {
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday,
};

fn is_weekend(day: Day) bool {
    return match (day) {
        .Saturday | .Sunday => true,
        else => false,
    };
}

fn work_hours(day: Day) []const u8 {
    return match (day) {
        .Monday | .Tuesday | .Wednesday | .Thursday | .Friday => "9-5",
        .Saturday | .Sunday => "closed",
    };
}

// Example 11: Wildcard Pattern
const Point3D = struct {
    x: f64,
    y: f64,
    z: f64,
};

fn match_partial(point: Point3D) void {
    match (point) {
        { .x = 0.0, .y = _, .z = _ } => {
            std.debug.print("On YZ plane\n", .{});
        },
        { .x = _, .y = 0.0, .z = _ } => {
            std.debug.print("On XZ plane\n", .{});
        },
        { .x = _, .y = _, .z = 0.0 } => {
            std.debug.print("On XY plane\n", .{});
        },
        else => {
            std.debug.print("Arbitrary point\n", .{});
        },
    }
}

// Example 12: @ Bindings
fn process_point(point @ { .x = x, .y = y }: Point) void {
    // Both 'point' and 'x', 'y' are available
    std.debug.print("Full point: {any}\n", .{point});
    std.debug.print("Components: x={}, y={}\n", .{x, y});
}

fn match_with_binding(result: Result) void {
    match (result) {
        ok @ .Ok => |value| {
            // 'ok' is the whole Result, 'value' is the payload
            std.debug.print("Matched Ok variant: {any}\n", .{ok});
            std.debug.print("Value: {}\n", .{value});
        },
        .Err => |msg| {
            std.debug.print("Error: {s}\n", .{msg});
        },
    }
}

// Example 13: Reference Patterns
fn match_by_ref(result: &Result) void {
    match (result) {
        &.Ok => |ref val| {
            // val is &i32, not i32
            std.debug.print("Reference to ok value: {}\n", .{val.*});
        },
        &.Err => |ref msg| {
            // msg is &[]const u8
            std.debug.print("Reference to error: {s}\n", .{msg.*});
        },
    }
}

// Example 14: Complex Nested Patterns
const Message = enum {
    Quit,
    Move: Point,
    Write: []const u8,
    ChangeColor: Color,
};

fn handle_message(msg: Message) void {
    match (msg) {
        .Quit => {
            std.debug.print("Quitting\n", .{});
        },
        .Move => |{ .x = x, .y = y }| {
            std.debug.print("Moving to ({d:.2}, {d:.2})\n", .{x, y});
        },
        .Write => |text| {
            std.debug.print("Writing: {s}\n", .{text});
        },
        .ChangeColor => |color| {
            const color_name = match (color) {
                .Red => "red",
                .Green => "green",
                .Blue => "blue",
            };
            std.debug.print("Changing color to {s}\n", .{color_name});
        },
    }
}

// Example 15: Exhaustiveness Checking
fn exhaustive_match(color: Color) void {
    // Compiler ensures all variants are covered
    match (color) {
        .Red => std.debug.print("Red\n", .{}),
        .Green => std.debug.print("Green\n", .{}),
        .Blue => std.debug.print("Blue\n", .{}),
        // Removing any arm would cause compile error
    }
}

// Example 16: Match as Expression
fn sign(x: i32) i32 {
    return match (x) {
        n if (n > 0) => 1,
        n if (n < 0) => -1,
        else => 0,
    };
}

fn max(a: i32, b: i32) i32 {
    return match ((a, b)) {
        (x, y) if (x > y) => x,
        (x, y) => y,
    };
}

// Example 17: Optional Chaining
fn process_chain(opt1: ?i32, opt2: ?i32) void {
    if (opt1) |v1| {
        if (opt2) |v2| {
            std.debug.print("Both present: {} and {}\n", .{v1, v2});
        } else {
            std.debug.print("Only first present: {}\n", .{v1});
        }
    } else {
        std.debug.print("First not present\n", .{});
    }
}

// Example 18: Tuple Patterns
fn tuple_match(pair: struct { i32, i32 }) void {
    match (pair) {
        (0, 0) => std.debug.print("Origin\n", .{}),
        (0, y) => std.debug.print("On Y axis: {}\n", .{y}),
        (x, 0) => std.debug.print("On X axis: {}\n", .{x}),
        (x, y) if (x == y) => std.debug.print("Diagonal: {}\n", .{x}),
        (x, y) => std.debug.print("Point: ({}, {})\n", .{x, y}),
    }
}

// Example 19: Range Patterns with Different Types
fn categorize_age(age: u8) []const u8 {
    return match (age) {
        0...2 => "baby",
        3...12 => "child",
        13...19 => "teenager",
        20...39 => "young adult",
        40...59 => "middle-aged",
        60...255 => "senior",
    };
}

fn categorize_temperature(temp: f32) []const u8 {
    return match (temp) {
        t if (t < 0.0) => "freezing",
        t if (t >= 0.0 and t < 15.0) => "cold",
        t if (t >= 15.0 and t < 25.0) => "comfortable",
        t if (t >= 25.0 and t < 35.0) => "warm",
        t => "hot",
    };
}

// Example 20: Advanced Result Handling
const FileError = error {
    NotFound,
    PermissionDenied,
    AlreadyExists,
};

fn handle_file_result(result: !void) void {
    result catch |err| {
        match (err) {
            error.NotFound => {
                std.debug.print("File not found\n", .{});
            },
            error.PermissionDenied => {
                std.debug.print("Permission denied\n", .{});
            },
            error.AlreadyExists => {
                std.debug.print("File already exists\n", .{});
            },
            else => {
                std.debug.print("Unknown error\n", .{});
            },
        }
    };
}

pub fn main() void {
    std.debug.print("=== Pattern Matching Examples ===\n\n", .{});

    std.debug.print("1. Basic match:\n", .{});
    match_color(.Red);
    match_color(.Green);

    std.debug.print("\n2. Match with values:\n", .{});
    std.debug.print("5 is {s}\n", .{categorize_number(5)});
    std.debug.print("50 is {s}\n", .{categorize_number(50)});
    std.debug.print("500 is {s}\n", .{categorize_number(500)});

    std.debug.print("\n3. Enum with payloads:\n", .{});
    const ok_result = Result{ .Ok = 42 };
    const err_result = Result{ .Err = "something went wrong" };
    process_result(ok_result);
    process_result(err_result);

    std.debug.print("\n4. If let:\n", .{});
    check_option(42);
    check_option(null);

    std.debug.print("\n5. While let:\n", .{});
    drain_iterator();

    std.debug.print("\n6. Struct destructuring:\n", .{});
    const p = Point{ .x = 3.0, .y = 4.0 };
    destructure_point(p);

    std.debug.print("\n7. Nested destructuring:\n", .{});
    const person = Person{
        .name = "Alice",
        .age = 30,
        .address = Address{
            .city = "Seoul",
            .country = "Korea",
        },
    };
    nested_destructure(person);

    std.debug.print("\n8. Array destructuring:\n", .{});
    destructure_array();
    match_specific_array();

    std.debug.print("\n9. Pattern guards:\n", .{});
    match_with_guard(-5);
    match_with_guard(5);
    match_with_guard(50);

    std.debug.print("\n10. Or patterns:\n", .{});
    std.debug.print("Saturday is weekend: {}\n", .{is_weekend(.Saturday)});
    std.debug.print("Monday is weekend: {}\n", .{is_weekend(.Monday)});

    std.debug.print("\n11. Messages:\n", .{});
    handle_message(Message.Quit);
    handle_message(Message{ .Move = Point{ .x = 10.0, .y = 20.0 } });
    handle_message(Message{ .Write = "Hello!" });
    handle_message(Message{ .ChangeColor = .Blue });

    std.debug.print("\nAll pattern matching examples completed!\n", .{});
}
