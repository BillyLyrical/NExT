use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::NExT;

# --- Empty / trivial ---

{
    my $tree = Data::NExT::parse('');
    is($Data::NExT::ERROR, undef, 'empty input: no error');
    is(scalar @$tree, 0, 'empty input: zero blocks');
}

{
    my $tree = Data::NExT::parse('# just a comment');
    is(scalar @$tree, 0, 'comment-only input: zero blocks');
}

# --- Single empty noun ---

{
    my $tree = Data::NExT::parse('Window[ ]');
    is(scalar @$tree, 1, 'empty noun: one block');
    ok(exists $tree->[0]{Window}, 'empty noun: has Window key');
    is(ref $tree->[0]{Window}, 'HASH', 'empty noun: Window is hashref');
    is(scalar keys %{$tree->[0]{Window}{_adj}}, 0, 'empty noun: no adjectives');
    is(scalar @{$tree->[0]{Window}{_children}}, 0, 'empty noun: no children');
}

# --- Noun with one adjective ---

{
    my $tree = Data::NExT::parse('Agent[ name("critic") ]');
    is(scalar @$tree, 1);
    my $agent = $tree->[0]{Agent};
    is($agent->{_adj}{name}, 'critic');
}

# --- Value types ---

{
    my $tree = Data::NExT::parse('X[ i(42) f(3.14) s("hello") t(true) fs(false) sym(@cancel) ]');
    my $x = $tree->[0]{X};
    is(scalar keys %{$x->{_adj}}, 6, 'all value types: six adjectives');

    is($x->{_adj}{i}, 42);
    is($x->{_adj}{f}, 3.14);
    is($x->{_adj}{s}, 'hello');
    is($x->{_adj}{t}, 1);
    is($x->{_adj}{fs}, 0);
    is($x->{_adj}{sym}, '@cancel');
}

# --- String escapes ---

{
    my $tree = Data::NExT::parse('X[ s("line1\\nline2") t("tab\\there") q("say \\"hi\\"") b("back\\\\slash") ]');
    my $x = $tree->[0]{X};
    is($x->{_adj}{s}, "line1\nline2", 'string escape \\n');
    is($x->{_adj}{t}, "tab\there", 'string escape \\t');
    is($x->{_adj}{q}, 'say "hi"', 'string escape \\"');
    is($x->{_adj}{b}, 'back\\slash', 'string escape \\\\');
}

# --- Nested nouns ---

{
    my $tree = Data::NExT::parse('Outer[ Inner[ val("x") ] ]');
    my $outer = $tree->[0]{Outer};
    my $inner = $outer->{_children}[0];
    ok(exists $inner->{Inner}, 'nested noun exists');
    is(ref $inner->{Inner}, 'HASH', 'nested noun is hashref');
    is($inner->{Inner}{_adj}{val}, 'x');
}

# --- Multiple siblings ---

{
    my $tree = Data::NExT::parse('A[ ] B[ ] C[ ]');
    is(scalar @$tree, 3, 'three top-level siblings');
    ok(exists $tree->[0]{A}, 'first sibling is A');
    ok(exists $tree->[1]{B}, 'second sibling is B');
    ok(exists $tree->[2]{C}, 'third sibling is C');
}

# --- Mixed adj/noun order inside a noun ---

{
    my $tree = Data::NExT::parse('Box[ Child[ ] label("test") ]');
    my $box = $tree->[0]{Box};
    is(scalar keys %{$box->{_adj}}, 1);
    is(scalar @{$box->{_children}}, 1);
    my $child = $box->{_children}[0];
    ok(exists $child->{Child}, 'noun child exists');
    is($box->{_adj}{label}, 'test');
}

# --- Comments (block + inline) ---

{
    my $input = <<'EOF';
# block comment
X[ name("a") ] # inline comment
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 1, 'comments ignored');
    ok(exists $tree->[0]{X}, 'X noun exists');
}

# --- Adjective with hyphen in name ---

{
    my $tree = Data::NExT::parse('X[ max-length(100) ]');
    is($tree->[0]{X}{_adj}{'max-length'}, 100);
}

# --- Deep nesting ---

{
    my $input = 'A[ B[ C[ D[ val("deep") ] ] ] ]';
    my $tree = Data::NExT::parse($input);
    my $a = $tree->[0]{A}{_children}[0];
    my $b = $a->{B}{_children}[0];
    my $c = $b->{C}{_children}[0];
    my $d = $c->{D};
    is($d->{_adj}{val}, 'deep');
}

# --- Object as value (inline noun) ---

{
    my $tree = Data::NExT::parse('X[ child( Var[ bind("x") ] ) ]');
    my $x = $tree->[0]{X};
    is(ref $x->{_adj}{child}, 'HASH', 'inline noun is hashref');
    is($x->{_adj}{child}{Var}{_adj}{bind}, 'x');
}

# --- Full pipeline example from spec ---

{
    my $input = <<'EOF';
Pipeline[
    name("code-review")
    about("Multi-agent code review")
]
Agent[
    name("critic")
    wit("logic")
    subscribe("git-context.output")
    publish("critic.output")
]
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 2, 'pipeline example: two top-level nouns');
    is($tree->[0]{Pipeline}{_adj}{name}, 'code-review');
    is($tree->[0]{Pipeline}{_adj}{about}, 'Multi-agent code review');
    is($tree->[1]{Agent}{_adj}{name}, 'critic');
    is($tree->[1]{Agent}{_adj}{wit}, 'logic');
    is($tree->[1]{Agent}{_adj}{subscribe}, 'git-context.output');
    is($tree->[1]{Agent}{_adj}{publish}, 'critic.output');
}

# --- GUI example from spec ---

{
    my $input = <<'EOF';
Window[
    title("Settings")
    width(500)
    height(400)
    Box[
        orientation("vertical")
        Label[ text("Username") ]
        Button[ text("Save") onclick("save") ]
    ]
]
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 1);
    my $win = $tree->[0]{Window};
    is($win->{_adj}{title}, 'Settings');
    is($win->{_adj}{width}, 500);
    is($win->{_adj}{height}, 400);
    my $box = $win->{_children}[0]{Box};
    is($box->{_adj}{orientation}, 'vertical');
    my $label = $box->{_children}[0]{Label};
    is($label->{_adj}{text}, 'Username');
    my $button = $box->{_children}[1]{Button};
    is($button->{_adj}{text}, 'Save');
    is($button->{_adj}{onclick}, 'save');
}

# --- Config example from spec ---

{
    my $input = <<'EOF';
Database[
    host("localhost")
    port(5432)
    name("myapp")
    Pool[
        min(5)
        max(20)
        timeout(30)
    ]
]
EOF
    my $tree = Data::NExT::parse($input);
    my $db = $tree->[0]{Database};
    is($db->{_adj}{host}, 'localhost');
    is($db->{_adj}{port}, 5432);
    is($db->{_adj}{name}, 'myapp');
    my $pool = $db->{_children}[0]{Pool};
    is($pool->{_adj}{min}, 5);
    is($pool->{_adj}{max}, 20);
    is($pool->{_adj}{timeout}, 30);
}

# --- Zero value ---

{
    my $tree = Data::NExT::parse('X[ val(0) ]');
    is($tree->[0]{X}{_adj}{val}, 0);
}

# --- Large integer ---

{
    my $tree = Data::NExT::parse('X[ val(1000000) ]');
    is($tree->[0]{X}{_adj}{val}, 1000000);
}

# --- Float without leading digit ---

{
    my $tree = Data::NExT::parse('X[ val(0.5) ]');
    is($tree->[0]{X}{_adj}{val}, 0.5);
    ok(!($tree->[0]{X}{_adj}{val} =~ /\./ && int($tree->[0]{X}{_adj}{val}) == $tree->[0]{X}{_adj}{val}), '0.5 is float, not integer');
}

# --- Unterminated string error ---

{
    $Data::NExT::ERROR = undef;
    my $tree = Data::NExT::parse('X[ name("unterminated )');
    ok(defined $Data::NExT::ERROR, 'unterminated string sets ERROR');
    ok($Data::NExT::ERROR =~ /unterminated/, 'error mentions unterminated');
}

# --- Unexpected character error ---

{
    $Data::NExT::ERROR = undef;
    my $tree = Data::NExT::parse('X[ name("ok") $ ]');
    ok(defined $Data::NExT::ERROR, 'unexpected char sets ERROR');
    ok($Data::NExT::ERROR =~ /unexpected/, 'error mentions unexpected');
}

# --- Missing closing paren error ---

{
    $Data::NExT::ERROR = undef;
    my $tree = Data::NExT::parse('X[ name("ok" ]');
    ok(defined $Data::NExT::ERROR, 'missing ) sets ERROR');
}

# --- Missing closing bracket error ---

{
    $Data::NExT::ERROR = undef;
    my $tree = Data::NExT::parse('X[ name("ok") ');
    ok(defined $Data::NExT::ERROR, 'missing ] sets ERROR');
}

# --- Adjective without value error ---

{
    $Data::NExT::ERROR = undef;
    my $tree = Data::NExT::parse('X[ name ]');
    ok(defined $Data::NExT::ERROR, 'adj without parens sets ERROR');
}

# --- Number-only adjective name is invalid ---

{
    $Data::NExT::ERROR = undef;
    my $tree = Data::NExT::parse('X[ 123("val") ]');
    ok(defined $Data::NExT::ERROR, 'starts-with-digit noun is error');
}

# --- Multiple top-level blocks with comments between ---

{
    my $input = <<'EOF';
A[ ]
# separator
B[ x("1") ]
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 2);
    ok(exists $tree->[0]{A}, 'first block is A');
    is($tree->[1]{B}{_adj}{x}, '1');
}

# --- Boolean that is a prefix of a longer word is not a boolean ---

{
    my $tree = Data::NExT::parse('X[ truthy("val") ]');
    is($tree->[0]{X}{_adj}{truthy}, 'val');
}

# --- Adjacent nouns at same level ---

{
    my $tree = Data::NExT::parse('Outer[ A[ ] B[ ] ]');
    my $outer = $tree->[0]{Outer};
    is(scalar @{$outer->{_children}}, 2);
    ok(exists $outer->{_children}[0]{A}, 'first child is A');
    ok(exists $outer->{_children}[1]{B}, 'second child is B');
}

# --- Empty list ---

{
    my $tree = Data::NExT::parse('X[ items([]) ]');
    my $x = $tree->[0]{X};
    is(ref $x->{_adj}{items}, 'ARRAY', 'empty list is arrayref');
    is(scalar @{$x->{_adj}{items}}, 0, 'empty list: zero items');
}

# --- List of strings ---

{
    my $tree = Data::NExT::parse('X[ tags(["gui" "settings" "dialog"]) ]');
    my $list = $tree->[0]{X}{_adj}{tags};
    is(ref $list, 'ARRAY', 'list is arrayref');
    is(scalar @$list, 3, 'string list: three items');
    is($list->[0], 'gui');
    is($list->[1], 'settings');
    is($list->[2], 'dialog');
}

# --- List of integers ---

{
    my $tree = Data::NExT::parse('X[ nums([1 2 3]) ]');
    my $list = $tree->[0]{X}{_adj}{nums};
    is(ref $list, 'ARRAY', 'list is arrayref');
    is(scalar @$list, 3, 'int list: three items');
    is($list->[0], 1);
    is($list->[1], 2);
    is($list->[2], 3);
}

# --- List of floats ---

{
    my $tree = Data::NExT::parse('X[ coords([1.0 2.5 3.3]) ]');
    my $list = $tree->[0]{X}{_adj}{coords};
    is(scalar @$list, 3);
    is($list->[0], 1.0);
    is($list->[2], 3.3);
}

# --- List of booleans ---

{
    my $tree = Data::NExT::parse('X[ flags([true false true]) ]');
    my $list = $tree->[0]{X}{_adj}{flags};
    is(scalar @$list, 3);
    is($list->[0], 1);
    is($list->[1], 0);
    is($list->[2], 1);
}

# --- List of symbols ---

{
    my $tree = Data::NExT::parse('X[ syms([@a @b @c]) ]');
    my $list = $tree->[0]{X}{_adj}{syms};
    is(scalar @$list, 3);
    is($list->[0], '@a');
    is($list->[2], '@c');
}

# --- List with comments between items ---

{
    my $tree = Data::NExT::parse("X[ items([ # first\n\"a\" # second\n\"b\" ]) ]");
    my $list = $tree->[0]{X}{_adj}{items};
    is(scalar @$list, 2, 'list with comments: two items');
    is($list->[0], 'a');
    is($list->[1], 'b');
}

# --- List inside nested noun ---

{
    my $tree = Data::NExT::parse('Outer[ Inner[ tags(["a" "b"]) ] ]');
    my $inner = $tree->[0]{Outer}{_children}[0]{Inner};
    my $list = $inner->{_adj}{tags};
    is(ref $list, 'ARRAY', 'list is arrayref');
    is(scalar @$list, 2);
}

# --- Mixed nouns and lists at top level ---

{
    my $input = <<'EOF';
Item[ name("a") tags(["x" "y"]) ]
Item[ name("b") tags(["z"]) ]
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 2, 'two items with lists');
    is(scalar @{$tree->[0]{Item}{_adj}{tags}}, 2);
    is(scalar @{$tree->[1]{Item}{_adj}{tags}}, 1);
}

# --- Heredoc (triple-quoted) strings ---

{
    my $input = "X[ desc(\"\"\"\nHello world\n\"\"\") ]";
    my $tree = Data::NExT::parse($input);
    is($tree->[0]{X}{_adj}{desc}, "Hello world\n", 'heredoc: value correct');
}

{
    my $input = "X[ desc(\"\"\"\nLine 1\nLine 2\nLine 3\n\"\"\") ]";
    my $tree = Data::NExT::parse($input);
    my $val = $tree->[0]{X}{_adj}{desc};
    like($val, qr/Line 1/, 'heredoc: multi-line contains Line 1');
    like($val, qr/Line 2/, 'heredoc: multi-line contains Line 2');
    like($val, qr/Line 3/, 'heredoc: multi-line contains Line 3');
    is($val, "Line 1\nLine 2\nLine 3\n", 'heredoc: exact content preserved');
}

{
    my $input = "X[ desc(\"\"\"\nContains \"quotes\" inside\n\"\"\") ]";
    my $tree = Data::NExT::parse($input);
    is($tree->[0]{X}{_adj}{desc}, "Contains \"quotes\" inside\n", 'heredoc: embedded quotes OK');
}

{
    my $input = "X[ a(\"normal\") b(\"\"\"\nmulti\nline\n\"\"\") c(42) ]";
    my $tree = Data::NExT::parse($input);
    my $x = $tree->[0]{X};
    is(scalar keys %{$x->{_adj}}, 3, 'heredoc: mixed with other values');
    is($x->{_adj}{a}, 'normal', 'heredoc: regular string OK');
    like($x->{_adj}{b}, qr/multi\nline/, 'heredoc: multi-line OK');
    is($x->{_adj}{c}, 42, 'heredoc: integer OK');
}

{
    $Data::NExT::ERROR = undef;
    my $input = "X[ desc(\"\"\"\nunterminated";
    my $tree = Data::NExT::parse($input);
    ok(defined $Data::NExT::ERROR, 'heredoc: unterminated sets ERROR');
    like($Data::NExT::ERROR, qr/unterminated heredoc/, 'heredoc: error message correct');
}

# --- Heredoc block format enforcement ---

{
    $Data::NExT::ERROR = undef;
    my $input = 'X[ desc("""inline text""") ]';
    my $tree = Data::NExT::parse($input);
    ok(defined $Data::NExT::ERROR, 'heredoc: inline without newline sets ERROR');
    like($Data::NExT::ERROR, qr/must be followed by newline/, 'heredoc: error mentions newline');
}

{
    $Data::NExT::ERROR = undef;
    my $input = "X[ desc(\"\"\"\ntext\"\"\") ]";
    my $tree = Data::NExT::parse($input);
    ok(defined $Data::NExT::ERROR, 'heredoc: closing not on own line sets ERROR');
    like($Data::NExT::ERROR, qr/must be on its own line/, 'heredoc: error mentions own line');
}

# --- Duplicate child nouns ---

{
    my $input = <<'EOF';
List[
    Item[ name("one") ]
    Item[ name("two") ]
    Item[ name("three") ]
]
EOF
    my $tree = Data::NExT::parse($input);
    ok(!defined $Data::NExT::ERROR, 'duplicate children: no parse error');
    my $list = $tree->[0]{List};
    is(scalar @{$list->{_children}}, 3, 'duplicate children: three Item children');

    my $c0 = $list->{_children}[0]{Item};
    my $c1 = $list->{_children}[1]{Item};
    my $c2 = $list->{_children}[2]{Item};
    is($c0->{_adj}{name}, 'one',   'duplicate children: first child correct');
    is($c1->{_adj}{name}, 'two',   'duplicate children: second child correct');
    is($c2->{_adj}{name}, 'three', 'duplicate children: third child correct');
}

# --- Duplicate children with mixed adj/nouns ---

{
    my $input = <<'EOF';
Pipeline[
    name("test")
    Agent[ name("a") ]
    Agent[ name("b") ]
    Agent[ name("c") ]
]
EOF
    my $tree = Data::NExT::parse($input);
    my $pipeline = $tree->[0]{Pipeline};
    is($pipeline->{_adj}{name}, 'test', 'mixed: parent adj preserved');
    is(scalar @{$pipeline->{_children}}, 3, 'mixed: three Agent children');
    is($pipeline->{_children}[0]{Agent}{_adj}{name}, 'a', 'mixed: first agent');
    is($pipeline->{_children}[1]{Agent}{_adj}{name}, 'b', 'mixed: second agent');
    is($pipeline->{_children}[2]{Agent}{_adj}{name}, 'c', 'mixed: third agent');
}

# --- Single child (no duplication) ---

{
    my $tree = Data::NExT::parse('Parent[ Child[ val("only") ] ]');
    my $parent = $tree->[0]{Parent};
    is(scalar @{$parent->{_children}}, 1, 'single child: one child');
    my $child = $parent->{_children}[0]{Child};
    is($child->{_adj}{val}, 'only', 'single child: value correct');
}

done_testing();
