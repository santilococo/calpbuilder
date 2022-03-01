#!/usr/bin/env bash

setPermissions() {
    echo "nobody ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    visudo -c
    chmod -R a+rw .
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

runScript() {
    set -euo pipefail

    pacman -Syu --noconfirm base-devel

    setPermissions

    baseDir="$PWD"
    [ -n "$INPUT_PKGDIR" ] && inBaseDir=true || inBaseDir=false
    cd "${INPUT_PKGDIR:-.}"
    oldFiles=$(find -H "$PWD" -not -path '*.git*')

    sudo -u nobody makepkg -s --noconfirm

    exportPackageFiles
    namcapAnalysis

    newFiles=$(find -H "$PWD" -not -path '*.git*')
    mapfile -t toRemove < <(printf '%s\n%s\n' "$newFiles" "$oldFiles" | sort | uniq -u)
    rm -rf "${toRemove[@]}"
}

runScript "$@"
