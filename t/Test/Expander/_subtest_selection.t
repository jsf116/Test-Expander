use strict;
use warnings
  FATAL    => qw( all ),
  NONFATAL => qw( deprecated exec internal malloc newline once portable redefine recursion uninitialized );

use Test2::V0 -target => 'Test::Expander';

use Test::Expander::Constants qw( $FMT_INVALID_SUBTEST_NUMBER );

plan( 4 );

{
  local @ARGV = ( '--exclude_name' => 'valid RegEx' );
  is( Test::Expander::_subtest_selection(), undef, 'exclude subtest by valid RegEx' );
}

{
  local @ARGV = ( '--exclude_name' => '[invalid RegEx' );
  is( Test::Expander::_subtest_selection(), undef, 'exclude subtest by invalid RegEx' );
}

{
  local @ARGV = ( '--exclude_number' => '1/0/2' );
  is( Test::Expander::_subtest_selection(), undef, 'exclude subtest by valid number' );
}

Test2::Tools::Subtest::subtest_streamed 'enforced usage of subtest_streamed for better test coverage' => sub {
  plan( 1 );
  local @ARGV = ( '--exclude_number' => '1/0/' );
  my $expected = sprintf( $FMT_INVALID_SUBTEST_NUMBER, '1/0/' );
  like( dies { Test::Expander::_subtest_selection() }, qr/$expected/, 'exclude subtest by invalid number' );
};
