# String Literals and Comments Design

## Overview

This document specifies K's string literal and comment syntax, including nested comments, raw strings, and multi-line strings.

## Comments

### Single-Line Comments

```k
// This is a single-line comment

/// Documentation comment for the following item
pub fn example() void {}

//! Module-level documentation comment
```

### Multi-Line Comments (Nested)

**Design**: K supports **nested multi-line comments** like Rust and Swift.

```k
/* This is a multi-line comment */

/*
 * Multi-line comment
 * spanning multiple lines
 */

/* Outer comment
   /* Nested comment */
   Back to outer comment
*/
```

**Why nested?**
- ✅ Easy to comment out blocks containing comments
- ✅ Safer than C-style /* */ (which don't nest)
- ✅ Proven in Rust, Swift, D

**Example use case**:
```k
/*  // Comment out this entire block
fn debug_function() void {
    /* Some nested comment explaining implementation */
    std.debug.print("Debug output\n", .{});
}
*/
```

**Implementation**:
- Track nesting depth counter
- Increment on `/*`
- Decrement on `*/`
- Comment ends when depth reaches 0

---

## String Literals

### Regular Strings

**Standard string literals** with escape sequences:

```k
const hello = "Hello, world!";
const newline = "Line 1\nLine 2";
const tab = "Column1\tColumn2";
const quote = "He said \"Hello\"";
const backslash = "Path: C:\\Users\\name";
const unicode = "Unicode: \u{1F600}"; // 😀
```

**Escape sequences**:
```k
\n      // Newline
\r      // Carriage return
\t      // Tab
\\      // Backslash
\"      // Double quote
\'      // Single quote
\0      // Null byte
\x7F    // Hex escape (2 digits)
\u{10FFFF}  // Unicode escape (1-6 hex digits)
```

---

### Raw Strings (Rust-Style)

**Design**: Raw strings with customizable delimiters (like Rust).

**Basic raw string** (no escapes):
```k
const path = r"C:\Users\name\Documents";  // No need to escape \

const regex = r"^\d{3}-\d{2}-\d{4}$";  // No need to escape regex characters
```

**Raw string with `#` delimiters**:
```k
// Use when string contains "
const json = r#"{"name": "value"}"#;

// Multiple # for nesting
const nested = r##"String with "# inside"##;

// Arbitrary nesting depth
const deeply_nested = r###"Contains r##"..."## inside"###;
```

**Syntax**:
- `r"..."` - Basic raw string (no escapes)
- `r#"..."#` - Raw string with one `#` delimiter
- `r##"..."##` - Raw string with two `#` delimiters
- `r###"..."###` - And so on...

**Matching rule**: Opening and closing must have same number of `#`

**Examples**:
```k
// Windows path
const path = r"C:\Program Files\MyApp\config.ini";

// Regex pattern
const email_regex = r"^[\w\.-]+@[\w\.-]+\.\w+$";

// JSON literal
const json_data = r#"{
    "name": "John",
    "age": 30,
    "email": "john@example.com"
}"#;

// SQL query
const sql = r#"
    SELECT * FROM users
    WHERE name LIKE '%John%'
    AND age > 18
"#;

// Nested raw strings
const template = r##"
    const inner = r#"Some "quoted" text"#;
    std.debug.print("{s}\n", .{inner});
"##;
```

**Why raw strings?**
- ✅ No need to escape `\` in paths
- ✅ Easier regex patterns
- ✅ Cleaner JSON/XML/SQL literals
- ✅ Proven in Rust, Swift, C#

---

### Multi-Line Strings

**Design**: Multi-line strings with automatic indentation trimming (like Swift, Kotlin).

**Using triple quotes** `"""..."""`:
```k
const multiline = """
    This is a multi-line string.
    It can span multiple lines.
    Leading whitespace is trimmed based on closing delimiter.
    """;

// With indentation trimming
fn example() void {
    const message = """
        Hello,
        This is indented correctly.
        All lines are aligned.
        """;

    // Equivalent to: "Hello,\nThis is indented correctly.\nAll lines are aligned."
}
```

**Indentation rules**:
1. Find indentation of closing `"""`
2. Remove that much indentation from all lines
3. First and last lines (if empty) are removed

**Example**:
```k
const html = """
    <html>
        <body>
            <h1>Hello, World!</h1>
        </body>
    </html>
    """;

// Result:
// "<html>\n    <body>\n        <h1>Hello, World!</h1>\n    </body>\n</html>"
```

**With escape sequences**:
```k
const text = """
    Line 1\n
    Line 2 with \t tab
    Unicode: \u{1F600}
    """;
```

**Raw multi-line strings**:
```k
const raw_multiline = r"""
    No escapes here: \n \t
    All literal characters
    """;

// With # delimiter
const raw_with_quotes = r#"""
    Contains """ inside
    """#;
```

**Why multi-line strings?**
- ✅ Cleaner than concatenation
- ✅ Preserves formatting (code, templates)
- ✅ Automatic indentation handling
- ✅ Proven in Swift, Kotlin, Python

---

### String Interpolation

**Design**: String interpolation with `{}` placeholders (like Rust's `format!` but built-in).

**Basic interpolation**:
```k
const name = "Alice";
const age = 30;

const message = "Hello, {name}! You are {age} years old.";
// "Hello, Alice! You are 30 years old."
```

**With expressions**:
```k
const x = 5;
const y = 10;

const result = "Sum: {x + y}, Product: {x * y}";
// "Sum: 15, Product: 50"
```

**Formatting specifiers**:
```k
const pi = 3.14159;

const formatted = "Pi: {pi:.2}";  // "Pi: 3.14"
const hex = "Hex: {255:x}";        // "Hex: ff"
const binary = "Binary: {15:b}";   // "Binary: 1111"
```

**Escaping braces**:
```k
const literal_braces = "Use {{ and }} for literal braces";
// "Use { and } for literal braces"
```

**In multi-line strings**:
```k
const user = .{ .name = "Bob", .age = 25 };

const template = """
    User Profile:
    Name: {user.name}
    Age: {user.age}
    """;
```

**In raw strings** (NO interpolation):
```k
const raw = r"No interpolation: {name}";
// Literal: "No interpolation: {name}"

// If you need interpolation in raw strings, use regular string
const interpolated = "Regex: {regex_pattern}";
```

**Why string interpolation?**
- ✅ More readable than format!()
- ✅ Type-checked at compile time
- ✅ Common in modern languages (Swift, Kotlin, C#)

---

### Byte Strings

**Design**: Byte string literals (like Rust `b"..."`).

**Basic byte string**:
```k
const bytes: []const u8 = b"Hello";
// [72, 101, 108, 108, 111]

const null_terminated: [*:0]const u8 = b"C string\0";
```

**Raw byte strings**:
```k
const raw_bytes = br"No escapes: \n \t";
const raw_bytes_delim = br#"Contains "# in bytes"#;
```

**Why byte strings?**
- ✅ Explicit byte vs string distinction
- ✅ FFI with C (null-terminated)
- ✅ Network protocols (binary data)
- ✅ No UTF-8 validation overhead

---

### Character Literals

**Design**: Single characters with `'...'` (like Rust).

**Basic characters**:
```k
const letter: u8 = 'A';      // ASCII
const unicode: u21 = '😀';   // Unicode scalar (21-bit)
```

**With escapes**:
```k
const newline: u8 = '\n';
const tab: u8 = '\t';
const backslash: u8 = '\\';
const quote: u8 = '\'';
```

**Unicode**:
```k
const emoji: u21 = '\u{1F600}';
const chinese: u21 = '中';
```

---

## Complete Examples

### Example 1: Configuration File Template

```k
const config_template = r#"""
    [database]
    host = "{db_host}"
    port = {db_port}

    [server]
    # Use raw string for Windows paths
    log_path = r"{log_path}"
    """#;

const rendered = config_template
    .replace("{db_host}", "localhost")
    .replace("{db_port}", "5432")
    .replace("{log_path}", r"C:\logs\app.log");
```

### Example 2: SQL Query Builder

```k
fn build_query(table: []const u8, conditions: []Condition) []const u8 {
    const base = r#"
        SELECT * FROM {table}
        WHERE
    "#;

    var query = base.replace("{table}", table);

    for (conditions, 0..) |cond, i| {
        if (i > 0) query = query ++ " AND ";
        query = query ++ "{cond.field} = {cond.value}";
    }

    return query;
}
```

### Example 3: Nested Comments for Debugging

```k
fn process_data(data: []const u8) !void {
    /* Temporary debug code - comment out entire block

    /* Original implementation - kept for reference
    const parsed = try parse_old_format(data);
    return process_old(parsed);
    */

    // New implementation
    const parsed = try parse_new_format(data);
    return process_new(parsed);

    */ // End temporary comment
}
```

### Example 4: HTML Template

```k
fn render_page(title: []const u8, content: []const u8) []const u8 {
    return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>{title}</title>
        </head>
        <body>
            <div class="container">
                {content}
            </div>
        </body>
        </html>
        """;
}
```

---

## Comparison with Other Languages

| Feature | Rust | Python | Swift | Zig | **K** |
|---------|------|--------|-------|-----|-------|
| **Nested comments** | ✅ `/* /* */ */` | ❌ | ✅ `/* /* */ */` | ❌ | ✅ `/* /* */ */` |
| **Raw strings** | ✅ `r#"..."#` | ✅ `r"..."` | ✅ `#"..."#` | ❌ | ✅ `r#"..."#` |
| **Multi-line strings** | ❌ | ✅ `"""..."""` | ✅ `"""..."""` | ✅ `\\` | ✅ `"""..."""` |
| **String interpolation** | ⚠️ `format!()` | ✅ `f"..."` | ✅ `"\(x)"` | ❌ | ✅ `"{x}"` |
| **Byte strings** | ✅ `b"..."` | ✅ `b"..."` | ❌ | ❌ | ✅ `b"..."` |
| **Custom delimiters** | ✅ Multiple `#` | ❌ | ✅ Multiple `#` | ❌ | ✅ Multiple `#` |

**K combines best features**:
- Rust's raw strings and byte strings
- Python's multi-line strings
- Swift's string interpolation and nesting
- Custom delimiter depth (Rust/Swift style)

---

## Syntax Summary

```k
// Comments
// Single-line
/* Multi-line */
/* /* Nested */ */
/// Doc comment
//! Module doc

// Regular strings
"Hello, world!"
"Escapes: \n \t \u{1F600}"
"Interpolation: {name}, {age}"

// Raw strings
r"No escapes: \n stays literal"
r#"Contains "quotes""#
r##"Contains r#"nested"#"##

// Multi-line strings
"""
Multi-line
content
"""

// Raw multi-line
r"""
Raw
multi-line
"""

r#"""
With delimiter
and quotes """
"""#

// Byte strings
b"Byte data"
br"Raw bytes"
br#"Raw with "#"#

// Characters
'A'
'\n'
'\u{1F600}'
```

---

## Implementation Notes

### Parser Considerations

1. **Nested comment depth tracking**:
   ```k
   var depth: usize = 0;
   // On '/*': depth += 1
   // On '*/': depth -= 1
   // Done when depth == 0
   ```

2. **Raw string delimiter counting**:
   ```k
   // Count # in r###"
   const open_hashes = count_hashes(opening);
   // Must match exactly in "###
   const close_hashes = count_hashes(closing);
   if (open_hashes != close_hashes) error.MismatchedDelimiter;
   ```

3. **Multi-line indentation trimming**:
   ```k
   // Find indentation of closing """
   const base_indent = measure_indent(closing_line);
   // Remove from all lines
   for (lines) |line| {
       trim_prefix(line, base_indent);
   }
   ```

4. **String interpolation parsing**:
   ```k
   // Parse {expr} at compile time
   // Validate types match format specifiers
   // Generate format!() call
   ```

---

## Design Rationale

### Why Nested Comments?

**Problem**: C-style comments don't nest
```c
/* Comment /* Nested */ breaks */
```

**Solution**: Track nesting depth
```k
/* Comment /* Nested */ works! */
```

**Benefits**:
- Easy to comment out blocks
- Safer during refactoring
- Proven in Rust, Swift, D

---

### Why Multiple Raw String Delimiters?

**Problem**: What if string contains `"`?
```k
const s = r"Contains " breaks";  // ❌ Breaks
```

**Solution**: Use `#` delimiters
```k
const s = r#"Contains " works"#;  // ✅ Works
const s2 = r##"Contains r#" works"##;  // ✅ Nested
```

**Benefits**:
- No escaping needed
- Arbitrary nesting depth
- Proven in Rust, Swift

---

### Why String Interpolation?

**Without interpolation**:
```k
const s = "Hello, " ++ name ++ "! Age: " ++ @intToString(age);  // Verbose
```

**With interpolation**:
```k
const s = "Hello, {name}! Age: {age}";  // Clear
```

**Benefits**:
- More readable
- Type-checked at compile time
- Common in modern languages

---

### Why Byte Strings?

**Problem**: String vs bytes confusion
```k
const data: []const u8 = "Hello";  // UTF-8 string or bytes?
```

**Solution**: Explicit byte strings
```k
const text: []const u8 = "Hello";   // UTF-8 string (validated)
const bytes: []const u8 = b"Hello"; // Raw bytes (no validation)
```

**Benefits**:
- Clear intent
- FFI with C
- Binary protocols
- No UTF-8 overhead for bytes

---

## Conclusion

**K's string and comment features**:
- ✅ **Nested comments** - safer refactoring
- ✅ **Raw strings** - easier regex, paths, SQL
- ✅ **Multi-line strings** - better templates
- ✅ **String interpolation** - readable formatting
- ✅ **Byte strings** - explicit bytes vs strings
- ✅ **Custom delimiters** - arbitrary nesting

**Combined features from**:
- Rust (raw strings, byte strings, nested comments)
- Python (multi-line strings)
- Swift (interpolation, multiple delimiters)
- Kotlin (indentation trimming)

This makes K excellent for:
- Systems programming (byte strings, FFI)
- Web backends (templates, SQL, HTML)
- Text processing (regex, parsing)
- Configuration files (TOML, JSON, YAML)
