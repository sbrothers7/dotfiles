#!/usr/bin/env bash
# Install GIMP with gimp-scribble.patch: scribble over strokes to erase them (GoodNotes style),
# tuned in GIMP under Edit > Scribble Settings.
#
# The package is Arch's own gimp recipe for the version in the repos plus the patch, marked with
# a ".1" pkgrel and "scribble-to-erase patch <patch hash>" in its description. Prebuilt packages
# live in the releases of github.com/sbrothers7/gimp-scribble, tagged <version>.1-<patch hash>:
#
#   build.sh            install the release for this GIMP version and patch, else build from source
#   build.sh --build    build from source even if a release exists
#   build.sh --publish  upload the package last built from source as a release (needs gh)
#
# A GIMP update from the repos replaces it with the unpatched build; the pacman hook this script
# installs says so after the upgrade, then run this again.
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
WORK=${XDG_CACHE_HOME:-$HOME/.cache}/gimp-scribble
MARK=scribble-to-erase
RECIPE=https://gitlab.archlinux.org/archlinux/packaging/packages/gimp.git
RELEASES=sbrothers7/gimp-scribble
MODE=${1:-}

ver=$(LC_ALL=C pacman -Si gimp | sed -n 's/^Version *: //p')
patch_id=$(sha256sum "$HERE/gimp-scribble.patch" | cut -c1-8)
pkgver=$ver.1
tag=$pkgver-$patch_id
pkgfile=gimp-$pkgver-x86_64.pkg.tar.zst

if [[ $MODE == --publish ]]; then
    [[ -f $WORK/$pkgfile ]] && tar -I zstd -xOf "$WORK/$pkgfile" .PKGINFO | grep -q "$MARK patch $patch_id" || {
        echo "No $pkgfile built from the current patch in $WORK; run $0 --build first." >&2
        exit 1
    }
    (cd "$WORK" && sha256sum "$pkgfile" > "$pkgfile.sha256")
    cp "$HERE/gimp-scribble.patch" "$WORK/gimp-scribble-$patch_id.patch"
    gh release create "$tag" -R "$RELEASES" --title "GIMP $pkgver with scribble-to-erase ($patch_id)" \
        --notes "GIMP $ver for Arch Linux (x86_64) with gimp-scribble.patch $patch_id.

Built from Arch's gimp recipe at tag [$ver](https://gitlab.archlinux.org/archlinux/packaging/packages/gimp/-/tree/$ver) \
(GIMP upstream tag \`GIMP_${ver%-*}\` with dots as underscores) plus the attached patch. \
Install with \`sudo pacman -U $pkgfile\` or the dotfiles' \`gimp-scribble/build.sh\`." \
        "$WORK/$pkgfile" "$WORK/$pkgfile.sha256" "$WORK/gimp-scribble-$patch_id.patch"
    exit 0
fi

# pacman hook: warn when an update drops the patch
hook=/etc/pacman.d/hooks/gimp-scribble.hook
if ! sed "s|@BUILD@|$HERE/build.sh|" "$HERE/gimp-scribble.hook" | cmp -s - "$hook"; then
    sed "s|@BUILD@|$HERE/build.sh|" "$HERE/gimp-scribble.hook" | sudo install -Dm644 /dev/stdin "$hook"
    echo "installed $hook"
fi

if [[ -z $MODE ]] && LC_ALL=C pacman -Qi gimp 2>/dev/null | grep -q "$MARK patch $patch_id" &&
   [[ $(pacman -Q gimp | cut -d' ' -f2) == "$pkgver" ]]; then
    echo "GIMP $pkgver with scribble patch $patch_id is already installed (--build to rebuild)."
    exit 0
fi

# prebuilt release
if [[ $MODE != --build ]]; then
    dl=$(mktemp -d)
    trap 'rm -rf "$dl"' EXIT
    url=https://github.com/$RELEASES/releases/download/$tag
    if curl -fsSL -o "$dl/$pkgfile.sha256" "$url/$pkgfile.sha256" 2>/dev/null; then
        echo "Downloading GIMP $pkgver with scribble patch $patch_id from $RELEASES"
        curl -fL --progress-bar -o "$dl/$pkgfile" "$url/$pkgfile"
        (cd "$dl" && sha256sum -c --quiet "$pkgfile.sha256")
        sudo pacman -U --noconfirm "$dl/$pkgfile"
        echo "Installed GIMP $pkgver with scribble-to-erase."
        exit 0
    fi
    echo "No release $tag yet, building from source."
fi

echo "Building GIMP $ver with scribble patch $patch_id in $WORK"
rm -rf "$WORK"
git clone -q --depth 1 --branch "$ver" "$RECIPE" "$WORK"
cp "$HERE/gimp-scribble.patch" "$WORK/"
cd "$WORK"

# the official recipe, plus: our pkgrel/description, the patch as a source, applied in prepare()
sed -i -e 's/^pkgrel=\(.*\)/pkgrel=\1.1/' \
       -e "s/^pkgdesc='\(.*\)'/pkgdesc='\1 ($MARK patch $patch_id)'/" PKGBUILD
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
sudo pacman -U --noconfirm "$WORK/$pkgfile"
echo "Installed GIMP $pkgver with scribble-to-erase. Share it with: $0 --publish"
