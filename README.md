# calbuilder
GitHub action to build a package, analyze it with namcap, and output the package file and its .SRCINFO.

This action supports PKGBUILDs that have AUR dependencies.

## Inputs and outputs
Inputs:
* `pkgDir`: PKGBUILD directory relative path.
* `gpgPublicKey`: GPG public key that will be used to sign packages.
* `gpgPrivateKey`: GPG private key.
* `gpgPassphrase`: The GPG passphrase for the gpgPrivateKey.

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
    - id: calbuilder
      uses: santilococo/calbuilder@master
    - uses: actions/upload-artifact@v2
      with:
        path: |
          ${{ steps.calbuilder.outputs.srcInfo }}
          ${{ steps.calbuilder.outputs.pkgFile }}
```
