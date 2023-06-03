use strict;
use warnings
  FATAL    => qw( all ),
  NONFATAL => qw( deprecated exec internal malloc newline once portable redefine recursion uninitialized );

use Test::Expander -target => 'Test::Expander';

is( $METHOD, undef, 'there is no method corresponding to this test file' );

done_testing();
