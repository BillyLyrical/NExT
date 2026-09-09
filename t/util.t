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
    require_adj require_child validate
    check_refs);

# --- find ---

{
    my $tree = Data::NExT::parse('Agent[ name("a") ] Pipeline[ ] Agent[ name("b") ]');
    my @agents = @{ find($tree, 'Agent') };
    is(scalar @agents, 2, 'find: two Agent nodes');
    is($agents[0]{Agent}{name}, 'a');
    is($agents[1]{Agent}{name}, 'b');
}

{
    my $tree = Data::NExT::parse('Outer[ Inner[ val("x") ] ]');
    my @inner = @{ find($tree, 'Inner') };
    is(scalar @inner, 1, 'find nested');
    is($inner[0]{Inner}{val}, 'x');
}

# --- find_adj ---

{
    my $tree = Data::NExT::parse('Agent[ name("a") wit("logic") ] Config[ name("b") ]');
    my @names = @{ find_adj($tree, 'name') };
    is(scalar @names, 2, 'find_adj: two name adjectives');
    is($names[0]{value}, 'a');
    is($names[1]{value}, 'b');
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
    ok(exists $first->{A}, 'find_first: returns first match');
}

{
    my $tree = Data::NExT::parse('A[ x("1") ]');
    my $miss = find_first($tree, 'Z');
    is($miss, undef, 'find_first: returns undef on miss');
}

# --- walk ---

{
    my $tree = Data::NExT::parse('A[ name("a") B[ name("b") ] ]');
    my @noun_keys;
    walk($tree, sub {
        my $node = shift;
        for my $key (keys %$node) {
            push @noun_keys, $key if ref $node->{$key} eq 'HASH';
        }
    });
    is_deeply(\@noun_keys, ['A', 'B'], 'walk visits all nouns');
}

{
    my $tree = Data::NExT::parse('X[ a("1") b("2") ]');
    my @adj_names;
    walk($tree, sub {
        my $node = shift;
        for my $key (keys %$node) {
            push @adj_names, $key if ref $node->{$key} ne 'HASH';
        }
    });
    is(scalar @adj_names, 2, 'walk visits adjectives');
}

# --- to_hash ---

{
    my $tree = Data::NExT::parse('Agent[ name("critic") wit("logic") ]');
    my $h = to_hash($tree->[0]);
    is($h->{Agent}{name}, 'critic', 'to_hash: string adj');
    is($h->{Agent}{wit}, 'logic', 'to_hash: second adj');
}

{
    my $tree = Data::NExT::parse('X[ val(42) flag(true) ]');
    my $h = to_hash($tree->[0]);
    is($h->{X}{val}, 42, 'to_hash: integer');
    is($h->{X}{flag}, 1, 'to_hash: boolean');
}

{
    my $tree = Data::NExT::parse('Outer[ Inner[ val("x") ] ]');
    my $h = to_hash($tree->[0]);
    is(ref $h->{Outer}{Inner}, 'HASH', 'to_hash: nested noun is hashref');
    is($h->{Outer}{Inner}{val}, 'x', 'to_hash: nested value');
}

# --- noun_names ---

{
    my $tree = Data::NExT::parse('A[ B[ C[ ] ] ] D[ ]');
    my @names = @{ noun_names($tree) };
    is(scalar @names, 4, 'noun_names: four nouns');
    ok(grep { $_ eq 'A' } @names, 'noun_names: contains A');
    ok(grep { $_ eq 'B' } @names, 'noun_names: contains B');
    ok(grep { $_ eq 'C' } @names, 'noun_names: contains C');
    ok(grep { $_ eq 'D' } @names, 'noun_names: contains D');
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
            name => "critic",
            wit  => "logic",
        ],
    ]);
    ok(exists $node->{Agent}, 'tree: has Agent key');
    is(ref $node->{Agent}, 'HASH', 'tree: Agent is hashref');
    is($node->{Agent}{name}, 'critic', 'tree: name value');
    is($node->{Agent}{wit}, 'logic', 'tree: wit value');
}

{
    my $node = tree([
        Pipeline => [
            name => "test",
            Agent => [
                name => "a",
            ],
            Agent => [
                name => "b",
            ],
        ],
    ]);
    ok(exists $node->{Pipeline}, 'tree: outer noun');
    my $pipeline = $node->{Pipeline};
    is(ref $pipeline->{Agent}, 'ARRAY', 'tree: Agent is array');
    is(scalar @{$pipeline->{Agent}}, 2, 'tree: two nested Agents');
    is($pipeline->{Agent}[0]{name}, 'a');
    is($pipeline->{Agent}[1]{name}, 'b');
}

{
    my $node = tree([
        X => [
            tags => ["gui", "settings"],
            val  => 42,
        ],
    ]);
    my $tags = $node->{X}{tags};
    is(ref $tags, 'ARRAY', 'tree: list is arrayref');
    is(scalar @$tags, 2, 'tree: two list items');
    is($tags->[0], 'gui', 'tree: list item');
}

# --- where ---

{
    my $tree = Data::NExT::parse('A[ x("1") ] B[ x("2") ] A[ x("3") ]');
    my @as = @{ where($tree, sub { exists $_[0]{A} }) };
    is(scalar @as, 2, 'where: two A nodes');
}

{
    my $tree = Data::NExT::parse('X[ a("1") b("2") a("3") ]');
    my @as = @{ where($tree, sub { $_[0]{a} && !ref $_[0]{a} }) };
    is(scalar @as, 1, 'where: one X node with a');
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
    is(scalar @d, 1, 'diff: one difference (missing key)');
    like($d[0], qr/missing in first tree/, 'diff: missing key message');
}

{
    my $a = Data::NExT::parse('A[ name("x") ]')->[0];
    my $b = Data::NExT::parse('B[ name("x") ]')->[0];
    my @d = @{ diff($a, $b) };
    is(scalar @d, 2, 'diff: two differences (A missing, B missing)');
    like($d[0], qr/missing/, 'diff: first missing message');
    like($d[1], qr/missing/, 'diff: second missing message');
}

# --- require_adj ---

{
    my $tree = Data::NExT::parse('Agent[ name("x") ]')->[0];
    ok(require_adj($tree->{Agent}, 'name'), 'require_adj: present');
}

{
    my $tree = Data::NExT::parse('Agent[ name("x") ]')->[0];
    eval { require_adj($tree->{Agent}, 'missing') };
    like($@, qr/required adjective 'missing' missing/, 'require_adj: missing dies');
}

# --- require_child ---

{
    my $tree = Data::NExT::parse('Pipeline[ Agent[ ] ]')->[0];
    ok(require_child($tree->{Pipeline}, 'Agent'), 'require_child: present');
}

{
    my $tree = Data::NExT::parse('Pipeline[ ]')->[0];
    eval { require_child($tree->{Pipeline}, 'Agent') };
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
    is(ref $h->{X}{tags}, 'ARRAY', 'to_hash: list is arrayref');
    is_deeply($h->{X}{tags}, ['gui', 'settings'], 'to_hash: list values');
}

# --- tree builder roundtrip ---

{
    my $node = tree([
        Agent => [
            name => "critic",
            wit  => "logic",
        ],
    ]);
    my $text = to_text($node);
    my $reparsed = Data::NExT::parse($text);
    ok(equals($node, $reparsed->[0]), 'tree builder + to_text roundtrip');
}

# --- check_refs ---

{
    my $tree = Data::NExT::parse('Button[ text(@cancel) ]');
    my $result = check_refs($tree);
    is(scalar @{$result->{warnings}}, 1, 'check_refs: one warning for single symbol');
    like($result->{warnings}[0], qr/\@cancel appears only once/, 'check_refs: warns about @cancel');
    is(scalar @{$result->{errors}}, 0, 'check_refs: no errors');
}

{
    my $tree = Data::NExT::parse('Button[ text(@cancel) ] Translate[ cancel("Annuler") ]');
    my $result = check_refs($tree);
    is(scalar @{$result->{warnings}}, 1, 'check_refs: still warns for @cancel');
    is(scalar @{$result->{errors}}, 0, 'check_refs: no errors');
}

{
    my $tree = Data::NExT::parse('A[ x(@foo) y(@bar) ] B[ z(@foo) ]');
    my $result = check_refs($tree);
    is(scalar @{$result->{warnings}}, 1, 'check_refs: @foo ok, @bar single');
    like($result->{warnings}[0], qr/\@bar/, 'check_refs: warns about @bar');
}

{
    my $tree = Data::NExT::parse('X[ a("hello") b(42) ]');
    my $result = check_refs($tree);
    is(scalar @{$result->{warnings}}, 0, 'check_refs: no symbols = no warnings');
    is(scalar @{$result->{errors}}, 0, 'check_refs: no errors');
}

done_testing();
