# Evolibs Shell

A cocktail of libraries to use in your Shell scripts.

## Libraries

### calendar

Functions to know if now is a holiday, a working day, a working hour…

### os-release

Functions to know if the OS is Debian and which version it is.

## Usage

Those libraries should be installed in `/usr/[local/]lib/evolibs-shell`, but you can put them wherever you want.

They can be sourced all at once or one by one.

There is an `example.sh` script in the repository.

## Tests

The test suite is based on [Bats](https://bats-core.readthedocs.io/en/stable/).

On Debian, you can `apt install bats`.

You can run the tests locally :

```bash
$ EVOLIBS_SHELL_LIB=./lib bats test/*.bats
/path/to/test/calendar.bats
 ✓ is_holiday returns nothing
 ✓ is_holiday returns 0 for January 1st
 ✓ is_holiday returns 1 for January 2nd
 ✓ is_weekend returns nothing
 ✓ is_weekend returns 1 when it's monday/tuesday/wednesday/thursday/friday
 ✓ is_weekend returns 0 when it's saturday/sunday
 ✓ is_workday returns nothing
 ✓ is_workday returns 1 for a holiday or weekend
 ✓ is_workday returns 0 a regular weekday
 ✓ is_worktime returns nothing
 ✓ is_worktime returns 0 for a regular weekday during working hours
 ✓ is_worktime returns 1 for a regular weekday outside working hours
/path/to/test/os-release.bats
 ✓ parse reads default file
 ✓ parse reads custom file
 ✓ is_debian without values
 ✓ is_debian with version
 ✓ is_debian with version and operator
 ✓ is_debian with bad operator

18 tests, 0 failures
```
