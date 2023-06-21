# NAME

**Test::Expander** - Expansion of test functionalities that appear to be frequently used while testing.

# SYNOPSIS

```perl
# Tries to automatically determine, which class / module and method / subroutine are to be tested,
# does not create a temporary directory:
use Test::Expander;

# Tries to automatically determine, which class / module and method / subroutine are to be tested,
# does not create a temporary directory, passes the option '-srand' to Test::V0 changing
# the random seed to the current time in seconds:
use Test::Expander -srand => time;

# Class is supplied explicitly, tries to automatically determine method / subroutine to be tested,
# a temporary directory is created with a name corresponing to the template supplied:
use Test::Expander -target => 'My::Class', -tempdir => { TEMPLATE => 'my_dir.XXXXXXXX' };

# Does not try to determine, which class / module and method / subroutine are to be tested:
use Test::Expander -target => undef;

# Tries to automatically determine, which class / module is to be tested,
# does not determine method / subroutine to be tested:
use Test::Expander -method => undef;

# Adds directories 'dir0' and 'dir1' located in the temporary directory created during the execution
# at the beginning of directory list used by the Perl interpreter for search of modules to be loaded.
# In other words, "unshifts" these directories to the @INC array:
use Test::Expander
    -lib => [
    'path( $TEMP_DIR )->child( qw( dir0 ) )->stringify',
    'path( $TEMP_DIR )->child( qw( dir1 ) )->stringify',
    ],
    -tempdir => {};
```

# DESCRIPTION

**Test::Expander** combines all advanced possibilities provided by [Test2::V0](https://metacpan.org/pod/Test2::V0)
with some specific functions only available in the older module [Test::More](https://metacpan.org/pod/Test::More)
(which allows a smooth migration from [Test::More](https://metacpan.org/pod/Test::More)-based tests to
[Test2::V0](https://metacpan.org/pod/Test2::V0)-based ones) and handy functions from some other modules
often used in test suites.

Furthermore, this module allows to automatically recognize the class / module to be tested
(see variable **$CLASS** below) so that in contrast to [Test2::V0](https://metacpan.org/pod/Test2::V0)
you do not need to specify this explicitly if the path to the test file is in accordance with the name
of class / module to be tested i.e. file **t/Foo/Bar/baz.t** corresponds to class / module **Foo::Bar**.

If such automated recognition is not intended, this can be deactivated by explicitly supplied
undefined class / module name along with the option **-target**.

A similar recognition is provided in regard to the method / subroutine to be tested
(see variables **$METHOD** and **$METHOD\_REF** below) if the base name (without extension) of test file is
identical with the name of this method / subroutine i.e. file **t/Foo/Bar/baz.t**
corresponds to method / subroutine **Foo::Bar::bar**.

You can additionally to the default functionality bundled and provided by this module apply some features from other
convenient modules like [Test::Cmd](https://metacpan.org/pod/Test::Cmd),
[Test::Fatal](https://metacpan.org/pod/Test::Fatal), etc.
In this case functions with the same names as the ones defined in **Test::Expander** will NOT be re-exported.

Finally, a configurable setting of specific environment variables is provided so that
there is no need to hard-code this in the test itself.

The following options are accepted:

- Options specific for this module only are always expected to have values and their meaning is:
    - **-lib** - prepend directory list used by the Perl interpreter for search of modules to be loaded
    (i.e. the **@INC** array) with values supplied in form of array reference.
    Each element of this array is evaluated using [string eval](https://perldoc.perl.org/functions/eval) so that
    expression evaluated to strings are supported.

        Among other things this provides a possibility to temporary expand the module search path by directories located
        in the temporary directory if the latter is defined with the option **-tempdir** (see below).

        **-lib** is interpreted as the very last option, that's why the variabels defined by **Test::Expander** for export
        e.g. **$TEMP\_DIR** can be used in the expressions determining such directories (see **SYNOPSYS** above).

    - **-method** - prevent any attempt to automatically determine method / subroutine to be tested.
    If the value supplied along with this option is defined and found in the class / module to be test
    (see **-target** below), this will be considered such method / subroutine so that the variables
    **$METHOD** and **$METHOD\_REF** (see description of exported variables below) will be imported and accessible in test.
    If this value is **undef**, these variables are not imported.
    - **-target** - identical to the same-named option of [Test2::V0](https://metacpan.org/pod/Test2::V0) and, if contains
    a defined value, has the same purpose namely the explicit definition of the class / module to be tested as the value.
    However, if its value is **undef**, this is not passed through to [Test2::V0](https://metacpan.org/pod/Test2::V0) so that
    no class / module will be loaded and the variable **$CLASS** will not be imported at all.
    - **-tempdir** - activates creation of a temporary directory. The value has to be a hash reference with content
    as explained in [File::Temp::tempdir](https://metacpan.org/pod/File::Temp). This means, you can control the creation of
    temporary directory by passing of necessary parameters in form of a hash reference or, if the default behavior is
    required, simply pass the empty hash reference as the option value.
    - **-tempfile** - activates creation of a temporary file. The value has to be a hash reference with content as explained in
    [File::Temp::tempfile](https://metacpan.org/pod/File::Temp). This means, you can control the creation of
    temporary file by passing of necessary parameters in form of a hash reference or, if the default behavior is
    required, simply pass the empty hash reference as the option value.
- All other valid options (i.e. arguments starting with the dash sign **-**) are forwarded to
[Test2::V0](https://metacpan.org/pod/Test2::V0) along with their values.

    Options without values are not supported; in case of their passing an exception is raised.

- If an argument cannot be recognized as an option, an exception is raised.

**Test::Expander** is recommended to be the very first module in your test file.

The only exception currently known is the case, when some actions performed on the module level
(e.g. determination of constants) rely upon results of other actions (e.g. mocking of built-ins).

To explain this let us assume that your test file should mock the built-in **close**
to verify if the testee properly reacts both on its success and failure.
For this purpose a reasonable implementation might look as follows:

```perl
my $closeSuccess = 1;
BEGIN {
    *CORE::GLOBAL::close = sub (*) { return $closeSuccess ? CORE::close($_[0]) : 0 }
}

use Test::Expander;
```

The automated recognition of name of class / module to be tested can only work
if the test file is located in the corresponding subdirectory.
For instance, if the class / module to be tested is _Foo::Bar::Baz_, then the folder with test files
related to this class / module should be **t/**_Foo_**/**_Bar_**/**_Baz_ or **xt/**_Foo_**/**_Bar_**/**_Baz_
(the name of the top-level directory in this relative name - **t**, or **xt**, or **my\_test** is not important) -
otherwise the module name cannot be put into the exported variable **$CLASS** and, if you want to use this variable,
should be supplied as the value of **-target**:

```perl
use Test::Expander -target => 'Foo::Bar::Baz';
```

This recognition can explicitly be deactivated if the value of **-target** is **undef**, so that no class / module
will be loaded and, correspondingly, the variables **$CLASS**, **$METHOD**, and **$METHOD\_REF** will not be exported.

Furthermore, the automated recognition of the name of the method / subroutine to be tested only works if the file
containing the class / module mentioned above exists and if this class / module has the method / subroutine
with the same name as the test file base name without the extension.
If this is the case, the exported variables **$METHOD** and **$METHOD\_REF** contain the name of method / subroutine
to be tested and its reference, correspondingly, otherwise both variables are neither evaluated nor exported.

Also in this case evaluation and export of the variables **$METHOD** and **$METHOD\_REF** can be prevented
by passing of **undef** as value of the option **-method**:

```perl
use Test::Expander -target => undef;
```

Finally, **Test::Expander** supports testing inside of a clean environment containing only some clearly
specified environment variables required for the particular test.
Names and values of these environment variables should be configured in files,
the names of which are identical with paths to single class / module levels or the method / subroutine to be tested,
and the extension is always **.env**.
For instance, if the test file name is **t/Foo/Bar/Baz/myMethod.t**, the following approach is applied:

- if the file **t/Foo.env** exists, its content is used for the initialization of the test environment,
- if the file **t/Foo/Bar.env** exists, its content is used either to extend the test environment
initialized in the previous step or for its initialization if **t/Foo.env** does not exist,
- if the file **t/Foo/Bar/Baz.env** exists, its content is used either to extend the test
environment initialized in one of the previous steps or for its initialization if neither **t/Foo.env** nor
**t/Foo/Bar.env** exist,
- if the file **t/Foo/Bar/Baz/myMethod.env** exists, its content is used either to extend the test environment
initialized in one of the previous steps or for its initialization if none of **.env** files mentioned above exist.

If the **.env** files existing on different levels have identical names of environment variables,
the priority is the higher the later they have been detected.
I.e. **VAR = 'VALUE0'** in **t/Foo/Bar/Baz/myMethod.env** overwrites **VAR = 'VALUE1'** in **t/Foo/Bar/Baz.env**.

If none of these **.env** files exist, the environment isn't changed by **Test::Expander**
during the execution of **t/Foo/Bar/Baz/myMethod.t**.

An environment configuration file (**.env** file) is a line-based text file.
Its content is interpreted as follows:

- if such files don't exist, the **%ENV** hash remains unchanged;
- otherwise, if at least one of such files exists, those elements of **%ENV** are kept,
which names are equal to names found in lines of **.env** file without values.
All remaining elements of the **%ENV** gets emptied (without localization) and
    - lines not matching the RegEx **/^\\w+\\s\*(?:=\\s\*\\S|$)?/** (some alphanumeric characters representing a name of
    environment variable, optional blanks, optionally followed by the equal sign, again optional blanks,
    and at least one non-blank character representing the first character of environment variable value) are skipped;
    - in all other lines the value of the environment variable is everything from the first non-blank
    character after the equal sign until end of the line;
    if this value is omitted, the corresponding environment variable remains unchanged as it originally was in the **%ENV**
    (if it existed there, of course);
    - the value of the environment variable (if provided) is evaluated by the
    [string eval](https://perldoc.perl.org/functions/eval) so that
        - constant values must be quoted;
        - variables and subroutines must not be quoted:

                NAME_CONST = 'VALUE'
                NAME_VAR   = $KNIB::App::MyApp::Constants::ABC
                NAME_FUNC  = join(' ', $KNIB::App::MyApp::Constants::DEF)

All environment variables set up in this manner are logged to STDOUT
using [note](https://metacpan.org/pod/Test2::Tools::Basic#DIAGNOSTICS).

Another common feature within test suites is the creation of a temporary directory / file used as an
isolated container for some testing actions.
The module options **-tempdir** and **-tempfile** are fully syntactically compatible with
[File::Temp::tempdir](https://metacpan.org/pod/File::Temp#FUNCTIONS) /
[File::Temp::tempfile](https://metacpan.org/pod/File::Temp#FUNCTIONS). They make sure that such temporary
directory / file are created after **use Test::Expander** and that their names are stored in the variables
**$TEMP\_DIR** / **$TEMP\_FILE**, correspondingly.
Both temporary directory and file are removed by default after execution.

The following functions provided by this module are exported by default:

- all functions exported by default from [Test2::V0](https://metacpan.org/pod/Test2::V0),
- all functions exported by default from [Test2::Tools::Explain](https://metacpan.org/pod/Test2::Tools::Explain),
- some functions exported by default from [Test::More](https://metacpan.org/pod/Test::More)
and often used in older tests but not supported by [Test2::V0](https://metacpan.org/pod/Test2::V0):
    - BAIL\_OUT,
    - is\_deeply,
    - new\_ok,
    - require\_ok,
    - use\_ok.
- some functions exported by default from [Test::Exception](https://metacpan.org/pod/Test::Exception)
and often used in older tests but not supported by [Test2::V0](https://metacpan.org/pod/Test2::V0):

    - dies\_ok,
    - lives\_ok,
    - throws\_ok.

    some functions exported by default from [Test2::Tools::Explain](https://metacpan.org/pod/Test2::Tools::Explain)
    and often used in older tests but not supported by
    [Test2::Tools::Explain](https://metacpan.org/pod/Test2::Tools::Explain):

    - explain.

- function exported by default from [Const::Fast](https://metacpan.org/pod/Const::Fast):
    - const.
- some functions exported by request from [File::Temp](https://metacpan.org/pod/File::Temp):
    - tempdir,
    - tempfile,
- some functions exported by request from [Path::Tiny](https://metacpan.org/pod/Path::Tiny):
    - cwd,
    - path,

The following variables can be set and exported:

- variable **$CLASS** containing the name of the class / module to be tested
if the class / module recognition is not disable and possible,
- variable **$METHOD** containing the name of the method / subroutine to be tested
if the method / subroutine recognition is not disable and possible,
- variable **$METHOD\_REF** containing the reference to the subroutine to be tested
if the method / subroutine recognition is not disable and possible,
- variable **$TEMP\_DIR** containing the name of a temporary directory created at compile time
if the option **-tempdir** is supplied,
- variable **$TEMP\_FILE** containing the name of a temporary file created at compile time
if the option **-tempfile** is supplied.

All variables mentioned above are read-only after their export.
In this case they are logged to STDOUT using [note](https://metacpan.org/pod/Test2::Tools::Basic#DIAGNOSTICS).

# AUTHOR

Jurij Fajnberg, &lt;fajnbergj at gmail.com>

# BUGS

Please report any bugs or feature requests through the web interface at
[https://github.com/jsf116/Test-Expander/issues](https://github.com/jsf116/Test-Expander/issues).

# COPYRIGHT AND LICENSE

Copyright (c) 2021-2023 Jurij Fajnberg

This program is free software; you can redistribute it and/or modify it under the same terms
as the Perl 5 programming language system itself.
