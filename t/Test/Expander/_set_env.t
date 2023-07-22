## no critic (RequireLocalizedPunctuationVars)

use strict;
use warnings
  FATAL    => qw( all ),
  NONFATAL => qw( deprecated exec internal malloc newline once portable redefine recursion uninitialized );

use File::chdir;

use Test::Expander -tempdir => {}, -srand => time;
use Test::Expander::Constants qw( $FMT_INVALID_ENV_ENTRY );

$METHOD     //= '_set_env';
$METHOD_REF //= $CLASS->can( $METHOD );
can_ok( $CLASS, $METHOD );

ok( -d $TEMP_DIR, "temporary directory '$TEMP_DIR' created" );

my $classPath = $CLASS =~ s{::}{/}gr;
my $testPath  = path( $TEMP_DIR )->child( 't' );
$testPath->child( $classPath )->mkpath;

{
  local $CWD   = $testPath->parent->stringify;              ## no critic (ProhibitLocalVars)

  my $testFile = path( 't' )->child( $classPath )->child( $METHOD . '.t' )->stringify;
  my $envFile  = path( 't' )->child( $classPath )->child( $METHOD . '.env' );

  is( Test2::Plugin::SRand->from, 'import arg', "random seed is supplied as 'time'" );

  subtest '1st env variable filled from a variable, 2nd one kept from %ENV, 3rd one ignored' => sub {
    our $var  = 'abc';
    my $name  = 'ABC';
    my $value = '$' . __PACKAGE__ . '::var';
    $envFile->spew( "$name = $value\nJust a comment line\nX\nY" );
    %ENV = ( XXX => 'yyy', X => 'A' );

    ok( lives { $METHOD_REF->( $CLASS, $testFile ) }, 'successfully executed' );
    my $expected = { $name => lc( $name ), X => 'A' };
    $expected->{ PWD } = $ENV{ PWD } if exists( $ENV{ PWD } );
    is( \%ENV, $expected,                             "'%ENV' has the expected content" );
  };

  subtest 'env variable filled by a self-implemented sub' => sub {
    my $name  = 'ABC';
    my $value = __PACKAGE__ . "::testEnv( lc( '$name' ) )";
    $envFile->spew( "$name = $value" );
    %ENV = ( XXX => 'yyy' );

    ok( lives { $METHOD_REF->( $CLASS, $testFile ) }, 'successfully executed' );
    my $expected = { $name => lc( $name ) };
    $expected->{ PWD } = $ENV{ PWD } if exists( $ENV{ PWD } );
    is( \%ENV, $expected,                             "'%ENV' has the expected content" );
  };

  subtest "env variable filled by a 'File::Temp::tempdir'" => sub {
    my $name  = 'ABC';
    my $value = 'File::Temp::tempdir';
    $envFile->spew( "$name = $value" );
    %ENV = ( XXX => 'yyy' );

    ok( lives { $METHOD_REF->( $CLASS, $testFile ) },      'successfully executed' );
    my %expected = ( $name => $value );
    $expected{ PWD } = $ENV{ PWD } if exists( $ENV{ PWD } );
    is( [ sort keys( %ENV ) ], [ sort keys( %expected ) ], "'%ENV' has the expected keys" );
    ok( -d $ENV{ $name },                                  'temporary directory exists' );
  };

  subtest 'env file does not exist' => sub {
    $envFile->remove;
    %ENV = ( XXX => 'yyy' );

    ok( lives { $METHOD_REF->( $CLASS, $testFile ) }, 'successfully executed' );
    my $expected = { XXX => 'yyy' };
    $expected->{ PWD } = $ENV{ PWD } if exists( $ENV{ PWD } );
    is( \%ENV, $expected,                             "'%ENV' remained unchanged" );
  };

  subtest 'directory structure does not correspond to class hierarchy' => sub {
    $envFile->remove;
    %ENV = ( XXX => 'yyy' );

    ok( lives { $METHOD_REF->( 'ABC::' . $CLASS, $testFile ) }, 'successfully executed' );
    my $expected = { XXX => 'yyy' };
    $expected->{ PWD } = $ENV{ PWD } if exists( $ENV{ PWD } );
    is( \%ENV, $expected,                                       "'%ENV' remained unchanged" );
  };

  subtest 'multiple levels of env files, cascade usage of their entries, overwrite entry' => sub {
    path( $envFile->parent->parent . '.env' )->spew( "C = '0'" );
    path( $envFile->parent         . '.env' )->spew( "A = '1'\nB = '2'\nD = \$ENV{ A } . \$ENV{ C }" );
    $envFile->spew( "C = '3'" );
    %ENV = ( XXX => 'yyy' );

    local $CWD = $TEMP_DIR;                                 ## no critic (ProhibitLocalVars)
    ok( lives { $METHOD_REF->( $CLASS, $testFile ) }, 'successfully executed' );
    my $expected = { A => '1', B => '2', C => '3', D => '10' };
    $expected->{ PWD } = $ENV{ PWD } if exists( $ENV{ PWD } );
    is( \%ENV, $expected,                             "'%ENV' has the expected content" );

    path( $envFile->parent->parent . '.env' )->remove;
    path( $envFile->parent         . '.env' )->remove;
  };

  subtest 'env file with invalid syntax' => sub {
    my $name  = 'ABC';
    my $value = 'abc->';
    $envFile->spew( "$name = $value" );

    my $expected = $FMT_INVALID_ENV_ENTRY =~ s/%d/0/r =~ s/%s/$envFile/r =~ s/%s/$name = $value/r =~ s/%s/.+/r;
    like( dies { $METHOD_REF->( $CLASS, $testFile ) }, qr/$expected/, 'expected exception raised' );
  };

  subtest 'env file with undefined values' => sub {
    my $name  = 'ABC';
    my $value = '$undefined';
    $envFile->spew( "$name = $value" );

    my $expected = $FMT_INVALID_ENV_ENTRY =~ s/%d/0/r =~ s/%s/$envFile/r =~ s/%s/$name = $value/r =~ s/%s/.+/r =~ s/(\$)/\\$1/r;
    like( dies { $METHOD_REF->( $CLASS, $testFile ) }, qr/$expected/m, 'expected exception raised' );
  };
}

done_testing();

sub testEnv { return $_[ 0 ] }                               ## no critic (RequireArgUnpacking)
