# Writing NExT — A Quick Guide for LLMs

NExT (Noun Expression Tree) is a declarative data description format. It describes **what**, not **how**.

## Grammar in 30 seconds

```
Noun[ adjective("value") ChildNoun[ adjective("value") ] ]
```

- **Nouns** start uppercase: `Window`, `Agent`, `Box`
- **Adjectives** start lowercase: `title`, `width`, `name`
- **Values** are literals in parens: `"hello"`, `42`, `true`, `@symbol`
- **Nesting** uses `[ ]` for nouns, `( )` for adjectives

## Example

```
Pipeline[
  name("code-review")
  Agent[
    name("critic")
    wit("logic")
    subscribe("git.diff.ready")
  ]
  Agent[
    name("fixer")
    wit("repair")
    subscribe("critic.output")
  ]
]
```

## Rules

1. Nouns: `[A-Z][a-zA-Z0-9_]*` — CamelCase
2. Adjectives: `[a-z][a-zA-Z0-_-]*` — snake_case
3. Values: `"string"`, `42`, `3.14`, `true`, `false`, `@symbol`, or inline `Noun[ ]`
4. Strings use double quotes. Escape: `\"`, `\\`, `\n`, `\t`
5. Comments start with `#`
6. No code, no expressions, no interpolation — just data
7. Whitespace is insignificant (indent for readability)
8. Nouns can be empty: `Window[ ]`
9. Adjectives and child nouns can be mixed in any order

## Common mistakes

- `name = "x"` → wrong: use `name("x")`
- `window[` → wrong: must be `Window[` (uppercase)
- `"name": "x"` → wrong: this is JSON, not NExT
- `name(x)` → wrong: strings need quotes: `name("x")`
- `name("hello" "world")` → wrong: one value per adjective

## Tips

- Think of nouns as objects, adjectives as properties
- Nesting depth is unlimited but keep it readable (≤10 levels)
- Use comments liberally: `# configuration section`
- Each adjective holds exactly one value
- Multiple nouns at the same level are siblings
