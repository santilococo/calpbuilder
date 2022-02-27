# calbuilder
GitHub action to build PKGFILE, analyze it with namcap and output its .SRCINFO.

## Inputs and outputs
Inputs:
* `pkgDir`: PKGBUILD directory relative path.

Outputs:
* `srcInfo`: Generated `.SRCINFO`.
* `pkgFile`: Built package file.

## Usage
```yaml
name: CI

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - id: makepkg
      uses: santilococo/calbuilder@master
    - uses: actions/upload-artifact@v2
      with:
        path: ${{ steps.makepkg.outputs.srcInfo }}
        path: ${{ steps.makepkg.outputs.pkgFile }}
```
