#!/usr/bin/env bash

getInputs() {
    gpgPrivateKey="$INPUT_GPGPRIVATEKEY"
    gpgPublicKey="$INPUT_GPGPUBLICKEY"
    gpgPassphrase="$INPUT_GPGPASSPHRASE"
    pkgDir="$INPUT_PKGDIR"
}

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
        if ! echo "$pkgInfo" | grep -q "\/${pkgName} "; then
            aurPkgs+=("$pkgName")
        fi
    done
    if [ "${#aurPkgs[@]}" -gt 0 ]; then
        pacman -Su --noconfirm --needed git
        sudo -u calbuilder git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin; sudo -Hu calbuilder makepkg -si --noconfirm; cd ..
        for aurPkg in "${aurPkgs[@]}"; do
            sudo -Hu calbuilder paru -S --noconfirm "$aurPkg"
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
    pacman -S --noconfirm pacman-contrib
    sudo -Hu calbuilder updpkgsums
    if [ -n "$gpgPrivateKey" ] && [ -n "$gpgPublicKey" ]; then
        importPrivateKey
        sudo -Hu calbuilder makepkg -s --sign --key "$gpgPublicKey" --noconfirm
    else
        sudo -Hu calbuilder makepkg -s --noconfirm
    fi
}

printWarnings() {
    [ ${#warnings[@]} -eq 0 ] && return
    for warning in "${warnings[@]}"; do
        echo "::warning::$1 ——— $warning"
    done
}

namcapAnalysis() {
    pacman -S --noconfirm namcap
    mapfile -t warnings < <(namcap PKGBUILD)
    printWarnings "PKGBUILD"
    pkgFile=$(sudo -u calbuilder makepkg --packagelist)
    pkgFile=$(basename "$pkgFile")
    if [ -f "$pkgFile" ]; then
        mapfile -t warnings < <(namcap "$pkgFile")
        printWarnings "$pkgFile"
    fi
}

exportFile() {
    [ "$inBaseDir" = false ] && mv "$2" /github/workspace
    echo "::set-output name=$1::$2"
}

exportPackageFiles() {
    sudo -u calbuilder makepkg --printsrcinfo > .SRCINFO
    exportFile "srcInfo" ".SRCINFO"

    pkgFile=$(sudo -u calbuilder makepkg --packagelist)
    pkgFile=$(basename "$pkgFile")
    if [ -f "$pkgFile" ]; then
        exportFile "pkgFile" "$pkgFile"
        if [ -n "$gpgPrivateKey" ]; then
            exportFile "pkgFileSig" "$pkgFile.sig"
        fi
    fi
}

runScript() {
    set -euo pipefail
    getInputs
    addUser

    if [ -n "$pkgDir" ] && [ "$pkgDir" != "." ]; then 
        inBaseDir=false
        cd "$pkgDir"
    else
        inBaseDir=true
    fi
    findArgs=("-not" "-path" "*.git*")
    oldFiles=$(find -H "$PWD" "${findArgs[@]}")

    pacman -Sy
    installAurDeps
    buildPackage
    namcapAnalysis
    exportPackageFiles

    findArgs+=("-not" "-name" "$pkgFile*" "-not" "-name" ".SRCINFO")
    newFiles=$(find -H "$PWD" "${findArgs[@]}")
    files=$(printf '%s\n%s\n' "$newFiles" "$oldFiles")
    mapfile -t toRemove < <(echo "$files" | sort | uniq -u)
    rm -rf "${toRemove[@]}"
}

runScript "$@"
