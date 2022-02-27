#!/usr/bin/env bash

pacman -Syu --noconfirm --needed base-devel
useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -R a+rw .

baseDir="$PWD"
cd "${INPUT_PKGDIR:-.}"
oldFiles=$(find -H "$PWD")

sudo -H -u builder makepkg --syncdeps --noconfirm ${INPUT_MAKEPKGARGS:-}

sudo -H -u builder makepkg --printsrcinfo > .SRCINFO
echo "::set-output name=srcInfo::.SRCINFO"
sudo mv .SRCINFO /github/workspace

relPkgFile="$(realpath --relative-base="$baseDir" "$pkgFile")"
echo "::set-output name=pkgFile::$relPkgFile"
sudo mv "$pkgFile" /github/workspace

newFiles=$(find -H $PWD)
toRemove=$(printf '%s\n%s\n' "$newFiles" "$oldFiles" | sort | uniq -u)
rm -rf $toRemove
