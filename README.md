# NExT

A lightweight Perl parser for the [NExT (Noun Expression Tree) format](NExT_spec.txt).

NExT is a declarative, hierarchical data format designed for LL(1)
single-pass parsing. It is purely declarative with no code, no logic,
and no Turing-complete expressions.

File extension: `.nx`

## Quick Start

    use Data::NExT;

    my $tree = Data::NExT::parse(q{
    Window[
        title("Settings")
        width(500)
        Box[
            orientation("vertical")
            Label[ text("Hello") ]
        ]
    ]
    });
    die "Error: $Data::NExT::ERROR\n" if defined $Data::NExT::ERROR;

## Format

Two structural token classes, distinguished by first character:

    First char   Token class   Bracket   Example
    -----------  -----------   -------   -------
    [A-Z]        Noun          [ ]       Window, Agent, Box
    [a-z]        Adjective     ( )       title, name, subscribe
    #            Comment       (none)    # this is a comment

Values: `"strings"`, `42` (int), `3.14` (float), `true`/`false` (bool), `@symbol` (symbol), inline `Noun[ ]`, or lists `["a" "b"]`.

## API

### `Data::NExT::parse($input)`

Returns a reference to an array of top-level noun nodes, or `undef` on
error. On error, `$Data::NExT::ERROR` contains a human-readable message
with line number.

Each node is a hashref:

    { type => 'noun', name => 'Window', children => [...], line => 1 }
    { type => 'adj',  name => 'title',  value => {...},    line => 2 }

## Running Tests

    prove -v t/

## License

Artistic License 2.0. See [LICENSE](LICENSE).
