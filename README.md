# Data::NExT

Lightweight parser for the NExT (Noun Expression Tree) data format.

## Synopsis

```perl
use Data::NExT;

my $input = q{
Window[
    title("Settings")
    width(500)
    Box[
        orientation("vertical")
        Label[ text("Hello") ]
    ]
]
};

my $tree = Data::NExT::parse($input);
die "Error: $Data::NExT::ERROR\n" if defined $Data::NExT::ERROR;

for my $node (@$tree) {
    print "$node->{name}\n" if $node->{type} eq 'noun';
}
```

## Description

NExT is a declarative, hierarchical data format designed for LL(1)
single-pass parsing. Purely declarative with no code, no logic, and
no Turing-complete expressions.

```
Token class   Bracket   Example
-----------   -------   -------
Noun          [ ]       Window, Agent, Box
Adjective     ( )       title, name, subscribe
Symbol        (none)    @cancel, @exit
Comment       (none)    # this is a comment
```

## Value Types

```
Type      Syntax                    Example
------    ------                    -------
String    "double-quoted"           "Hello"
Heredoc   """ (block format)        """\nmulti-line\ntext"""
Integer   decimal digits            42, 0, 1000
Float     digits.digits             3.14, 0.5
Boolean   true or false             true, false
Symbol    @identifier               @cancel, @exit
Noun      Noun[ content ]           Var[ bind("x") ]
List      [ value ... ]             ["a" "b"], [1 2 3]
```

## Modules

### Data::NExT

Core parser. Zero dependencies.

### Data::NExT::Template

Template pre-processor for `.nxt` files. Handles variable interpolation,
function calls, conditionals, and file inclusion.

### Data::NExT::Util

Tree utilities — traversal, extraction, building, comparison, validation.

## CLI Tools

```
nxt-preprocess    .nxt → .nx  (template expansion)
nxt-format        .nx → .nx   (pretty-print)
nxt-validate      .nx → exit code (validation)
```

## Installation

```bash
perl Makefile.PL
make
make test
make install
```

## Author

Billy Lyrical

## License

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.
