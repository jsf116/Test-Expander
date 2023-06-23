## no critic ( ProhibitStringyEval ProhibitSubroutinePrototypes RequireLocalizedPunctuationVars)
package Test::Expander;

# The versioning is conform with https://semver.org
our $VERSION = '2.0.0';                                     ## no critic (RequireUseStrict, RequireUseWarnings)

use strict;
use warnings
  FATAL      => qw( all ),
  NONFATAL   => qw( deprecated exec internal malloc newline portable recursion );
use feature     qw( switch );
no if ( $] >= 5.018 ),
    warnings => qw( experimental );

use Const::Fast;
use File::chdir;
use File::Temp       qw( tempdir tempfile );
use Importer;
use Path::Tiny       qw( cwd path );
use Scalar::Readonly qw( readonly_on );
use Test2::Tools::Basic;
use Test2::Tools::Explain;
use Test2::V0        qw();

use Test::Expander::Constants qw(
  $DIE $FALSE
  $FMT_INVALID_DIRECTORY $FMT_INVALID_ENV_ENTRY $FMT_INVALID_VALUE $FMT_KEEP_ENV_VAR $FMT_NEW_FAILED
  $FMT_NEW_SUCCEEDED $FMT_REPLACEMENT $FMT_REQUIRE_DESCRIPTION $FMT_REQUIRE_IMPLEMENTATION $FMT_SEARCH_PATTERN
  $FMT_SET_ENV_VAR $FMT_SET_TO $FMT_UNKNOWN_OPTION $FMT_USE_DESCRIPTION $FMT_USE_IMPLEMENTATION
  $MSG_ERROR_WAS $MSG_UNEXPECTED_EXCEPTION
  $NOTE
  $REGEX_ANY_EXTENSION $REGEX_CLASS_HIERARCHY_LEVEL $REGEX_TOP_DIR_IN_PATH $REGEX_VERSION_NUMBER
  $TRUE
  %CONSTANTS_TO_EXPORT
);

readonly_on( $VERSION );

our ( $CLASS, $METHOD, $METHOD_REF, $TEMP_DIR, $TEMP_FILE );
our @EXPORT = (
  @{ Const::Fast::EXPORT },
  @{ Test2::Tools::Explain::EXPORT },
  @{ Test2::V0::EXPORT },
  qw( tempdir tempfile ),
  qw( cwd path ),
  qw( BAIL_OUT dies_ok is_deeply lives_ok new_ok require_ok throws_ok use_ok ),
);

*BAIL_OUT = \&bail_out;                                     # Explicit "sub BAIL_OUT" would be untestable

sub dies_ok ( &;$ ) {
  my ( $coderef, $description ) = @_;

  eval { $coderef->() };

  return ok( $@, $description );
}

sub import {
  my ( $class, @exports ) = @_;

  my $frameIndex = 0;
  my $testFile;
  while( my @currentFrame = caller( $frameIndex++ ) ) {
    $testFile = path( $currentFrame[ 1 ] ) =~ s{^/}{}r;
  }
  my $options = _parse_options( \@exports, $testFile );

  _set_env( $options->{ -target }, $testFile );

  _export_symbols( $options );
  Test2::V0->import( %$options );

  Importer->import_into( $class, scalar( caller ), () );

  return;
}

sub is_deeply ( $$;$@ ) {
  my ( $got, $expected, $title ) = @_;

  return is( $got, $expected, $title );
}

sub lives_ok ( &;$ ) {
  my ( $coderef, $description ) = @_;

  eval { $coderef->() };
  diag( $MSG_UNEXPECTED_EXCEPTION . $@ ) if $@;

  return ok( !$@, $description );
}

sub new_ok {
  my ( $class, $args ) = @_;

  $args ||= [];
  my $obj = eval { $class->new( @$args ) };
  ok( !$@, _new_test_message( $class ) );

  return $obj;
}

sub require_ok {
  my ( $module ) = @_;

  my $package       = caller;
  my $requireResult = eval( sprintf( $FMT_REQUIRE_IMPLEMENTATION, $package, $module ) );
  ok( $requireResult, sprintf( $FMT_REQUIRE_DESCRIPTION, $module, _error() ) );

  return $requireResult;
}

sub throws_ok ( &$;$ ) {
  my ( $coderef, $expecting, $description ) = @_;

  eval { $coderef->() };
  my $exception    = $@;
  my $expectedType = ref( $expecting );

  return $expectedType eq 'Regexp' ? like  ( $exception,   $expecting,   $description )
                                   : isa_ok( $exception, [ $expecting ], $description );
}

sub use_ok ( $;@ ) {
  my ( $module, @imports ) = @_;

  my ( $package, $filename, $line ) = caller( 0 );
  $filename =~ y/\n\r/_/;                                   # taken over from Test::More

  my $requireResult = eval( sprintf( $FMT_USE_IMPLEMENTATION, $package, $module, _use_imports( \@imports ) ) );
  ok(
    $requireResult,
    sprintf(
      $FMT_USE_DESCRIPTION, $module, _error( $FMT_SEARCH_PATTERN, sprintf( $FMT_REPLACEMENT, $filename, $line ) )
    )
  );

  return $requireResult;
}

sub _determine_testee {
  my ( $options, $testFile ) = @_;

  if ( $options->{ -lib } ) {
    foreach my $directory ( @{ $options->{ -lib } } ) {
      $DIE->( $FMT_INVALID_DIRECTORY, $directory, 'invalid type' ) if ref( $directory );
      my $incEntry = eval( $directory );
      $DIE->( $FMT_INVALID_DIRECTORY, $directory, $@ ) if $@;
      unshift( @INC, $incEntry );
    }
    delete( $options->{ -lib } );
  }

  if ( exists( $options->{ -method } ) ) {
    delete( $options->{ -method } );
  }
  else {
    $METHOD = path( $testFile )->basename( $REGEX_ANY_EXTENSION );
  }

  unless ( exists( $options->{ -target } ) ) {              # Try to determine class / module autmatically
    my ( $testRoot ) = $testFile =~ $REGEX_TOP_DIR_IN_PATH;
    my $testee       = path( $testFile )->relative( $testRoot )->parent;
    $options->{ -target } = $testee =~ s{/}{::}gr if grep { path( $_ )->child( $testee . '.pm' )->is_file } @INC;
  }
  $CLASS = $options->{ -target } if exists( $options->{ -target } );

  return $options;
}

sub _error {
  my ( $searchString, $replacementString ) = @_;

  return '' if $@ eq '';

  my $error = $MSG_ERROR_WAS . $@ =~ s/\n$//mr;
  $error =~ s/$searchString/$replacementString/m if defined( $searchString );
  return $error;
}

sub _export_symbols {
  my ( $options ) = @_;

  foreach my $var ( sort keys( %CONSTANTS_TO_EXPORT ) ) {   # Export defined constants
    no strict qw( refs );                                   ## no critic (ProhibitProlongedStrictureOverride)
    my $value = eval( "${ \$var }" ) or next;
    readonly_on( ${ __PACKAGE__ . '::' . $var =~ s/^.//r } );
    push( @EXPORT, $var );
    $NOTE->( $FMT_SET_TO, $var, $CONSTANTS_TO_EXPORT{ $var }->( $value, $CLASS ) );

    if ( $var eq '$CLASS' ) {                               # Export method constants only if class is known
      $METHOD_REF = $CLASS->can( $METHOD );
      $METHOD     = undef unless( $METHOD_REF );
    }
  }

  return;
}

sub _new_test_message {
  my ( $class ) = @_;

  return $@ ? sprintf( $FMT_NEW_FAILED, $class, _error() ) : sprintf( $FMT_NEW_SUCCEEDED, $class, $class );
}

sub _parse_options {
  my ( $exports, $testFile ) = @_;

  my $options = {};
  while ( my $optionName = shift( @$exports ) ) {
    given ( $optionName ) {
      when ( '-lib' ) {
        my $optionValue = shift( @$exports );
        $DIE->( $FMT_INVALID_VALUE, $optionName, $optionValue ) if ref( $optionValue ) ne 'ARRAY';
        $options->{ -lib } = $optionValue;
      }
      when ( '-method' ) {
        my $optionValue = shift( @$exports );
        $DIE-> ( $FMT_INVALID_VALUE, $optionName, $optionValue ) if ref( $optionValue );
        $METHOD = $options->{ -method } = $optionValue;
      }
      when ( '-target' ) {
        my $optionValue = shift( @$exports );               # Do not load module only if its name is undef
        $options->{ -target } = $optionValue if defined( $optionValue );
      }
      when ( '-tempdir' ) {
        my $optionValue = shift( @$exports );
        $DIE->( $FMT_INVALID_VALUE, $optionName, $optionValue ) if ref( $optionValue ) ne 'HASH';
        $TEMP_DIR = tempdir( CLEANUP => 1, %$optionValue );
      }
      when ( '-tempfile' ) {
        my $optionValue = shift( @$exports );
        $DIE->( $FMT_INVALID_VALUE, $optionName, $optionValue ) if ref( $optionValue ) ne 'HASH';
        my $fileHandle;
        ( $fileHandle, $TEMP_FILE ) = tempfile( UNLINK => 1, %$optionValue );
      }
      when ( /^-\w/ ) {
        $options->{ $optionName } = shift( @$exports );
      }
      default {
        $DIE->( $FMT_UNKNOWN_OPTION, $optionName, shift( @$exports ) // '' );
      }
    }
  }

  return _determine_testee( $options, $testFile );
}

sub _read_env_file {
  my ( $envFile ) = @_;

  my @lines = path( $envFile )->lines( { chomp => 1 } );
  my %env;
  while ( my ( $index, $line ) = each( @lines ) ) {
                                                            ## no critic (ProhibitUnusedCapture)
    next unless $line =~ /^ (?<name> \w+) \s* (?: = \s* (?<value> \S .*) | $ )/x;
    if ( exists( $+{ value } ) ) {
      $env{ $+{ name } } = eval( $+{ value } );
      $DIE->( $FMT_INVALID_ENV_ENTRY, $index, $envFile, $line, $@ ) if $@;
      $NOTE->( $FMT_SET_ENV_VAR, $+{ name }, $env{ $+{ name } }, $envFile );
    }
    elsif ( exists( $ENV{ $+{ name } } ) ) {
      $env{ $+{ name } } = $ENV{ $+{ name } };
      $NOTE->( $FMT_KEEP_ENV_VAR, $+{ name }, $ENV{ $+{ name } } );
    }
  }

  return \%env;
}

sub _set_env {
  my ( $class, $testFile ) = @_;

  my $envFound = $FALSE;
  my $newEnv   = {};
  {
    local $CWD = $testFile =~ s{/.*}{}r;                    ## no critic (ProhibitLocalVars)
    ( $envFound, $newEnv ) = _set_env_hierarchically( $class, $envFound, $newEnv );
  }

  my $envFile = $testFile =~ s/$REGEX_ANY_EXTENSION/.env/r;

  if ( path( $envFile )->is_file ) {
    $envFound                       = $TRUE unless $envFound;
    my $methodEnv                   = _read_env_file( $envFile );
    @$newEnv{ keys( %$methodEnv ) } = values( %$methodEnv );
  }

  %ENV = %$newEnv if $envFound;

  return;
}

sub _set_env_hierarchically {
  my ( $class, $envFound, $newEnv ) = @_;

  return ( $envFound, $newEnv ) unless $class;

  my $classTopLevel;
  ( $classTopLevel, $class ) = $class =~ $REGEX_CLASS_HIERARCHY_LEVEL;

  return ( $FALSE, {} ) unless path( $classTopLevel )->is_dir;

  my $envFile = $classTopLevel . '.env';
  if ( path( $envFile )->is_file ) {
    $envFound = $TRUE unless $envFound;
    $newEnv   = { %$newEnv, %{ _read_env_file( $envFile ) } };
  }

  local $CWD = $classTopLevel;                              ## no critic (ProhibitLocalVars)
  return _set_env_hierarchically( $class, $envFound, $newEnv );
}

sub _use_imports {
  my ( $imports ) = @_;

  return @$imports == 1 && $imports->[ 0 ] =~ $REGEX_VERSION_NUMBER ? ' ' . $imports->[ 0 ] : '';
}

1;
