use strict;
use warnings
  FATAL    => qw( all ),
  NONFATAL => qw( deprecated exec internal malloc newline once portable redefine recursion uninitialized );

use Test::Expander;

my $subtestSkipped;
my $mockTest2API = mock 'Test2::API::Context' => (
  override => [ skip => sub { ok( $subtestSkipped, 'subtest skipped' ) } ]
);

plan( 3 );

subtest 'no subtest excluded' => sub {
  plan( 2 );
  $subtestSkipped = 0;
  lives_ok { $METHOD_REF->( sub { ok( !$subtestSkipped, 'original subtest executed' ) }, 'NAME' ) } 'no changes';
};

subtest 'exclude subtest by number' => sub {
  plan( 2 );
  local @ARGV = ( '--exclude_number' => '1/0' );
  Test::Expander::_subtest_selection();
  $subtestSkipped = 1;
  lives_ok { $METHOD_REF->( sub { ok( !$subtestSkipped, 'original subtest executed' ) }, 'NAME' ) } 'executed';
};

subtest 'exclude subtest by name' => sub {
  plan( 2 );
  local @ARGV = ( '--exclude_name' => '[A-Z]' );
  Test::Expander::_subtest_selection();
  $subtestSkipped = 1;
  lives_ok { $METHOD_REF->( sub { ok( !$subtestSkipped, 'original subtest executed' ) }, 'NAME' ) } 'executed';
};
