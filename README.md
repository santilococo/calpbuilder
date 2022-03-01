# calbuilder
GitHub action to build a package, analyze it with `namcap`, and output the package file (signed or unsigned) and its `.SRCINFO`.

This action supports PKGBUILDs that have AUR dependencies.

## Table of contents
  - [Inputs and outputs <a name="inputs-and-outputs-"></a>](#inputs-and-outputs--)
  - [Usage <a name="usage"></a>](#usage-)
  - [Contributing <a name="contributing"></a>](#contributing-)
  - [License <a name="license"></a>](#license-)

## Inputs and outputs <a name="inputs-and-outputs-"></a>
### Inputs:
* `pkgDir`: PKGBUILD directory relative path.
* `gpgPublicKey`: GPG public key that will be used to sign packages.
* `gpgPrivateKey`: GPG private key.
* `gpgPassphrase`: The GPG passphrase for the `gpgPrivateKey`.

It is recommended that you store the `gpgPrivateKey` and the `gpgPassphrase` as secrets (see [Usage <a name="usage"></a>](#usage-)).

None of these inputs are required. 

### Outputs:
* `srcInfo`: Generated `.SRCINFO`.
* `pkgFile`: Built package file.

## Usage <a name="usage"></a>
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
        pkgDir: "libxft-bgra"
        gpgPublicKey: "199980CE93F18E62"
        gpgPrivateKey: "${{ secrets.GPG_PRIVATE_KEY }}"
        gpgPassphrase: "${{ secrets.GPG_PASSPHRASE }}"
    - uses: actions/upload-artifact@v2
      with:
        path: |
          ${{ steps.calbuilder.outputs.srcInfo }}
          ${{ steps.calbuilder.outputs.pkgFile }}
```

## Contributing <a name="contributing"></a>
PRs are welcome.

## License <a name="license"></a>
[MIT](https://raw.githubusercontent.com/santilococo/calbuilder/master/LICENSE.md)
