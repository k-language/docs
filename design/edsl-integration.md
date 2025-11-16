# Embedded DSL Integration in K

## Problem Statement

**Question**: JSX나 LINQ 같은 eDSL (embedded Domain-Specific Language) 통합 아이디어 있어?

**Answer**: K's comptime + reflection + HKT는 여러 eDSL 통합 전략을 가능하게 함!

## eDSL Examples to Support

### 1. JSX-like (UI Description)

```jsx
// React JSX
const element = (
    <div className="container">
        <h1>Hello, {name}!</h1>
        <button onClick={handleClick}>Click me</button>
    </div>
);
```

### 2. LINQ-like (Query Composition)

```csharp
// C# LINQ
var result = from person in people
             where person.age > 18
             orderby person.name
             select person.name;
```

### 3. SQL-like (Type-safe Queries)

```kotlin
// Kotlin Exposed
val users = Users
    .select { Users.age greater 18 }
    .orderBy(Users.name)
    .map { it[Users.name] }
```

### 4. HTML Templates

```html
<!-- Template with interpolation -->
<div class="{{className}}">
    {{#each items}}
        <li>{{this.name}}</li>
    {{/each}}
</div>
```

---

## Approach 1: Comptime Code Generation (Zig-Style)

**Strategy**: Use comptime functions to generate code at compile time

### JSX-like Example

```k
// HTML DSL using comptime
const html = comptime {
    const root = Html.div(.{ .class = "container" }, &[_]Html.Node{
        Html.h1(.{}, &[_]Html.Node{
            Html.text("Hello, "),
            Html.text(name),
            Html.text("!"),
        }),
        Html.button(.{ .onClick = handleClick }, &[_]Html.Node{
            Html.text("Click me"),
        }),
    });
    return root.render();
};
```

**Pros**:
- ✅ Type-safe at compile time
- ✅ Zero runtime overhead
- ✅ No special syntax needed
- ✅ Works with existing K features

**Cons**:
- ❌ Verbose compared to JSX
- ❌ Less ergonomic

---

## Approach 2: Builder Pattern with Comptime (Swift-Style)

**Strategy**: Use function builder pattern with comptime validation

### HTML Builder Example

```k
// HTML builder
fn html(comptime builder: fn() Html.Node) Html.Node {
    return comptime builder();
}

// Usage with builder syntax
const element = html {
    div(.{ .class = "container" }) {
        h1 {
            text("Hello, ");
            text(name);
            text("!");
        };
        button(.{ .onClick = handleClick }) {
            text("Click me");
        };
    }
};
```

**Implementation**:
```k
const Html = struct {
    pub const Node = union(enum) {
        Element: struct {
            tag: []const u8,
            attrs: Attrs,
            children: []Node,
        },
        Text: []const u8,
    };

    pub const Attrs = std.StringHashMap([]const u8);

    // Builder for div
    pub fn div(attrs: Attrs, comptime builder: fn() []Node) Node {
        return .{
            .Element = .{
                .tag = "div",
                .attrs = attrs,
                .children = comptime builder(),
            },
        };
    }

    // Builder for h1
    pub fn h1(comptime builder: fn() []Node) Node {
        return .{
            .Element = .{
                .tag = "h1",
                .attrs = Attrs.init(),
                .children = comptime builder(),
            },
        };
    }

    pub fn text(content: []const u8) Node {
        return .{ .Text = content };
    }
};
```

**Pros**:
- ✅ More ergonomic than raw function calls
- ✅ Type-safe
- ✅ Comptime validated
- ✅ No macros needed

**Cons**:
- ⚠️ Still not as clean as JSX
- ⚠️ Requires builder infrastructure

---

## Approach 3: Macro System (Rust-Style)

**Strategy**: Add macro system for AST transformation

### Declarative Macros

```k
// Define macro
macro jsx {
    // Pattern matching on AST
    rule { <$tag:ident $attrs:expr> $children:expr </$tag:ident> } => {
        Html.element(stringify!($tag), $attrs, $children)
    };

    rule { <$tag:ident $attrs:expr /> } => {
        Html.element(stringify!($tag), $attrs, &[_]Html.Node{})
    };

    rule { { $expr:expr } } => {
        Html.text($expr)
    };
}

// Usage
const element = jsx! {
    <div class="container">
        <h1>Hello, {name}!</h1>
        <button onClick={handleClick}>Click me</button>
    </div>
};
```

**Pros**:
- ✅ JSX-like syntax
- ✅ Familiar to web developers
- ✅ Powerful transformation

**Cons**:
- ❌ Requires macro system (new feature)
- ❌ Hygiene issues
- ❌ Debugging complexity

---

## Approach 4: Quasi-Quotation (Haskell-Style)

**Strategy**: AST literals with quasi-quotation

### Template Haskell-like

```k
// Quasi-quoter for HTML
const element = [html|
    <div class="container">
        <h1>Hello, ${name}!</h1>
        <button onClick=${handleClick}>Click me</button>
    </div>
|];

// Desugars to AST construction at compile time
const element = comptime parseHtml(
    "<div class=\"container\">\n" ++
    "    <h1>Hello, ${name}!</h1>\n" ++
    "    <button onClick=${handleClick}>Click me</button>\n" ++
    "</div>"
);
```

**Implementation**:
```k
// Compile-time HTML parser
fn parseHtml(comptime source: []const u8) Html.Node {
    comptime {
        const parser = HtmlParser.init(source);
        return parser.parse();
    }
}

// Usage with @embedFile
const template = [html| @embedFile("template.html") |];
```

**Pros**:
- ✅ Natural syntax for templates
- ✅ Can validate at compile time
- ✅ Can use @embedFile for external templates

**Cons**:
- ❌ Requires quasi-quotation syntax
- ⚠️ Limited interpolation

---

## Approach 5: LINQ-Style Query Comprehension

**Strategy**: Monadic comprehension with do-notation or query syntax

### Using Monad Traits

```k
// LINQ-like queries using trait methods
const result = people
    .where(fn(p) p.age > 18)
    .orderBy(fn(p) p.name)
    .select(fn(p) p.name);
```

**With do-notation** (if we add it):
```k
const result = do {
    person <- people;
    guard(person.age > 18);
    return person.name;
}.orderBy(fn(p) p);
```

**With query comprehension syntax**:
```k
const result = query {
    for person in people
    where person.age > 18
    orderby person.name
    select person.name
};
```

**Implementation** (method chaining version):
```k
// Query monad
const Query = fn(comptime T: type) type {
    return struct {
        items: []T,

        pub fn where(self: Query(T), predicate: fn(T) bool) Query(T) {
            var result = std.ArrayList(T).init(allocator);
            for (self.items) |item| {
                if (predicate(item)) {
                    try result.append(item);
                }
            }
            return Query(T){ .items = result.items };
        }

        pub fn select(self: Query(T), comptime U: type, selector: fn(T) U) Query(U) {
            var result = std.ArrayList(U).init(allocator);
            for (self.items) |item| {
                try result.append(selector(item));
            }
            return Query(U){ .items = result.items };
        }

        pub fn orderBy(self: Query(T), comptime K: type, key: fn(T) K) Query(T)
            where K: Ord
        {
            const items_copy = try allocator.dupe(T, self.items);
            std.sort.sort(T, items_copy, {}, fn(ctx: void, a: T, b: T) bool {
                return key(a) < key(b);
            });
            return Query(T){ .items = items_copy };
        }
    };
};

// Helper to create queries
fn from(comptime T: type, items: []T) Query(T) {
    return Query(T){ .items = items };
}

// Usage
const result = from(Person, people)
    .where(fn(p) p.age > 18)
    .orderBy([]const u8, fn(p) p.name)
    .select([]const u8, fn(p) p.name);
```

**Pros**:
- ✅ Works with current K features
- ✅ Type-safe
- ✅ Chainable
- ✅ Lazy evaluation possible

**Cons**:
- ⚠️ Not as clean as C# LINQ syntax
- ⚠️ Requires method chaining

---

## Approach 6: Type-Safe SQL

**Strategy**: Compile-time SQL parsing + type generation

### Using Comptime Reflection

```k
// Define schema at compile time
const Users = comptime defineTable("users", .{
    .id = .{ .type = i64, .primary_key = true },
    .name = .{ .type = []const u8, .not_null = true },
    .email = .{ .type = []const u8, .unique = true },
    .age = .{ .type = i32, .nullable = true },
});

// Type-safe query builder
const query = Users
    .select(&[_][]const u8{ "name", "age" })
    .where(.{ .age = .{ .gt = 18 } })
    .orderBy(.{ .name = .asc });

// Generates SQL at compile time
const sql = comptime query.toSql();
// "SELECT name, age FROM users WHERE age > ? ORDER BY name ASC"

// Type of result
const ResultRow = comptime query.resultType();
// struct { name: []const u8, age: i32 }

// Execute with type safety
const results: []ResultRow = try db.execute(query);
```

**Implementation**:
```k
fn defineTable(comptime name: []const u8, comptime schema: anytype) type {
    return struct {
        const Self = @This();
        const table_name = name;

        // Generate column types
        const Columns = comptime generateColumns(schema);

        pub fn select(comptime columns: []const []const u8) SelectBuilder(Self, columns) {
            return SelectBuilder(Self, columns).init();
        }

        pub fn insert(values: Columns) InsertBuilder(Self) {
            return InsertBuilder(Self).init(values);
        }

        pub fn update(values: anytype) UpdateBuilder(Self) {
            return UpdateBuilder(Self).init(values);
        }
    };
}

fn SelectBuilder(comptime Table: type, comptime columns: []const []const u8) type {
    return struct {
        conditions: []Condition,

        pub fn where(self: @This(), cond: anytype) @This() {
            // Build WHERE clause
        }

        pub fn orderBy(self: @This(), order: anytype) @This() {
            // Build ORDER BY clause
        }

        pub fn toSql(self: @This()) []const u8 {
            comptime {
                var sql = "SELECT ";
                for (columns, 0..) |col, i| {
                    if (i > 0) sql = sql ++ ", ";
                    sql = sql ++ col;
                }
                sql = sql ++ " FROM " ++ Table.table_name;
                // Add WHERE, ORDER BY, etc.
                return sql;
            }
        }

        pub fn resultType() type {
            comptime {
                // Generate struct type for result row
                var fields: []const FieldDef = &[_]FieldDef{};
                for (columns) |col| {
                    const col_type = @field(Table.Columns, col);
                    fields = fields ++ [_]FieldDef{
                        .{ .name = col, .type = col_type },
                    };
                }
                return @Type(.{ .Struct = .{ .fields = fields } });
            }
        }
    };
}
```

**Pros**:
- ✅ Compile-time SQL validation
- ✅ Type-safe results
- ✅ No runtime parsing
- ✅ Prevents SQL injection

**Cons**:
- ⚠️ Complex implementation
- ⚠️ Requires @Type() and reflection

---

## Recommended Approach for K

### Hybrid Strategy: Multiple eDSL Support

**Phase 1: Foundation (Available Now)**

1. **Builder Pattern + Comptime**
   - Works with current features
   - Type-safe
   - Zero runtime overhead

```k
const ui = html {
    div(.{ .class = "container" }) {
        h1 { text("Hello!") };
        button(.{ .onClick = handler }) { text("Click") };
    }
};
```

2. **Method Chaining** (LINQ-style)
   - Current features
   - Monadic composition

```k
const result = from(Person, people)
    .where(fn(p) p.age > 18)
    .select([]const u8, fn(p) p.name);
```

---

**Phase 2: Quasi-Quotation (Near-term)**

Add `[name| ... |]` syntax for compile-time parsing:

```k
const template = [html|
    <div class="container">
        <h1>Hello, ${name}!</h1>
    </div>
|];

const query = [sql|
    SELECT name, age FROM users WHERE age > ${minAge}
|];
```

**Benefits**:
- ✅ Natural syntax for templates
- ✅ Compile-time validation
- ✅ Type-safe interpolation
- ✅ Works with @embedFile

**Implementation**:
```k
// Compiler recognizes [name| ... |] syntax
// Calls comptime function: parse_name(source)

fn parse_html(comptime source: []const u8) Html.Node {
    comptime {
        // Parse at compile time
        const parser = HtmlParser.init(source);
        return parser.parse();
    }
}

// Register quasi-quoter
@registerQuasiQuoter("html", parse_html);
```

---

**Phase 3: Macro System (Future)**

Add hygenic macro system for advanced DSLs:

```k
macro jsx {
    rule { <$tag:ident $($attr:ident=$val:expr)*> $children:tt </$tag:ident> } => {
        Html.element(
            stringify!($tag),
            &[_]Html.Attr{ $( Html.attr(stringify!($attr), $val) ),* },
            $children
        )
    };
}

const element = jsx! {
    <div class="container">
        <h1>Hello!</h1>
    </div>
};
```

---

## Real-World Examples

### Example 1: Web UI DSL

```k
// Define UI component
const TodoList = fn(comptime props: type) type {
    return struct {
        const Self = @This();

        items: []TodoItem,

        pub fn render(self: Self) Html.Node {
            return html {
                div(.{ .class = "todo-list" }) {
                    h2 { text("My Todos") };
                    ul {
                        for (self.items) |item| {
                            li(.{ .class = if (item.done) "done" else "" }) {
                                text(item.title);
                            };
                        }
                    };
                }
            };
        }
    };
};
```

### Example 2: Database Query DSL

```k
// Define schema
const Users = defineTable("users", .{
    .id = i64,
    .name = []const u8,
    .email = []const u8,
    .age = i32,
});

// Type-safe query
const query = Users
    .select(&[_][]const u8{ "name", "email" })
    .where(.{ .age = .{ .gte = 18, .lte = 65 } })
    .orderBy(.{ .name = .asc })
    .limit(10);

// Execute with type safety
const results: []struct { name: []const u8, email: []const u8 } =
    try db.execute(query);
```

### Example 3: Parser Combinator DSL

```k
// Define parser using monadic combinators
const json_parser = do {
    _ <- whitespace;
    value <- choice(&[_]Parser{
        json_object,
        json_array,
        json_string,
        json_number,
        json_bool,
        json_null,
    });
    _ <- whitespace;
    return value;
};

// Or with builder syntax
const json_parser = parser {
    whitespace;
    const value = oneOf {
        json_object;
        json_array;
        json_string;
        json_number;
    };
    whitespace;
    return value;
};
```

### Example 4: Async/Await DSL

```k
// Async computation builder
const task = async {
    const data = await fetchData(url);
    const parsed = await parseData(data);
    const validated = await validateData(parsed);
    return validated;
};

// Desugars to:
const task = fetchData(url)
    .andThen(fn(data) parseData(data))
    .andThen(fn(parsed) validateData(parsed));
```

---

## Comparison with Other Languages

| Language | Approach | Syntax | Type Safety | Compile-time |
|----------|----------|--------|-------------|--------------|
| **React (JSX)** | Transpiler | Custom | ⚠️ Partial | ❌ No |
| **C# (LINQ)** | Compiler feature | Custom | ✅ Full | ⚠️ Partial |
| **Rust** | Macros | proc_macro | ✅ Full | ✅ Yes |
| **Haskell** | Template Haskell | Quasi-quotes | ✅ Full | ✅ Yes |
| **Scala** | Macros + implicits | Custom | ✅ Full | ✅ Yes |
| **K (Proposed)** | **Comptime + Quasi** | **Builder + Quotes** | ✅ Full | ✅ Yes |

---

## Implementation Priorities

### Immediate (Works Now)

1. ✅ **Builder patterns** with comptime
2. ✅ **Method chaining** for queries
3. ✅ **Comptime code generation**

### Near-term (High Priority)

1. **Quasi-quotation** syntax: `[name| ... |]`
2. **@registerQuasiQuoter** builtin
3. **Compile-time string parsing**

### Long-term (Future)

1. **Hygenic macro system**
2. **Do-notation** for monads
3. **Custom operators**

---

## Conclusion

### Answer to Original Question

> JSX나 LINQ 같은 eDSL 통합 아이디어 있어?

**Yes!** K can support eDSLs through multiple approaches:

**Available now**:
- ✅ Builder patterns + comptime
- ✅ Method chaining (LINQ-style)
- ✅ Type-safe at compile time

**Proposed additions**:
- 🎯 Quasi-quotation: `[html| ... |]`, `[sql| ... |]`
- 🎯 Compile-time parsing + validation
- 🎯 Zero runtime overhead

**Future**:
- 🔮 Hygenic macro system
- 🔮 Do-notation for monads

**K's advantages**:
- ✅ Comptime + reflection = powerful metaprogramming
- ✅ Type-safe eDSLs
- ✅ Zero runtime cost
- ✅ No transpiler needed

**With quasi-quotation**, K would have:
- **JSX-like** UI description
- **LINQ-like** queries
- **SQL-like** type-safe queries
- **HTML** templates
- All **compile-time validated** and **type-safe**!

This would make K excellent for:
- Web backends (type-safe SQL)
- UI frameworks (HTML/JSX-like)
- Parser combinators
- Async workflows
- Domain-specific tooling
