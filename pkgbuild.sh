#!/usr/bin/env bash

set -euo pipefail

pacman -Syu --noconfirm --needed base-devel

echo "nobody ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
visudo -c
chmod -R a+rw .

baseDir="$PWD"
cd "${INPUT_PKGDIR:-.}"
oldFiles=$(find -H "$PWD")

sudo -u nobody makepkg -s --noconfirm

sudo -u nobody makepkg --printsrcinfo > .SRCINFO
echo "::set-output name=srcInfo::.SRCINFO"
sudo mv .SRCINFO /github/workspace

pkgFile=$(sudo -u nobody makepkg --packagelist)
relPkgFile="$(realpath --relative-base="$baseDir" "$pkgFile")"
echo "::set-output name=pkgFile::$relPkgFile"
sudo mv "$pkgFile" /github/workspace

newFiles=$(find -H "$PWD")
toRemove=$(printf '%s\n%s\n' "$newFiles" "$oldFiles" | sort | uniq -u)
rm -rf "$toRemove"
