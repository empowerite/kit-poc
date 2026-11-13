# Customize

kit is a starting point, built to be changed without forking it.

## Everything kit adds comes from a package

kit adds nothing by itself. A package is a directory in a release, and every file kit delivers belongs to one.

## Settings live in one file

`kit.yml` is the one file of settings: the active packages, the version of kit the repository pins, and the
patterns that names must match.

## An update leaves your files alone

A release is versioned and pinned, and an update replaces what kit delivered and nothing else.
