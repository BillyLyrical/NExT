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
    is($tree->[0]{type}, 'noun');
    is($tree->[0]{name}, 'Window');
    is(scalar @{$tree->[0]{children}}, 0, 'empty noun: no children');
}

# --- Noun with one adjective ---

{
    my $tree = Data::NExT::parse('Agent[ name("critic") ]');
    is(scalar @$tree, 1);
    my $agent = $tree->[0];
    is($agent->{name}, 'Agent');
    is(scalar @{$agent->{children}}, 1);
    is($agent->{children}[0]{type}, 'adj');
    is($agent->{children}[0]{name}, 'name');
    is($agent->{children}[0]{value}{type}, 'string');
    is($agent->{children}[0]{value}{value}, 'critic');
}

# --- Value types ---

{
    my $tree = Data::NExT::parse('X[ i(42) f(3.14) s("hello") t(true) f(false) sym(@cancel) ]');
    my @adj = @{$tree->[0]{children}};
    is(scalar @adj, 6, 'all value types: six adjectives');

    is($adj[0]{value}{type}, 'integer');
    is($adj[0]{value}{value}, 42);

    is($adj[1]{value}{type}, 'float');
    is($adj[1]{value}{value}, 3.14);

    is($adj[2]{value}{type}, 'string');
    is($adj[2]{value}{value}, 'hello');

    is($adj[3]{value}{type}, 'boolean');
    is($adj[3]{value}{value}, 1);

    is($adj[4]{value}{type}, 'boolean');
    is($adj[4]{value}{value}, 0);

    is($adj[5]{value}{type}, 'symbol');
    is($adj[5]{value}{value}, '@cancel');
}

# --- String escapes ---

{
    my $tree = Data::NExT::parse('X[ s("line1\\nline2") t("tab\\there") q("say \\"hi\\"") b("back\\\\slash") ]');
    my @adj = @{$tree->[0]{children}};
    is($adj[0]{value}{value}, "line1\nline2", 'string escape \\n');
    is($adj[1]{value}{value}, "tab\there", 'string escape \\t');
    is($adj[2]{value}{value}, 'say "hi"', 'string escape \\"');
    is($adj[3]{value}{value}, 'back\\slash', 'string escape \\\\');
}

# --- Nested nouns ---

{
    my $tree = Data::NExT::parse('Outer[ Inner[ val("x") ] ]');
    my $outer = $tree->[0];
    is($outer->{name}, 'Outer');
    is(scalar @{$outer->{children}}, 1);
    my $inner = $outer->{children}[0];
    is($inner->{type}, 'noun');
    is($inner->{name}, 'Inner');
    is($inner->{children}[0]{value}{value}, 'x');
}

# --- Multiple siblings ---

{
    my $tree = Data::NExT::parse('A[ ] B[ ] C[ ]');
    is(scalar @$tree, 3, 'three top-level siblings');
    is($tree->[0]{name}, 'A');
    is($tree->[1]{name}, 'B');
    is($tree->[2]{name}, 'C');
}

# --- Mixed adj/noun order inside a noun ---

{
    my $tree = Data::NExT::parse('Box[ Child[ ] label("test") ]');
    my $box = $tree->[0];
    is(scalar @{$box->{children}}, 2);
    is($box->{children}[0]{type}, 'noun');
    is($box->{children}[0]{name}, 'Child');
    is($box->{children}[1]{type}, 'adj');
    is($box->{children}[1]{name}, 'label');
}

# --- Comments (block + inline) ---

{
    my $input = <<'EOF';
# block comment
X[ name("a") ] # inline comment
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 1, 'comments ignored');
    is($tree->[0]{name}, 'X');
}

# --- Adjective with hyphen in name ---

{
    my $tree = Data::NExT::parse('X[ max-length(100) ]');
    is($tree->[0]{children}[0]{name}, 'max-length');
    is($tree->[0]{children}[0]{value}{value}, 100);
}

# --- Deep nesting ---

{
    my $input = 'A[ B[ C[ D[ val("deep") ] ] ] ]';
    my $tree = Data::NExT::parse($input);
    is($tree->[0]{name}, 'A');
    is($tree->[0]{children}[0]{name}, 'B');
    is($tree->[0]{children}[0]{children}[0]{name}, 'C');
    is($tree->[0]{children}[0]{children}[0]{children}[0]{name}, 'D');
    is($tree->[0]{children}[0]{children}[0]{children}[0]{children}[0]{value}{value}, 'deep');
}

# --- Object as value (inline noun) ---

{
    my $tree = Data::NExT::parse('X[ child( Var[ bind("x") ] ) ]');
    my $adj = $tree->[0]{children}[0];
    is($adj->{type}, 'adj');
    is($adj->{value}{type}, 'noun');
    is($adj->{value}{name}, 'Var');
    is($adj->{value}{children}[0]{value}{value}, 'x');
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
    is($tree->[0]{name}, 'Pipeline');
    is($tree->[1]{name}, 'Agent');
    is(scalar @{$tree->[0]{children}}, 2);
    is(scalar @{$tree->[1]{children}}, 4);
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
    my $win = $tree->[0];
    is($win->{name}, 'Window');
    is(scalar @{$win->{children}}, 4);
    my $box = $win->{children}[3];
    is($box->{type}, 'noun');
    is($box->{name}, 'Box');
    is(scalar @{$box->{children}}, 3);
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
    is($tree->[0]{name}, 'Database');
    is(scalar @{$tree->[0]{children}}, 4);
    my $pool = $tree->[0]{children}[3];
    is($pool->{name}, 'Pool');
    is(scalar @{$pool->{children}}, 3);
    is($pool->{children}[0]{value}{value}, 5);
    is($pool->{children}[1]{value}{value}, 20);
    is($pool->{children}[2]{value}{value}, 30);
}

# --- Zero value ---

{
    my $tree = Data::NExT::parse('X[ val(0) ]');
    is($tree->[0]{children}[0]{value}{value}, 0);
}

# --- Large integer ---

{
    my $tree = Data::NExT::parse('X[ val(1000000) ]');
    is($tree->[0]{children}[0]{value}{value}, 1000000);
}

# --- Float without leading digit ---

{
    my $tree = Data::NExT::parse('X[ val(0.5) ]');
    is($tree->[0]{children}[0]{value}{type}, 'float');
    is($tree->[0]{children}[0]{value}{value}, 0.5);
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

# --- Line tracking ---

{
    my $input = <<'EOF';
X[
    name("a")
    val(42)
]
EOF
    my $tree = Data::NExT::parse($input);
    is($tree->[0]{line}, 1, 'noun line = 1');
    is($tree->[0]{children}[0]{line}, 2, 'adj line = 2');
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
    is($tree->[0]{name}, 'A');
    is($tree->[1]{name}, 'B');
}

# --- Boolean that is a prefix of a longer word is not a boolean ---

{
    my $tree = Data::NExT::parse('X[ truthy("val") ]');
    is($tree->[0]{children}[0]{name}, 'truthy');
    is($tree->[0]{children}[0]{value}{type}, 'string');
}

# --- Adjacent nouns at same level ---

{
    my $tree = Data::NExT::parse('Outer[ A[ ] B[ ] ]');
    my $outer = $tree->[0];
    is(scalar @{$outer->{children}}, 2);
    is($outer->{children}[0]{name}, 'A');
    is($outer->{children}[1]{name}, 'B');
}

# --- Empty list ---

{
    my $tree = Data::NExT::parse('X[ items([]) ]');
    my $adj = $tree->[0]{children}[0];
    is($adj->{type}, 'adj');
    is($adj->{name}, 'items');
    is($adj->{value}{type}, 'list');
    is(scalar @{$adj->{value}{items}}, 0, 'empty list: zero items');
}

# --- List of strings ---

{
    my $tree = Data::NExT::parse('X[ tags(["gui" "settings" "dialog"]) ]');
    my $list = $tree->[0]{children}[0]{value};
    is($list->{type}, 'list');
    is(scalar @{$list->{items}}, 3, 'string list: three items');
    is($list->{items}[0]{type}, 'string');
    is($list->{items}[0]{value}, 'gui');
    is($list->{items}[1]{value}, 'settings');
    is($list->{items}[2]{value}, 'dialog');
}

# --- List of integers ---

{
    my $tree = Data::NExT::parse('X[ nums([1 2 3]) ]');
    my $list = $tree->[0]{children}[0]{value};
    is($list->{type}, 'list');
    is(scalar @{$list->{items}}, 3, 'int list: three items');
    is($list->{items}[0]{type}, 'integer');
    is($list->{items}[0]{value}, 1);
    is($list->{items}[1]{value}, 2);
    is($list->{items}[2]{value}, 3);
}

# --- List of floats ---

{
    my $tree = Data::NExT::parse('X[ coords([1.0 2.5 3.3]) ]');
    my $list = $tree->[0]{children}[0]{value};
    is(scalar @{$list->{items}}, 3);
    is($list->{items}[0]{type}, 'float');
    is($list->{items}[0]{value}, 1.0);
    is($list->{items}[2]{value}, 3.3);
}

# --- List of booleans ---

{
    my $tree = Data::NExT::parse('X[ flags([true false true]) ]');
    my $list = $tree->[0]{children}[0]{value};
    is(scalar @{$list->{items}}, 3);
    is($list->{items}[0]{type}, 'boolean');
    is($list->{items}[0]{value}, 1);
    is($list->{items}[1]{value}, 0);
}

# --- List of symbols ---

{
    my $tree = Data::NExT::parse('X[ syms([@a @b @c]) ]');
    my $list = $tree->[0]{children}[0]{value};
    is(scalar @{$list->{items}}, 3);
    is($list->{items}[0]{type}, 'symbol');
    is($list->{items}[0]{value}, '@a');
    is($list->{items}[2]{value}, '@c');
}

# --- List with comments between items ---

{
    my $tree = Data::NExT::parse("X[ items([ # first\n\"a\" # second\n\"b\" ]) ]");
    my $list = $tree->[0]{children}[0]{value};
    is(scalar @{$list->{items}}, 2, 'list with comments: two items');
    is($list->{items}[0]{value}, 'a');
    is($list->{items}[1]{value}, 'b');
}

# --- List inside nested noun ---

{
    my $tree = Data::NExT::parse('Outer[ Inner[ tags(["a" "b"]) ] ]');
    my $inner = $tree->[0]{children}[0];
    is($inner->{name}, 'Inner');
    my $list = $inner->{children}[0]{value};
    is($list->{type}, 'list');
    is(scalar @{$list->{items}}, 2);
}

# --- Mixed nouns and lists at top level ---

{
    my $input = <<'EOF';
Item[ name("a") tags(["x" "y"]) ]
Item[ name("b") tags(["z"]) ]
EOF
    my $tree = Data::NExT::parse($input);
    is(scalar @$tree, 2, 'two items with lists');
    is($tree->[0]{children}[1]{value}{type}, 'list');
    is(scalar @{$tree->[0]{children}[1]{value}{items}}, 2);
    is(scalar @{$tree->[1]{children}[1]{value}{items}}, 1);
}

# --- Heredoc (triple-quoted) strings ---

{
    my $input = 'X[ desc("""Hello world""") ]';
    my $tree = Data::NExT::parse($input);
    is($tree->[0]{children}[0]{value}{type}, 'string', 'heredoc: type is string');
    is($tree->[0]{children}[0]{value}{value}, 'Hello world', 'heredoc: value correct');
}

{
    my $input = qq{X[ desc("""\nLine 1\nLine 2\nLine 3\n""") ]};
    my $tree = Data::NExT::parse($input);
    my $val = $tree->[0]{children}[0]{value}{value};
    like($val, qr/Line 1/, 'heredoc: multi-line contains Line 1');
    like($val, qr/Line 2/, 'heredoc: multi-line contains Line 2');
    like($val, qr/Line 3/, 'heredoc: multi-line contains Line 3');
    is($val, "\nLine 1\nLine 2\nLine 3\n", 'heredoc: exact content preserved');
}

{
    my $input = q{X[ desc("""Contains "quotes" inside""") ]};
    my $tree = Data::NExT::parse($input);
    is($tree->[0]{children}[0]{value}{value}, 'Contains "quotes" inside', 'heredoc: embedded quotes OK');
}

{
    my $input = qq{X[ a("normal") b("""multi\nline""") c(42) ]};
    my $tree = Data::NExT::parse($input);
    is(scalar @{$tree->[0]{children}}, 3, 'heredoc: mixed with other values');
    is($tree->[0]{children}[0]{value}{value}, 'normal', 'heredoc: regular string OK');
    like($tree->[0]{children}[1]{value}{value}, qr/multi\nline/, 'heredoc: multi-line OK');
    is($tree->[0]{children}[2]{value}{value}, 42, 'heredoc: integer OK');
}

{
    $Data::NExT::ERROR = undef;
    my $input = 'X[ desc("""unterminated )';
    my $tree = Data::NExT::parse($input);
    ok(defined $Data::NExT::ERROR, 'heredoc: unterminated sets ERROR');
    like($Data::NExT::ERROR, qr/unterminated heredoc/, 'heredoc: error message correct');
}

done_testing();
