#!/usr/bin/env bash
# Build and install GIMP with gimp-scribble.patch: scribble over strokes to erase them (GoodNotes
# style). Uses Arch's own gimp recipe for the version in the repos, so the result is the official
# package plus the patch, marked with a ".1" pkgrel and "scribble-to-erase" in its description.
#
# A GIMP update from the repos replaces it with the unpatched build; the pacman hook this script
# installs says so after the upgrade, then run this again. `--force` rebuilds even if up to date.
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
WORK=${XDG_CACHE_HOME:-$HOME/.cache}/gimp-scribble
MARK=scribble-to-erase
RECIPE=https://gitlab.archlinux.org/archlinux/packaging/packages/gimp.git

# pacman hook: warn when an update drops the patch
hook=/etc/pacman.d/hooks/gimp-scribble.hook
if ! sed "s|@BUILD@|$HERE/build.sh|" "$HERE/gimp-scribble.hook" | cmp -s - "$hook"; then
    sed "s|@BUILD@|$HERE/build.sh|" "$HERE/gimp-scribble.hook" | sudo install -Dm644 /dev/stdin "$hook"
    echo "installed $hook"
fi

ver=$(LC_ALL=C pacman -Si gimp | sed -n 's/^Version *: //p')
if [[ ${1:-} != --force ]] && LC_ALL=C pacman -Qi gimp 2>/dev/null | grep -q "$MARK" &&
   [[ $(pacman -Q gimp | cut -d' ' -f2) == "$ver.1" ]]; then
    echo "GIMP $ver with the scribble patch is already installed (--force to rebuild)."
    exit 0
fi

echo "Building GIMP $ver with the scribble patch in $WORK"
rm -rf "$WORK"
git clone -q --depth 1 --branch "$ver" "$RECIPE" "$WORK"
cp "$HERE/gimp-scribble.patch" "$WORK/"
cd "$WORK"

# the official recipe, plus: our pkgrel/description, the patch as a source, applied in prepare()
sed -i -e 's/^pkgrel=\(.*\)/pkgrel=\1.1/' \
       -e "s/^pkgdesc='\(.*\)'/pkgdesc='\1 ($MARK patch)'/" PKGBUILD
cat >> PKGBUILD <<'EOF'

source+=(gimp-scribble.patch)
sha256sums+=(SKIP)
eval "_official_$(declare -f prepare)"
prepare() {
  _official_prepare
  git -C "$srcdir/$pkgname" apply "$srcdir/gimp-scribble.patch" || {
    echo "gimp-scribble.patch doesn't apply to GIMP $pkgver; it needs updating for this version." >&2
    return 1
  }
}
EOF

makepkg --syncdeps --nocheck --noconfirm
sudo pacman -U --noconfirm "$WORK"/gimp-"$ver".1-*.pkg.tar.zst
echo "Installed GIMP $ver.1 with scribble-to-erase."
