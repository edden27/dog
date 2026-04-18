# Swift 6 Concurrency Rules

Swift 6 enforces strict concurrency checking at compile time. Code that compiled fine in Swift 5 will throw errors now. This file covers what you need to know for this project.

## The one rule that matters

**You cannot share mutable state across concurrency boundaries unless it's protected.**

Swift 6 enforces this at compile time. If the compiler complains about "sending" or "Sendable" or "actor-isolated", it's telling you that you're trying to share something between threads unsafely.

## Sendable

A type is `Sendable` if it's safe to pass between concurrent contexts.

**Already Sendable (you don't have to do anything):**
- Value types (`struct`, `enum`) where all stored properties are also Sendable
- Immutable classes (all `let` properties that are themselves Sendable)
- Actors (by definition)
- Primitives: `Int`, `String`, `Bool`, `Double`, `URL`, etc.
- Standard library collections of Sendable types: `[String]`, `[Int: URL]`, etc.

**Not Sendable (needs work):**
- Classes with `var` properties
- Anything holding a closure (closures aren't Sendable by default)
- Types with mutable shared state

**For this project:** Most of our types will be `struct` and `enum` (Codable models, result types, config). These are automatically Sendable. Don't reach for classes unless you have a real reason.

```swift
// Good — automatically Sendable
struct SearchResult: Codable, Sendable {
    let title: String
    let url: String
    let description: String
}

// Bad — class with var, not Sendable, compiler will yell at you
class SearchResult {
    var title: String = ""
    var url: String = ""
}
```

## async/await

All network calls use `async/await`. No completion handlers, no Combine, no DispatchQueue.

```swift
// Good
func fetchDocumentation(path: String) async throws -> DocumentationPage {
    let (data, response) = try await URLSession.shared.data(for: request)
    // ...
}

// Bad — completion handler style
func fetchDocumentation(path: String, completion: @escaping (Result<DocumentationPage, Error>) -> Void) {
    URLSession.shared.dataTask(with: request) { data, response, error in
        // callback hell
    }.resume()
}
```

## Task and structured concurrency

Use `Task` at the entry point (CLI main). Use task groups for parallel work.

```swift
// Sequential — one after another
let page1 = try await fetchDocumentation(path: path1)
let page2 = try await fetchDocumentation(path: path2)

// Parallel — both at once (use this for batch fetches)
async let page1 = fetchDocumentation(path: path1)
async let page2 = fetchDocumentation(path: path2)
let results = try await [page1, page2]

// Parallel with dynamic number of items — task group
let pages = try await withThrowingTaskGroup(of: DocumentationPage.self) { group in
    for path in paths {
        group.addTask {
            try await fetchDocumentation(path: path)
        }
    }
    var results: [DocumentationPage] = []
    for try await page in group {
        results.append(page)
    }
    return results
}
```

## @MainActor

**We probably don't need this.** `@MainActor` is for UI code — it guarantees something runs on the main thread. This is a CLI tool with no UI. Don't slap `@MainActor` on things to make compiler errors go away — that's hiding the problem.

If you see a compiler error suggesting `@MainActor`, the real fix is almost always:
- Make the type Sendable (usually by making it a struct)
- Make the property `let` instead of `var`
- Move the mutation into an actor

## Actors

Use an `actor` when you genuinely need mutable shared state that multiple concurrent tasks access. For this project, the most likely candidate is a cache or a rate limiter.

```swift
// Good — actor protects mutable state
actor DocumentationCache {
    private var pages: [String: DocumentationPage] = [:]

    func get(_ path: String) -> DocumentationPage? {
        pages[path]
    }

    func store(_ page: DocumentationPage, for path: String) {
        pages[path] = page
    }
}

// Usage — must await because actor access is async
let cache = DocumentationCache()
if let cached = await cache.get(path) {
    return cached
}
```

**Don't use actors for everything.** If a type is created, used, and discarded in a single function, it doesn't need to be an actor. Actors are for long-lived shared state.

## nonisolated

When an actor conforms to a protocol (like `CustomStringConvertible`) and the required method only reads immutable state, mark it `nonisolated` so callers don't need to await it.

```swift
actor DocumentationCache {
    let name: String // immutable, safe to read from anywhere

    nonisolated var description: String {
        "Cache: \(name)" // only touches let properties
    }
}
```

## Closures and Sendable

If you pass a closure across a concurrency boundary (into a `Task`, into an actor method), the closure and everything it captures must be Sendable.

```swift
// This will error if `config` is not Sendable
Task {
    let result = try await fetch(config) // config captured by closure
}
```

Fix: make sure `config` is a Sendable type (struct with Sendable properties).

Don't use `@Sendable` on closures as a band-aid. If the compiler wants `@Sendable`, it means the captured values need to be Sendable. Fix the values, not the closure annotation.

## Common compiler errors and what they actually mean

**"Sending 'value' risks causing data races"**
→ You're passing a non-Sendable value into a concurrent context. Make the type Sendable (usually struct with let properties) or copy the values you need.

**"Actor-isolated property 'x' can not be referenced from a non-isolated context"**
→ You're trying to access an actor's property without `await`. Add `await` or mark the access point as being on the same actor.

**"Type 'X' does not conform to the 'Sendable' protocol"**
→ The type has mutable state or non-Sendable properties. Make it a struct, make properties `let`, or make the contained types Sendable.

**"Capture of non-sendable type in @Sendable closure"**
→ A closure going into a Task/actor captures something that isn't Sendable. Same fix — make the captured type Sendable.

## Rules of thumb for this project

1. **Default to structs.** They're automatically Sendable when their properties are.
2. **Default to `let`.** Immutable is always safe.
3. **Use `async/await` for all IO.** Network, file system, everything.
4. **Use `async let` or task groups for parallel work.** Batch fetches should be parallel.
5. **Use actors only for shared mutable state** (cache, rate limiter). Don't reach for them by default.
6. **Don't use `@MainActor`** — this is a CLI, not a UI app.
7. **Don't use `@unchecked Sendable`** — this disables the safety checks. If you think you need it, you probably need to restructure instead.
8. **Don't use `nonisolated(unsafe)`** — same thing, it's an escape hatch that hides bugs.
9. **If the compiler complains, fix the design, don't silence the warning.** Swift 6's concurrency errors are almost always pointing at a real potential bug.
