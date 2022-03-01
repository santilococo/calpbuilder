#!/usr/bin/env bash

addUser() {
    useradd calbuilder -m
    echo "calbuilder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    visudo -c
    chmod -R a+rw .
}

installAurDeps() {
    aurPkgs=()
    sudo -u calbuilder makepkg --printsrcinfo > .SRCINFO
    regExp="^[[:space:]]*\(make\)\?depends\(.\)* = \([[:alnum:][:punct:]]*\)[[:space:]]*$"
    mapfile -t pkgDeps < <(sed -n -e "s/$regExp/\3/p" .SRCINFO)
    for pkgDep in "${pkgDeps[@]}"; do
        pkgName=$(echo "$pkgDep" | sed 's/[><=].*//')
        set +e
        pkgInfo=$(pacman -Ss "${pkgName}" 2> /dev/null)
        set -e
        if ! echo $pkgInfo | grep -q "\/${pkgName} "; then
            aurPkgs+=("$pkgName")
        fi
    done
    if [ "${#aurPkgs[@]}" -gt 0 ]; then
        pacman -S --noconfirm --needed git
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin; sudo -Hu calbuilder makepkg -si --noconfirm; cd ..
        for aurPkg in "${aurPkgs[@]}"; do
            paru -S --noconfirm "$aurPkg"
        done
        rm -rf paru-bin 
    fi
}

importPrivateKey() {
    echo "$gpgPrivateKey" > private.key
    gpgFlags=("--batch" "--pinentry-mode" "loopback" "--passphrase")
    sudo -Hu calbuilder gpg "${gpgFlags[@]}" "$gpgPassphrase" --import private.key
    rm private.key
    sedCommand="gpg ${gpgFlags[*]} \"$gpgPassphrase\""
    makepkgSigFile="/usr/share/makepkg/integrity/generate_signature.sh"
    sed -i -e "s/gpg/$sedCommand/" $makepkgSigFile
}

buildPackage() {
    if [ -n "$gpgPrivateKey" ] && [ -n "$gpgPublicKey" ]; then
        importPrivateKey
        sudo -Hu calbuilder makepkg -s --sign --key "$gpgPublicKey" --noconfirm
    else
        sudo -Hu calbuilder makepkg -s --noconfirm
    fi
}

exportPackageFiles() {
    sudo -u calbuilder makepkg --printsrcinfo > .SRCINFO
    exportFile "srcInfo" ".SRCINFO"

    pkgFile=$(sudo -u calbuilder makepkg --packagelist)
    if [ -f "$pkgFile" ]; then
        relPkgFile="$(realpath --relative-base="$baseDir" "$pkgFile")"
        exportFile "pkgFile" "$relPkgFile" "$pkgFile"
        if [ -n "$gpgPrivateKey" ]; then
            exportFile "pkgFileSig" "$relPkgFile.sig" "$pkgFile.sig"
        fi
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
    pkgFile=$(sudo -u calbuilder makepkg --packagelist)
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

    pacman -Syu --needed --noconfirm base-devel

    getInputs
    addUser

    baseDir="$PWD"
    if [ -n "$pkgDir" ] && [ "$pkgDir" != "." ]; then 
        inBaseDir=false
        cd "$pkgDir"
    else
        inBaseDir=true
    fi
    oldFiles=$(find -H "$PWD" -not -path '*.git*')

    installAurDeps
    buildPackage
    ls -al
    exportPackageFiles
    namcapAnalysis

    newFiles=$(find -H "$PWD" -not -path '*.git*')
    mapfile -t toRemove < <(printf '%s\n%s\n' "$newFiles" "$oldFiles" | sort | uniq -u)
    rm -rf "${toRemove[@]}"
}

runScript "$@"
