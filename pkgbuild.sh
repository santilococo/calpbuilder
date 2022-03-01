#!/usr/bin/env bash

setPermissions() {
    echo "nobody ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    visudo -c
    chmod -R a+rw .
}

importPrivateKey() {
    echo "$gpgPrivateKey" > private.key
    gpgFlags=("--batch" "--pinentry-mode" "loopback" "--passphrase")
    gpg "${gpgFlags[@]}" "$gpgPassphrase" --import private.key
    rm private.key
    sedCommand="gpg ${gpgFlags[*]} \"$gpgPassphrase\""
    makepkgSigFile="/usr/share/makepkg/integrity/generate_signature.sh"
    sed -i -e "s/gpg/$sedCommand/" $makepkgSigFile
}

buildPackage() {
    if [ -n "$gpgPrivateKey" ] && [ -n "$gpgPublicKey" ]; then
        importPrivateKey
        sudo -u nobody makepkg -s --sign --key "$gpgPublicKey" --noconfirm
    else
        sudo -u nobody makepkg -s --noconfirm
    fi
}

exportPackageFiles() {
    sudo -u nobody makepkg --printsrcinfo > .SRCINFO
    exportFile "srcInfo" ".SRCINFO"

    pkgFile=$(sudo -u nobody makepkg --packagelist)
    if [ -f "$pkgFile" ]; then
        relPkgFile="$(realpath --relative-base="$baseDir" "$pkgFile")"
        exportFile "pkgFile" "$relPkgFile" "$pkgFile"
    fi
}

exportFile() {
    echo "::set-output name=$1::$2"
    if [ "$inBaseDir" = false ]; then
        [ $# -eq 2 ] && pkgFile=$2 || pkgFile=$3
        mv "$pkgFile" /github/workspace
    fi
}

namcapAnalysis() {
    pacman -S --noconfirm namcap

    mapfile -t warnings < <(namcap PKGBUILD)
    printWarnings "PKGBUILD"
    if [ -f "$pkgFile" ]; then
        relPkgFile="$(realpath --relative-base="$baseDir" "$pkgFile")"
        mapfile -t warnings < <(namcap "$pkgFile")
        printWarnings "$relPkgFile"
    fi
}

printWarnings() {
    [ ${#warnings[@]} -eq 0 ] && return
    for warning in "${warnings[@]}"; do
        echo "::warning::$1 ——— $warning"
    done
}

getInputs() {
    gpgPrivateKey="$INPUT_GPGPRIVATEKEY"
    gpgPublicKey="$INPUT_GPGPUBLICKEY"
    gpgPassphrase="$INPUT_GPGPASSPHRASE"
    pkgDir="$INPUT_PKGDIR"
}

runScript() {
    set -euo pipefail

    pacman -Syu --noconfirm base-devel

    getInputs
    setPermissions

    baseDir="$PWD"
    if [ -n "$pkgDir" ] && [ "$pkgDir" != "." ]; then 
        inBaseDir=false
        cd "$pkgDir"
    else
        inBaseDir=true
    fi
    oldFiles=$(find -H "$PWD" -not -path '*.git*')

    buildPackage

    exportPackageFiles
    namcapAnalysis

    newFiles=$(find -H "$PWD" -not -path '*.git*')
    mapfile -t toRemove < <(printf '%s\n%s\n' "$newFiles" "$oldFiles" | sort | uniq -u)
    rm -rf "${toRemove[@]}"
}

runScript "$@"
