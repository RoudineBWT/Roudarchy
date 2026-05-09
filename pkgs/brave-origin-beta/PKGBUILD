pkgname=brave-origin-beta-bin
pkgver=1.91.145
pkgrel=1
pkgdesc="Brave Origin Web Browser — Beta channel (sans Rewards/Wallet/Leo)"
arch=('x86_64')
url="https://brave.com"
license=('custom')
depends=(
  'gtk3' 'nss' 'alsa-lib' 'libxss' 'ttf-font'
  'libnotify' 'dbus' 'xdg-utils' 'libcups'
)
optdepends=(
  'plasma-browser-integration: KDE Plasma integration'
  'kdialog: KDE file picker'
  'libgnome-keyring: GNOME keyring support'
)
provides=('brave-origin-beta')
conflicts=('brave-origin-beta')
options=('!strip')

_appname="brave-origin-beta"
_binname="brave-origin-beta"
_flagsfile="brave-origin-beta-flags.conf"
_filename="brave-origin-beta_${pkgver}_amd64.deb"
source=("${_filename}::https://github.com/brave/brave-browser/releases/download/v${pkgver}/${_filename}")
sha256sums=('312b6d44a452987c949b6ebc886076e67a90e2e633c187221a34420be476ed44')

_icon_suffixes=("_beta" "_origin_beta" "" "_release")

prepare() {
  cd "$srcdir"
  bsdtar -xf "${_filename}"
  bsdtar -xf data.tar.xz
}

_install_icons() {
  local app_dir="$1" icon_name="$2" found=0
  for size in 16 24 32 48 64 128 256; do
    for suffix in "${_icon_suffixes[@]}"; do
      local src="${app_dir}/product_logo_${size}${suffix}.png"
      if [ -f "$src" ]; then
        install -Dm644 "$src" \
          "$pkgdir/usr/share/icons/hicolor/${size}x${size}/apps/${icon_name}.png"
        found=1
        break
      fi
    done
  done
  [[ "$found" -eq 0 ]] && echo "WARNING: aucune icône trouvée pour $icon_name"
}

package() {
  cd "$srcdir"

  install -d "$pkgdir/opt/brave.com/${_appname}"
  cp -a "opt/brave.com/${_appname}/." "$pkgdir/opt/brave.com/${_appname}/"
  chmod 4755 "$pkgdir/opt/brave.com/${_appname}/chrome-sandbox"

  install -Dm755 /dev/stdin "$pkgdir/usr/bin/${_binname}" <<EOF
#!/usr/bin/env bash
XDG_CONFIG_HOME="\${XDG_CONFIG_HOME:-"\${HOME}/.config"}"
FLAGS_FILE="\${XDG_CONFIG_HOME}/${_flagsfile}"
FLAG_LIST=()

if [[ -f "\$FLAGS_FILE" ]]; then
  mapfile -t _lines < "\$FLAGS_FILE"
  for line in "\${_lines[@]}"; do
    line="\$(sed -e 's/[[:space:]]*#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*\$//' <<< "\$line")"
    [[ -n "\$line" ]] && FLAG_LIST+=("\$line")
  done
fi

export CHROME_VERSION_EXTRA='beta'
export CHROME_WRAPPER="\$(readlink -f "\$0")"
export GNOME_DISABLE_CRASH_DIALOG=SET_BY_GOOGLE_CHROME

exec < /dev/null
exec > >(exec cat)
exec 2> >(exec cat >&2)

exec /opt/brave.com/${_appname}/brave "\${FLAG_LIST[@]}" "\$@"
EOF

  if [ -f "usr/share/applications/brave-origin-beta.desktop" ]; then
    install -Dm644 "usr/share/applications/brave-origin-beta.desktop" \
      "$pkgdir/usr/share/applications/brave-origin-beta.desktop"
  else
    install -Dm644 /dev/stdin \
      "$pkgdir/usr/share/applications/brave-origin-beta.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Name=Brave Origin Beta
GenericName=Web Browser
Comment=Brave Origin — minimalist browser (Beta)
Exec=/usr/bin/brave-origin-beta %U
StartupNotify=true
Terminal=false
Icon=brave-origin-beta
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF
  fi

  _install_icons "opt/brave.com/${_appname}" "brave-origin-beta"

  install -Dm644 "opt/brave.com/${_appname}/LICENSE" \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE" 2>/dev/null || true
}
