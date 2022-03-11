FROM archlinux:base-devel

COPY pkgbuild.sh /pkgbuild.sh

ENTRYPOINT ["/pkgbuild.sh"]