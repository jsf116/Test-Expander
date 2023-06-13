use strict;
use warnings
  FATAL    => qw( all ),
  NONFATAL => qw( deprecated exec internal malloc newline once portable redefine recursion uninitialized );

my ( @functions, @variables );
BEGIN {
  use Const::Fast;
  use File::Temp qw( tempdir tempfile );
  use Path::Tiny qw( cwd path );
  use Test2::Tools::Explain;
  use Test2::V0;
  @functions = (
    @{ Const::Fast::EXPORT },
    @{ Test2::Tools::Explain::EXPORT },
    @{ Test2::V0::EXPORT },
    qw( tempdir tempfile ),
    qw( cwd path ),
    qw( BAIL_OUT dies_ok is_deeply lives_ok new_ok require_ok use_ok ),
  );
  @variables = qw( $CLASS $METHOD $METHOD_REF $TEMP_DIR $TEMP_FILE );
}

use Scalar::Readonly          qw( readonly_off );
use Test::Builder::Tester     tests => @functions + @variables + 7;

use Test::Expander            -target   => 'Test::Expander',
                              -tempdir  => { CLEANUP => 1 },
                              -tempfile => { UNLINK  => 1 };
use Test::Expander::Constants qw( $INVALID_VALUE $SET_TO $UNKNOWN_OPTION );

foreach my $function ( sort @functions ) {
  my $title = "$CLASS->can('$function')";
  test_out( "ok 1 - $title" );
  can_ok( $CLASS, $function );
  test_test( $title );
}

foreach my $variable ( sort @variables ) {
  my $title = "$CLASS exports '$variable'";
  test_out( "ok 1 - $title" );
  ok( eval( "defined( $variable )" ), $title );             ## no critic (ProhibitStringyEval)
  test_test( $title );
}

my ( $title, $expected );

$title    = "invalid value of '-method'";
$expected = $INVALID_VALUE =~ s/%s/.+/gr;
readonly_off( $CLASS );
readonly_off( $METHOD );
readonly_off( $METHOD_REF );
readonly_off( $TEMP_DIR );
readonly_off( $TEMP_FILE );
test_out( "ok 1 - $title" );
like( dies { $CLASS->$METHOD( -method => {} ) }, qr/$expected/, $title );
test_test( $title );

$title    = "invalid value of '-tempdir'";
$expected = $INVALID_VALUE =~ s/%s/.+/gr;
readonly_off( $CLASS );
readonly_off( $METHOD );
readonly_off( $METHOD_REF );
readonly_off( $TEMP_DIR );
readonly_off( $TEMP_FILE );
test_out( "ok 1 - $title" );
like( dies { $CLASS->$METHOD( -tempdir => 1 ) }, qr/$expected/, $title );
test_test( $title );

$title    = "invalid value of '-tempfile'";
$expected = $INVALID_VALUE =~ s/%s/.+/gr;
readonly_off( $CLASS );
readonly_off( $METHOD );
readonly_off( $METHOD_REF );
readonly_off( $TEMP_DIR );
readonly_off( $TEMP_FILE );
test_out( "ok 1 - $title" );
like( dies { $CLASS->$METHOD( -tempfile => 1 ) }, qr/$expected/, $title );
test_test( $title );

$title    = 'unknown option with some value';
$expected = $UNKNOWN_OPTION =~ s/%s/.+/gr;
readonly_off( $CLASS );
readonly_off( $METHOD );
readonly_off( $METHOD_REF );
readonly_off( $TEMP_DIR );
readonly_off( $TEMP_FILE );
test_out( "ok 1 - $title" );
like( dies { $CLASS->$METHOD( unknown => 1 ) }, qr/$expected/, $title );
test_test( $title );

$title    = 'unknown option without value';
$expected = $UNKNOWN_OPTION =~ s/%s/.+/r =~ s/%s//r;
readonly_off( $CLASS );
readonly_off( $METHOD );
readonly_off( $METHOD_REF );
readonly_off( $TEMP_DIR );
readonly_off( $TEMP_FILE );
test_out( "ok 1 - $title" );
like( dies { $CLASS->$METHOD( 'unknown' ) }, qr/$expected/, $title );
test_test( $title );

$title    = "valid '-method', '-target' => undef (return value)";
$expected = undef;
readonly_off( $CLASS );
readonly_off( $METHOD );
readonly_off( $METHOD_REF );
readonly_off( $TEMP_DIR );
readonly_off( $TEMP_FILE );
test_out(
  join(
    "\n",
    sprintf( "# $SET_TO", '$CLASS',     $CLASS ),
    sprintf( "# $SET_TO", '$TEMP_DIR',  $TEMP_DIR ),
    sprintf( "# $SET_TO", '$TEMP_FILE', $TEMP_FILE ),
    "ok 1 - $title",
  )
);
my $mockImporter = mock 'Importer'  => ( override => [ import_into => sub {} ] );
my $mockTest2    = mock 'Test2::V0' => ( override => [ import      => sub {} ] );
is( dies { $CLASS->$METHOD( -method => 'dummy', -target => undef ) }, $expected, $title );
test_test( $title );

$title    = "valid '-method' (assigned method name)";
$expected = undef;
test_out( "ok 1 - $title" );
is( $METHOD, $expected, $title );
test_test( $title );
