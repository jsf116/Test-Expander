## no critic ( ProhibitStringyEval ProhibitSubroutinePrototypes RequireLocalizedPunctuationVars)
package Test::Expander;

# The versioning is conform with https://semver.org
our $VERSION = '2.0.0';                                     ## no critic (RequireUseStrict, RequireUseWarnings)

use strict;
use warnings
  FATAL      => qw( all ),
  NONFATAL   => qw( deprecated exec internal malloc newline portable recursion );
use feature      qw( switch );
no if ( $] >= 5.018 ),
    warnings => qw( experimental );

use Const::Fast;
use File::chdir;
use File::Temp        qw( tempdir tempfile );
use Importer;
use Module::Functions qw( get_public_functions );
use Path::Tiny        qw( cwd path );
use Scalar::Readonly  qw( readonly_on );
use Test2::Tools::Basic;
use Test2::Tools::Explain;
use Test2::V0         qw();

use Test::Expander::Constants qw(
  $ANY_EXTENSION
  $CLASS_HIERARCHY_LEVEL
  $ERROR_WAS $EXCEPTION_PREFIX
  $FALSE
  $INVALID_ENV_ENTRY $INVALID_VALUE
  $KEEP_ENV_VAR
  $NEW_FAILED $NEW_SUCCEEDED $NOTE
  $REPLACEMENT $REQUIRE_DESCRIPTION $REQUIRE_IMPLEMENTATION
  $SEARCH_PATTERN $SET_ENV_VAR $SET_TO
  $TOP_DIR_IN_PATH $TRUE
  $UNEXPECTED_EXCEPTION $UNKNOWN_OPTION $USE_DESCRIPTION $USE_IMPLEMENTATION
  $VERSION_NUMBER
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

  my $testFile = path( ( caller( 2 ) )[ 1 ] ) =~ s{^/}{}r;  ## no critic (ProhibitMagicNumbers)
  my $options  = _parseOptions( \@exports, $testFile );

  _setEnv( $options->{ -target }, $testFile );

  _exportSymbols( $options );
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
  diag( $UNEXPECTED_EXCEPTION->( $@ ) ) if $@;
  # { no warnings; printf( $UNEXPECTED_EXCEPTION[ !!$@ ], $@ ); } ## no critic (ProhibitNoWarnings)

  return ok( !$@, $description );
}

sub new_ok {
  my ( $class, $args ) = @_;

  $args ||= [];
  my $obj = eval { $class->new( @$args ) };
  ok( !$@, _newTestMessage( $class ) );

  return $obj;
}

sub require_ok {
  my ( $module ) = @_;

  my $package       = caller;
  my $requireResult = eval( sprintf( $REQUIRE_IMPLEMENTATION, $package, $module ) );
  ok( $requireResult, sprintf( $REQUIRE_DESCRIPTION, $module, _error() ) );

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

  my $requireResult = eval( sprintf( $USE_IMPLEMENTATION, $package, $module, _useImports( \@imports ) ) );
  ok(
    $requireResult,
    sprintf( $USE_DESCRIPTION, $module, _error( $SEARCH_PATTERN, sprintf( $REPLACEMENT, $filename, $line ) ) )
  );

  return $requireResult;
}

sub _error {
  my ( $searchString, $replacementString ) = @_;

  return '' if $@ eq '';

  my $error = $ERROR_WAS . $@ =~ s/\n$//mr;
  $error =~ s/$searchString/$replacementString/m if defined( $searchString );
  return $error;
}

sub _exportSymbols {
  my ( $options ) = @_;

  foreach my $var ( sort keys( %CONSTANTS_TO_EXPORT ) ) {   # Export defined constants
    no strict qw( refs );
    my $value = eval( "${ \$var }" ) or next;
    readonly_on( ${ __PACKAGE__ . '::' . $var =~ s/^.//r } );
    push( @EXPORT, $var );
    $NOTE->( $SET_TO, $var, $CONSTANTS_TO_EXPORT{ $var }->( $value, $CLASS ) );

    if ( $var eq '$CLASS' ) {                               # Export method constants only if class is known
      $METHOD_REF = $CLASS->can( $METHOD );
      $METHOD     = undef unless( $METHOD_REF );
    }
  }

  return;
}

sub _newTestMessage {
  my ( $class ) = @_;

  return $@ ? sprintf( $NEW_FAILED, $class, _error() ) : sprintf( $NEW_SUCCEEDED, $class, $class );
}

sub _parseOptions {
  my ( $exports, $testFile ) = @_;

  my $options = {};
  while ( my $optionName = shift( @$exports ) ) {
    given ( $optionName ) {
      when ( '-method' ) {
        my $optionValue = shift( @$exports );
        die( sprintf( $INVALID_VALUE, $optionName, $optionValue ) ) if ref( $optionValue );
        $METHOD = $options->{ -method } = $optionValue;
      }
      when ( '-target' ) {
        my $optionValue = shift( @$exports );               # Do not load module only if its name is undef
        $options->{ -target } = $optionValue if defined( $optionValue );
      }
      when ( '-tempdir' ) {
        my $optionValue = shift( @$exports );
        die( sprintf( $INVALID_VALUE, $optionName, $optionValue ) ) if ref( $optionValue ) ne 'HASH';
        $TEMP_DIR = tempdir( CLEANUP => 1, %$optionValue );
      }
      when ( '-tempfile' ) {
        my $optionValue = shift( @$exports );
        die( sprintf( $INVALID_VALUE, $optionName, $optionValue ) ) if ref( $optionValue ) ne 'HASH';
        my $fileHandle;
        ( $fileHandle, $TEMP_FILE ) = tempfile( UNLINK => 1, %$optionValue );
      }
      when ( /^-\w/ ) {
        $options->{ $optionName } = shift( @$exports );
      }
      default {
        die( sprintf( $UNKNOWN_OPTION, $optionName, shift( @$exports ) // '' ) );
      }
    }
  }

  unless ( exists( $options->{ -target } ) ) {
    my ( $testRoot ) = $testFile =~ $TOP_DIR_IN_PATH;
    my $testee       = path( $testFile )->relative( $testRoot )->parent;
    $options->{ -target } = $testee =~ s{/}{::}gr if grep { path( $_ )->child( $testee . '.pm' )->is_file } @INC;
  }
  elsif  ( !defined( $options->{ -target } ) ) {
    delete( $options->{ -target } );                        # Do not load any module if '-target => undef'
  }
  $CLASS = $options->{ -target } if exists( $options->{ -target } );

  if ( exists( $options->{ -method } ) ) {
    delete( $options->{ -method } );
  }
  else {
    $METHOD = path( $testFile )->basename( $ANY_EXTENSION );
  }

  return $options;
}

sub _readEnvFile {
  my ( $envFile ) = @_;

  my @lines = path( $envFile )->lines( { chomp => 1 } );
  my %env;
  while ( my ( $index, $line ) = each( @lines ) ) {
                                                            ## no critic (ProhibitUnusedCapture)
    next unless $line =~ /^ (?<name> \w+) \s* (?: = \s* (?<value> \S .*) | $ )/x;
    if ( exists( $+{ value } ) ) {
      $env{ $+{ name } } = eval( $+{ value } );
      die( sprintf( $INVALID_ENV_ENTRY, $index, $envFile, $line, $@ ) ) if $@;
      $NOTE->( $SET_ENV_VAR, $+{ name }, $env{ $+{ name } }, $envFile );
    }
    elsif ( exists( $ENV{ $+{ name } } ) ) {
      $env{ $+{ name } } = $ENV{ $+{ name } };
      $NOTE->( $KEEP_ENV_VAR, $+{ name }, $ENV{ $+{ name } } );
    }
  }

  return \%env;
}

sub _setEnv {
  my ( $class, $testFile ) = @_;

  my $envFound = $FALSE;
  my $newEnv   = {};
  {
    local $CWD = $testFile =~ s{/.*}{}r;                    ## no critic (ProhibitLocalVars)
    ( $envFound, $newEnv ) = _setEnvHierarchically( $class, $envFound, $newEnv );
  }

  my $envFile = $testFile =~ s/$ANY_EXTENSION/.env/r;

  if ( path( $envFile )->is_file ) {
    $envFound                       = $TRUE unless $envFound;
    my $methodEnv                   = _readEnvFile( $envFile );
    @$newEnv{ keys( %$methodEnv ) } = values( %$methodEnv );
  }

  %ENV = %$newEnv if $envFound;

  return;
}

sub _setEnvHierarchically {
  my ( $class, $envFound, $newEnv ) = @_;

  return ( $envFound, $newEnv ) unless $class;

  my $classTopLevel;
  ( $classTopLevel, $class ) = $class =~ $CLASS_HIERARCHY_LEVEL;

  return ( $FALSE, {} ) unless path( $classTopLevel )->is_dir;

  my $envFile = $classTopLevel . '.env';
  if ( path( $envFile )->is_file ) {
    $envFound = $TRUE unless $envFound;
    $newEnv   = { %$newEnv, %{ _readEnvFile( $envFile ) } };
  }

  local $CWD = $classTopLevel;                              ## no critic (ProhibitLocalVars)
  return _setEnvHierarchically( $class, $envFound, $newEnv );
}

sub _useImports {
  my ( $imports ) = @_;

  return @$imports == 1 && $imports->[ 0 ] =~ $VERSION_NUMBER ? ' ' . $imports->[ 0 ] : '';
}

1;
