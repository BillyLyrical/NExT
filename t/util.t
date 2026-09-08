use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::NExT;
use Data::NExT::Util qw(find find_adj find_first walk
    to_hash noun_names to_text
    tree
    where
    equals diff
    require_adj require_child validate);

# --- find ---

{
    my $tree = Data::NExT::parse('Agent[ name("a") ] Pipeline[ ] Agent[ name("b") ]');
    my @agents = @{ find($tree, 'Agent') };
    is(scalar @agents, 2, 'find: two Agent nodes');
    is($agents[0]{children}[0]{value}{value}, 'a');
    is($agents[1]{children}[0]{value}{value}, 'b');
}

{
    my $tree = Data::NExT::parse('Outer[ Inner[ val("x") ] ]');
    my @inner = @{ find($tree, 'Inner') };
    is(scalar @inner, 1, 'find nested');
    is($inner[0]{children}[0]{value}{value}, 'x');
}

# --- find_adj ---

{
    my $tree = Data::NExT::parse('Agent[ name("a") wit("logic") ] Config[ name("b") ]');
    my @names = @{ find_adj($tree, 'name') };
    is(scalar @names, 2, 'find_adj: two name adjectives');
    is($names[0]{value}{value}, 'a');
    is($names[1]{value}{value}, 'b');
}

{
    my $tree = Data::NExT::parse('X[ a("1") ] Y[ a("2") b("3") ]');
    my @a = @{ find_adj($tree, 'a') };
    my @b = @{ find_adj($tree, 'b') };
    is(scalar @a, 2, 'find_adj: two a adjectives');
    is(scalar @b, 1, 'find_adj: one b adjective');
}

# --- find_first ---

{
    my $tree = Data::NExT::parse('A[ x("1") ] B[ x("2") ]');
    my $first = find_first($tree, 'A');
    is($first->{name}, 'A', 'find_first: returns first match');
}

{
    my $tree = Data::NExT::parse('A[ x("1") ]');
    my $miss = find_first($tree, 'Z');
    is($miss, undef, 'find_first: returns undef on miss');
}

# --- walk ---

{
    my $tree = Data::NExT::parse('A[ name("a") B[ name("b") ] ]');
    my @names;
    walk($tree, sub {
        my $node = shift;
        push @names, $node->{name} if $node->{type} eq 'noun';
    });
    is_deeply(\@names, ['A', 'B'], 'walk visits all nouns');
}

{
    my $tree = Data::NExT::parse('X[ a("1") b("2") ]');
    my @adj_names;
    walk($tree, sub {
        my $node = shift;
        push @adj_names, $node->{name} if $node->{type} eq 'adj';
    });
    is_deeply(\@adj_names, ['a', 'b'], 'walk visits adjectives');
}

# --- to_hash ---

{
    my $tree = Data::NExT::parse('Agent[ name("critic") wit("logic") ]');
    my $h = to_hash($tree->[0]);
    is($h->{name}, 'critic', 'to_hash: string adj');
    is($h->{wit}, 'logic', 'to_hash: second adj');
}

{
    my $tree = Data::NExT::parse('X[ val(42) flag(true) ]');
    my $h = to_hash($tree->[0]);
    is($h->{val}, 42, 'to_hash: integer');
    is($h->{flag}, 1, 'to_hash: boolean');
}

{
    my $tree = Data::NExT::parse('Outer[ Inner[ val("x") ] ]');
    my $h = to_hash($tree->[0]);
    is(ref $h->{Inner}, 'HASH', 'to_hash: nested noun is hashref');
    is($h->{Inner}{val}, 'x', 'to_hash: nested value');
}

# --- noun_names ---

{
    my $tree = Data::NExT::parse('A[ B[ C[ ] ] ] D[ ]');
    my @names = @{ noun_names($tree) };
    is_deeply(\@names, ['A', 'B', 'C', 'D'], 'noun_names: all nouns in order');
}

# --- to_text roundtrip ---

{
    my $input = "Agent[\n    name(\"critic\")\n    wit(\"logic\")\n]\n";
    my $tree = Data::NExT::parse($input);
    my $text = to_text($tree->[0]);
    like($text, qr/Agent\[/, 'to_text: noun present');
    like($text, qr/name\("critic"\)/, 'to_text: adj present');
}

{
    my $input = "X[\n    tags([\"a\" \"b\"])\n    val(42)\n    flag(true)\n]\n";
    my $tree = Data::NExT::parse($input);
    my $text = to_text($tree->[0]);
    like($text, qr/tags\(\["a" "b"\]\)/, 'to_text: list value');
    like($text, qr/val\(42\)/, 'to_text: integer value');
    like($text, qr/flag\(true\)/, 'to_text: boolean value');
}

# --- tree builder ---

{
    my $node = tree([
        Agent => [
            [name => "critic"],
            [wit  => "logic"],
        ],
    ]);
    is($node->{type}, 'noun', 'tree: type is noun');
    is($node->{name}, 'Agent', 'tree: name is Agent');
    is(scalar @{$node->{children}}, 2, 'tree: two children');
    is($node->{children}[0]{type}, 'adj', 'tree: first child is adj');
    is($node->{children}[0]{name}, 'name', 'tree: first adj name');
    is($node->{children}[0]{value}{type}, 'string', 'tree: value type');
    is($node->{children}[0]{value}{value}, 'critic', 'tree: value');
}

{
    my $node = tree([
        Pipeline => [
            [name => "test"],
            [Agent => [
                [name => "a"],
            ]],
            [Agent => [
                [name => "b"],
            ]],
        ],
    ]);
    is($node->{name}, 'Pipeline', 'tree: outer noun');
    my @agents = @{ find($node, 'Agent') };
    is(scalar @agents, 2, 'tree: two nested Agents');
    is($agents[0]{children}[0]{value}{value}, 'a');
    is($agents[1]{children}[0]{value}{value}, 'b');
}

{
    my $node = tree([
        X => [
            [tags => ["gui", "settings"]],
            [val  => 42],
        ],
    ]);
    my $tags = $node->{children}[0]{value};
    is($tags->{type}, 'list', 'tree: list type');
    is(scalar @{$tags->{items}}, 2, 'tree: two list items');
    is($tags->{items}[0]{value}, 'gui', 'tree: list item');
}

# --- where ---

{
    my $tree = Data::NExT::parse('A[ x("1") ] B[ x("2") ] A[ x("3") ]');
    my @as = @{ where($tree, sub { $_[0]{type} eq 'noun' && $_[0]{name} eq 'A' }) };
    is(scalar @as, 2, 'where: two A nodes');
}

{
    my $tree = Data::NExT::parse('X[ a("1") b("2") a("3") ]');
    my @as = @{ where($tree, sub { $_[0]{type} eq 'adj' && $_[0]{name} eq 'a' }) };
    is(scalar @as, 2, 'where: two a adjectives');
}

# --- equals ---

{
    my $a = Data::NExT::parse('Agent[ name("x") ]')->[0];
    my $b = Data::NExT::parse('Agent[ name("x") ]')->[0];
    ok(equals($a, $b), 'equals: identical trees');
}

{
    my $a = Data::NExT::parse('Agent[ name("x") ]')->[0];
    my $b = Data::NExT::parse('Agent[ name("y") ]')->[0];
    ok(!equals($a, $b), 'equals: different values');
}

{
    my $a = Data::NExT::parse('Agent[ name("x") ]')->[0];
    my $b = Data::NExT::parse('Agent[ name("x") wit("y") ]')->[0];
    ok(!equals($a, $b), 'equals: different child count');
}

{
    my $a = Data::NExT::parse('A[ ]')->[0];
    my $b = Data::NExT::parse('B[ ]')->[0];
    ok(!equals($a, $b), 'equals: different names');
}

# --- diff ---

{
    my $a = Data::NExT::parse('Agent[ name("x") ]')->[0];
    my $b = Data::NExT::parse('Agent[ name("y") ]')->[0];
    my @d = @{ diff($a, $b) };
    is(scalar @d, 1, 'diff: one difference');
    like($d[0], qr/value mismatch/, 'diff: value mismatch message');
}

{
    my $a = Data::NExT::parse('Agent[ name("x") ]')->[0];
    my $b = Data::NExT::parse('Agent[ name("x") wit("y") ]')->[0];
    my @d = @{ diff($a, $b) };
    is(scalar @d, 2, 'diff: two differences (count + extra child)');
    like($d[0], qr/child count/, 'diff: count message');
    like($d[1], qr/extra child/, 'diff: extra child message');
}

{
    my $a = Data::NExT::parse('A[ name("x") ]')->[0];
    my $b = Data::NExT::parse('B[ name("x") ]')->[0];
    my @d = @{ diff($a, $b) };
    is(scalar @d, 1, 'diff: name difference');
    like($d[0], qr/name mismatch/, 'diff: name message');
}

# --- require_adj ---

{
    my $tree = Data::NExT::parse('Agent[ name("x") ]')->[0];
    ok(require_adj($tree, 'name'), 'require_adj: present');
}

{
    my $tree = Data::NExT::parse('Agent[ name("x") ]')->[0];
    eval { require_adj($tree, 'missing') };
    like($@, qr/required adjective 'missing' missing/, 'require_adj: missing dies');
}

# --- require_child ---

{
    my $tree = Data::NExT::parse('Pipeline[ Agent[ ] ]')->[0];
    ok(require_child($tree, 'Agent'), 'require_child: present');
}

{
    my $tree = Data::NExT::parse('Pipeline[ ]')->[0];
    eval { require_child($tree, 'Agent') };
    like($@, qr/required child 'Agent' missing/, 'require_child: missing dies');
}

# --- validate ---

{
    my $tree = Data::NExT::parse('Agent[ name("x") ]');
    my @errors = validate($tree);
    is(scalar @errors, 0, 'validate: valid tree has no errors');
}

{
    my $tree = Data::NExT::parse('A[ ]');
    my @errors = validate($tree);
    is(scalar @errors, 0, 'validate: empty tree has no errors');
}

# --- to_hash with list ---

{
    my $tree = Data::NExT::parse('X[ tags(["gui" "settings"]) ]');
    my $h = to_hash($tree->[0]);
    is(ref $h->{tags}, 'ARRAY', 'to_hash: list is arrayref');
    is_deeply($h->{tags}, ['gui', 'settings'], 'to_hash: list values');
}

# --- tree builder roundtrip ---

{
    my $node = tree([
        Agent => [
            [name => "critic"],
            [wit  => "logic"],
        ],
    ]);
    my $text = to_text($node);
    my $reparsed = Data::NExT::parse($text);
    ok(equals($node, $reparsed->[0]), 'tree builder + to_text roundtrip');
}

done_testing();
