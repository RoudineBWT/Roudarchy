#!/usr/bin/env bash
# update.sh — Met à jour tous les canaux Brave (stable, beta, nightly, origin-beta, origin-nightly)
set -euo pipefail

declare -A UPDATED_VERSIONS=()
declare -A SKIPPED=()

# ──────────────────────────────────────────────────────────────────────────────
# update_package LABEL  PKGBUILD_PATH  ASSET_NAME  IS_PRERELEASE
# ──────────────────────────────────────────────────────────────────────────────
update_package() {
  local LABEL="$1"
  local PKGBUILD="$2"
  local ASSET_NAME="$3"
  local IS_PRERELEASE="$4"
  local HASH_TYPE="${5:-sha256}"  # sha256 ou sha512

  echo "──────────────────────────────────────"
  echo "🔍 Checking $LABEL..."

  # Guard : si le dossier/PKGBUILD n'existe pas, on skip proprement
  if [[ ! -f "$PKGBUILD" ]]; then
    echo "⚠️  $PKGBUILD introuvable, skip."
    SKIPPED["$LABEL"]="PKGBUILD manquant"
    return 0
  fi

  local FILTER
  if [[ "$IS_PRERELEASE" == "true" ]]; then
    FILTER='map(select(.prerelease == true))'
  else
    FILTER='map(select(.prerelease == false))'
  fi

  local VERSION
  VERSION=$(curl -s \
    -H "Authorization: Bearer ${GITHUB_TOKEN:-}" \
    "https://api.github.com/repos/brave/brave-browser/releases?per_page=100" \
    | jq -r \
      --arg asset "${ASSET_NAME}" \
      "${FILTER}
       | map(select(
           .assets | any(.name | startswith(\$asset) and endswith(\"_amd64.deb\"))
         ))
       | sort_by(.published_at) | reverse | .[0].tag_name // empty" \
    | sed 's/^v//')

  # Guard : aucune release trouvée pour ce canal (ex: origin stable pas encore sorti)
  if [[ -z "$VERSION" ]]; then
    echo "⚠️  Aucune release trouvée pour $LABEL (canal peut-être pas encore publié), skip."
    SKIPPED["$LABEL"]="Aucune release disponible"
    return 0
  fi

  echo "✅ Dernière version $LABEL : $VERSION"

  # Vérifie que l'asset est bien accessible (HTTP 200)
  local DEB_URL="https://github.com/brave/brave-browser/releases/download/v${VERSION}/${ASSET_NAME}${VERSION}_amd64.deb"
  local HTTP_CODE
  HTTP_CODE=$(curl -s -L -o /dev/null -w "%{http_code}" "$DEB_URL")
  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "⚠️  Asset non disponible (HTTP $HTTP_CODE) pour $LABEL, skip."
    SKIPPED["$LABEL"]="Asset HTTP $HTTP_CODE"
    return 0
  fi

  # Récupère la version et le sha256 actuels
  local CURRENT_VER CURRENT_SHA
  CURRENT_VER=$(grep '^pkgver=' "$PKGBUILD" | cut -d= -f2)
  if [[ "$HASH_TYPE" == "sha512" ]]; then
    CURRENT_SHA=$(grep '^sha512sums_x86_64=' "$PKGBUILD" | sed "s/sha512sums_x86_64=('//;s/')//" )
  else
    CURRENT_SHA=$(grep '^sha256sums=' "$PKGBUILD" | sed "s/sha256sums=('//;s/')//" )
  fi

  if [[ "$CURRENT_VER" == "$VERSION" && "$CURRENT_SHA" != "PLACEHOLDER" ]]; then
    echo "⏭️  $LABEL déjà à jour ($VERSION)."
    return 0
  fi

  # Calcul du hash
  echo "🔒 Calcul hash (téléchargement du .deb)..."
  local HASH
  if [[ "$HASH_TYPE" == "sha512" ]]; then
    HASH=$(curl -sL "$DEB_URL" | sha512sum | awk '{print $1}')
    echo "   sha512 : $HASH"
    sed -i \
      -e "s/^pkgver=.*/pkgver=${VERSION}/" \
      -e "s/^pkgrel=.*/pkgrel=1/" \
      -e "s/sha512sums_x86_64=('.*')/sha512sums_x86_64=('${HASH}')/" \
      "$PKGBUILD"
  else
    HASH=$(curl -sL "$DEB_URL" | sha256sum | awk '{print $1}')
    echo "   sha256 : $HASH"
    sed -i \
      -e "s/^pkgver=.*/pkgver=${VERSION}/" \
      -e "s/^pkgrel=.*/pkgrel=1/" \
      -e "s/sha256sums=('.*')/sha256sums=('${HASH}')/" \
      "$PKGBUILD"
  fi

  echo "✏️  $CURRENT_VER → $VERSION"
  UPDATED_VERSIONS["$LABEL"]="$VERSION"
}

# ──────────────────────────────────────────────────────────────────────────────
# Mise à jour des 5 canaux
# ──────────────────────────────────────────────────────────────────────────────
update_package "Brave Stable"         "pkgs/brave-stable/PKGBUILD"         "brave-browser_"          "false" "sha256"
update_package "Brave Beta"           "pkgs/brave-beta/PKGBUILD"           "brave-browser-beta_"     "true"  "sha256"
update_package "Brave Nightly"        "pkgs/brave-nightly/PKGBUILD"        "brave-browser-nightly_"  "true"  "sha256"
update_package "Brave Origin Beta"    "pkgs/brave-origin-beta/PKGBUILD"    "brave-origin-beta_"      "true"  "sha512"
update_package "Brave Origin Nightly" "pkgs/brave-origin-nightly/PKGBUILD" "brave-origin-nightly_"   "true"  "sha512"

# ──────────────────────────────────────────────────────────────────────────────
# Résumé
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════"
set +u
if [[ ${#UPDATED_VERSIONS[@]} -eq 0 && ${#SKIPPED[@]} -eq 0 ]]; then
  echo "✅ Tous les canaux sont déjà à jour."
fi

if [[ ${#UPDATED_VERSIONS[@]} -gt 0 ]]; then
  echo "📦 Canaux mis à jour :"
  for key in "${!UPDATED_VERSIONS[@]}"; do
    echo "   ✅ $key → ${UPDATED_VERSIONS[$key]}"
  done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo "⏭️  Canaux ignorés :"
  for key in "${!SKIPPED[@]}"; do
    echo "   ⚠️  $key : ${SKIPPED[$key]}"
  done
fi
set -u
echo "══════════════════════════════════════"
