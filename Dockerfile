FROM archlinux:latest

COPY pkgbuild.sh /pkgbuild.sh

ENTRYPOINT ["/pkgbuild.sh"]