use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::NExT::Template;
use File::Temp qw(tempfile tempdir);
use File::Spec;

my $tmpdir = tempdir(CLEANUP => 1);

# --- Simple variable ---

{
    my $t = Data::NExT::Template->new(cli_vars => { NAME => 'alice' });
    my $out = $t->preprocess('name("${NAME}")');
    is($out, 'name("alice")', 'simple variable from CLI');
}

# --- Variable default ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess('port(${PORT:5432})');
    is($out, 'port(5432)', 'variable with default');
}

# --- Variable undefined, no default ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess('host("${MISSING}")');
    is($out, 'host("")', 'undefined variable becomes empty');
}

# --- CLI overrides config ---

{
    my $t = Data::NExT::Template->new(
        config   => { PORT => '8080' },
        cli_vars => { PORT => '3000' },
    );
    my $out = $t->preprocess('port(${PORT})');
    is($out, 'port(3000)', 'CLI overrides config');
}

# --- Config overrides ENV ---

{
    local $ENV{TEST_PORT} = '9090';
    my $t = Data::NExT::Template->new(config => { TEST_PORT => '8080' });
    my $out = $t->preprocess('port(${TEST_PORT})');
    is($out, 'port(8080)', 'config overrides ENV');
}

# --- ENV fallback ---

{
    local $ENV{TEST_HOST} = 'from-env';
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess('host("${TEST_HOST}")');
    is($out, 'host("from-env")', 'ENV fallback works');
}

# --- Path variable ---

{
    my $t = Data::NExT::Template->new(
        config => { db => { host => 'localhost', pool => { min => 5 } } },
    );
    my $out = $t->preprocess('${db/host} ${db/pool/min}');
    is($out, 'localhost 5', 'path variable traversal');
}

# --- Path variable with default ---

{
    my $t = Data::NExT::Template->new(config => {});
    my $out = $t->preprocess('${db/host:default-host}');
    is($out, 'default-host', 'path variable with default');
}

# --- Fallback chain ---

{
    my $t = Data::NExT::Template->new(config => { SERVER => 'from-server' });
    my $out = $t->preprocess('${HOST|SERVER:localhost}');
    is($out, 'from-server', 'fallback chain: second name hits');
}

# --- Fallback chain first hit ---

{
    my $t = Data::NExT::Template->new(config => { HOST => 'from-host', SERVER => 'from-server' });
    my $out = $t->preprocess('${HOST|SERVER:localhost}');
    is($out, 'from-host', 'fallback chain: first name hits');
}

# --- Fallback chain all miss ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess('${HOST|SERVER:localhost}');
    is($out, 'localhost', 'fallback chain: default used');
}

# --- Fallback chain no default ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess('${HOST|SERVER}');
    is($out, '', 'fallback chain: no default, empty string');
}

# --- %Ifdef true ---

{
    my $t = Data::NExT::Template->new(cli_vars => { DEBUG => '1' });
    my $out = $t->preprocess("before\n%Ifdef(\"DEBUG\")\nlog(\"on\")\n%Endif\nafter");
    like($out, qr/log\("on"\)/, '%Ifdef: content included when var set');
    like($out, qr/before/, '%Ifdef: surrounding content preserved');
    like($out, qr/after/, '%Ifdef: content after block preserved');
}

# --- %Ifdef false ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("%Ifdef(\"MISSING\")\nlog(\"on\")\n%Endif");
    is($out, '', '%Ifdef: content removed when var missing');
}

# --- %Ifndef ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("%Ifndef(\"MISSING\")\ndefault(\"val\")\n%Endif");
    like($out, qr/default\("val"\)/, '%Ifndef: content included when var missing');
}

# --- %Ifdef with %Else ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("%Ifdef(\"MISSING\")\nnope\n%Else\nyes\n%Endif");
    like($out, qr/yes/, '%Ifdef with Else: else branch taken');
    unlike($out, qr/nope/, '%Ifdef with Else: then branch skipped');
}

# --- Nested conditionals ---

{
    my $t = Data::NExT::Template->new(cli_vars => { A => '1' });
    my $out = $t->preprocess("%Ifdef(\"A\")\nouter\n%Ifdef(\"B\")\ninner\n%Endif\n%Endif");
    like($out, qr/outer/, 'nested: outer included');
    unlike($out, qr/inner/, 'nested: inner excluded (B missing)');
}

# --- Unclosed %Ifdef ---

{
    my $t = Data::NExT::Template->new;
    eval { $t->preprocess("%Ifdef(\"X\")\ncontent\n") };
    like($@, qr/unclosed %Ifdef/, 'unclosed %Ifdef dies');
}

# --- %Ignore block ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("before\n%Ignore\nstuff\n%EndIgnore\nafter");
    like($out, qr/before/, '%Ignore: before preserved');
    unlike($out, qr/stuff/, '%Ignore: content removed');
    like($out, qr/after/, '%Ignore: after preserved');
}

# --- Nested %Ignore ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("a\n%Ignore\nx\n%Ignore\ny\n%EndIgnore\nz\n%EndIgnore\nb");
    like($out, qr/^a\n/, '%Ignore nested: start');
    like($out, qr/\nb$/, '%Ignore nested: end');
    unlike($out, qr/[xyz]/, '%Ignore nested: all content removed');
}

# --- Unclosed %Ignore ---

{
    my $t = Data::NExT::Template->new;
    eval { $t->preprocess("%Ignore\nstuff\n") };
    like($@, qr/unclosed %Ignore/, 'unclosed %Ignore dies');
}

# --- %Include ---

{
    my ($fh, $filename) = tempfile(DIR => $tmpdir, SUFFIX => '.nx');
    print $fh "Included[\n    val(\"hello\")\n]\n";
    close $fh;

    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("%Include(\"$filename\")");
    like($out, qr/Included\[/, '%Include: file content inlined');
    like($out, qr/val\("hello"\)/, '%Include: content correct');
}

# --- %OptInclude missing ---

{
    my $t = Data::NExT::Template->new;
    my $out = $t->preprocess("before\n%OptInclude(\"nonexistent.nx\")\nafter");
    like($out, qr/before/, '%OptInclude missing: before preserved');
    like($out, qr/after/, '%OptInclude missing: after preserved');
    unlike($out, qr/Include/, '%OptInclude missing: no error, empty output');
}

# --- %Include missing ---

{
    my $t = Data::NExT::Template->new;
    eval { $t->preprocess("%Include(\"nonexistent.nx\")") };
    like($@, qr/include file not found/, '%Include missing dies');
}

# --- Max include depth ---

{
    my ($fh1, $f1) = tempfile(DIR => $tmpdir, SUFFIX => '.nx', UNLINK => 0);
    my ($fh2, $f2) = tempfile(DIR => $tmpdir, SUFFIX => '.nx', UNLINK => 0);
    print $fh1 "%Include(\"$f2\")";
    close $fh1;
    print $fh2 "%Include(\"$f1\")";
    close $fh2;

    my $t = Data::NExT::Template->new(opts => { max_depth => 2 });
    eval { $t->preprocess("%Include(\"$f1\")") };
    like($@, qr/max include depth/, 'max depth exceeded dies');
    unlink $f1, $f2;
}

# --- Host function ---

{
    my $t = Data::NExT::Template->new(
        functions => { 'echo' => sub { "RETURNED" } },
    );
    my $out = $t->preprocess('val( %echo )');
    is($out, 'val( RETURNED )', 'host function called');
}

# --- Host function with arg ---

{
    my $t = Data::NExT::Template->new(
        functions => { 'repeat' => sub { $_[0] x 3 } },
    );
    my $out = $t->preprocess('%repeat("ab")');
    is($out, 'ababab', 'host function with argument');
}

# --- Undefined function ---

{
    my $t = Data::NExT::Template->new;
    eval { $t->preprocess('%nope') };
    like($@, qr/undefined function 'nope'/, 'undefined function dies');
}

# --- Function error ---

{
    my $t = Data::NExT::Template->new(
        functions => { 'bad' => sub { die "boom" } },
    );
    eval { $t->preprocess('%bad') };
    like($@, qr/function 'bad' failed: boom/, 'function error propagated');
}

# --- Function returning NExT ---

{
    my $t = Data::NExT::Template->new(
        functions => {
            'gen' => sub {
                return "Column[\n    name(\"id\")\n    type(\"int\")\n]";
            },
        },
    );
    my $out = $t->preprocess("Database[\n    name(\"app\")\n    %gen\n]");
    like($out, qr/Column\[/, 'function returning NExT: noun present');
    like($out, qr/name\("id"\)/, 'function returning NExT: adj present');
}

# --- %Env builtin ---

{
    local $ENV{NXT_TEST_ENV} = 'env-val';
    my $t = Data::NExT::Template->new(config => { NXT_TEST_ENV => 'config-val' });
    my $out = $t->preprocess('%Env("NXT_TEST_ENV")');
    is($out, 'env-val', '%Env bypasses config, reads ENV');
}

# --- %Var builtin ---

{
    local $ENV{NXT_TEST_VAR} = 'env-val';
    my $t = Data::NExT::Template->new(config => { NXT_TEST_VAR => 'config-val' });
    my $out = $t->preprocess('%Var("NXT_TEST_VAR")');
    is($out, 'config-val', '%Var bypasses ENV, reads config');
}

# --- Multiple variables ---

{
    my $t = Data::NExT::Template->new(
        config => { A => '1', B => '2', C => '3' },
    );
    my $out = $t->preprocess('${A} ${B} ${C}');
    is($out, '1 2 3', 'multiple variables expanded');
}

# --- Variable in string context ---

{
    my $t = Data::NExT::Template->new(cli_vars => { NAME => 'test' });
    my $out = $t->preprocess('label("hello ${NAME} world")');
    is($out, 'label("hello test world")', 'variable inside string');
}

# --- Full template example ---

{
    my $t = Data::NExT::Template->new(
        config    => { db => { host => 'localhost' } },
        functions => { 'hostname' => sub { 'myhost' } },
        cli_vars  => { PORT => '5432' },
    );
    my $template = <<'TMPL';
Pipeline[
    name("my-pipeline")
    host( %hostname )
    port(${PORT})
    db("${db/host}")
    %Ifdef("DEBUG")
    log_level("verbose")
    %Endif
]
TMPL
    my $out = $t->preprocess($template);
    like($out, qr/host\( myhost \)/, 'full example: function');
    like($out, qr/port\(5432\)/, 'full example: CLI var');
    like($out, qr/db\("localhost"\)/, 'full example: path var');
    unlike($out, qr/log_level/, 'full example: ifdef excluded');
}

# --- Full template with DEBUG ---

{
    my $t = Data::NExT::Template->new(
        config   => { db => { host => 'localhost' }, DEBUG => '1' },
        cli_vars => { PORT => '5432' },
    );
    my $template = <<'TMPL';
Pipeline[
    name("my-pipeline")
    port(${PORT})
    db("${db/host}")
    %Ifdef("DEBUG")
    log_level("verbose")
    %Endif
]
TMPL
    my $out = $t->preprocess($template);
    like($out, qr/log_level\("verbose"\)/, 'full example: ifdef included when set');
}

done_testing();
