#!/usr/bin/env bash
#
# Builds a self-contained, statically linked qbittorrent-nox for macOS.
#
# Every dependency (OpenSSL, Boost, Qt, libtorrent) is built from pinned,
# checksum-verified sources in engine/versions.env. Nothing is taken from
# Homebrew or /usr/local, so the result depends only on macOS system
# libraries and can be shipped inside OrbTorrent.app.
#
# Usage:
#   engine/build.sh                      # host architecture
#   ARCHS="arm64 x86_64" engine/build.sh # universal binary (release builds)
#
# Output: engine/dist/qbittorrent-nox and engine/dist/VERSIONS.txt

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
source "$ROOT/versions.env"

ARCHS="${ARCHS:-$(uname -m)}"
MACOS_MIN="${MACOS_MIN:-26.0}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

ARCH_KEY="${ARCHS// /-}"
CACHE="$ROOT/.cache"
WORK="$ROOT/.build/$ARCH_KEY"
SRC="$WORK/src"
PREFIX="$WORK/prefix"
LOGS="$WORK/logs"
DIST="$ROOT/dist"
CMAKE_ARCHS="${ARCHS// /;}"

mkdir -p "$CACHE" "$SRC" "$PREFIX" "$LOGS" "$DIST"

# --- toolchain isolation -----------------------------------------------------
# Only cmake and ninja are borrowed from the host; everything else resolves to
# the macOS SDK or to $PREFIX. pkg-config is deliberately not on PATH.
TOOLS="$WORK/tools"
mkdir -p "$TOOLS"
for tool in cmake ninja; do
  real="$(command -v "$tool" || true)"
  [[ -n "$real" ]] || { echo "error: $tool is required (brew install $tool)" >&2; exit 1; }
  ln -sf "$real" "$TOOLS/$tool"
done
export PATH="$TOOLS:/usr/bin:/bin:/usr/sbin:/sbin"
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR CPATH LIBRARY_PATH CMAKE_PREFIX_PATH
export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

COMMON_CMAKE=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_ARCHITECTURES="$CMAKE_ARCHS"
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN"
  -DCMAKE_OSX_SYSROOT="$SDKROOT"
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
  -DCMAKE_PREFIX_PATH="$PREFIX"
  -DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local;/opt/local"
  -DCMAKE_FIND_FRAMEWORK=LAST
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DBUILD_SHARED_LIBS=OFF
)

# --- helpers -------------------------------------------------------------------
log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

run() { # run <step> <command...>: log to file, show the tail on failure
  local step="$1"; shift
  if ! "$@" >>"$LOGS/$step.log" 2>&1; then
    echo "error: step '$step' failed; last lines of $LOGS/$step.log:" >&2
    tail -40 "$LOGS/$step.log" >&2
    exit 1
  fi
}

done_step() { [[ -f "$WORK/.done-$1" ]]; }
mark_done() { touch "$WORK/.done-$1"; }

fetch() { # fetch <url> <sha256> -> path of verified archive
  local url="$1" sha="$2" file="$CACHE/$(basename "${1%%\?*}")"
  if [[ ! -s "$file" ]]; then
    curl -fL --retry 3 --silent --show-error -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  local got
  got="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  if [[ "$got" != "$sha" ]]; then
    echo "error: checksum mismatch for $(basename "$file")" >&2
    echo "  expected $sha" >&2
    echo "  got      $got" >&2
    exit 1
  fi
  echo "$file"
}

unpack() { # unpack <archive> <dest-dir-name> [patch-set]: extract, then apply engine/patches/<patch-set>
  local archive="$1" dest="$SRC/$2" patches="$ROOT/patches/${3:-}"
  rm -rf "$dest" && mkdir -p "$dest"
  tar -xf "$archive" -C "$dest" --strip-components=1
  if [[ -n "${3:-}" && -d "$patches" ]]; then
    local patch
    for patch in "$patches"/*.patch; do
      [[ -e "$patch" ]] || continue
      patch -d "$dest" -p1 --forward --quiet <"$patch" >&2
    done
  fi
  echo "$dest"
}

# --- OpenSSL (per architecture, then merged with lipo) ---------------------
build_openssl() {
  done_step openssl && return
  log "OpenSSL $OPENSSL_VERSION ($ARCHS)"
  local archive; archive="$(fetch "$OPENSSL_URL" "$OPENSSL_SHA256")"
  local libs=()
  for arch in $ARCHS; do
    local src; src="$(unpack "$archive" "openssl-$arch")"
    local target=darwin64-arm64-cc
    [[ "$arch" == x86_64 ]] && target=darwin64-x86_64-cc
    (
      cd "$src"
      run openssl ./Configure "$target" no-shared no-tests no-docs no-module \
        --prefix="$WORK/openssl-$arch" --libdir=lib --openssldir=/etc/ssl \
        "-mmacosx-version-min=$MACOS_MIN"
      run openssl make -j"$JOBS" build_libs
      run openssl make install_dev
    )
    libs+=("$arch")
  done
  mkdir -p "$PREFIX/lib" "$PREFIX/include"
  local first="${libs[0]}"
  rm -rf "$PREFIX/include/openssl"
  cp -R "$WORK/openssl-$first/include/openssl" "$PREFIX/include/"
  for lib in libssl.a libcrypto.a; do
    local inputs=()
    for arch in "${libs[@]}"; do inputs+=("$WORK/openssl-$arch/lib/$lib"); done
    lipo -create "${inputs[@]}" -output "$PREFIX/lib/$lib"
  done
  mkdir -p "$PREFIX/lib/pkgconfig"
  mark_done openssl
}

# --- Boost (headers + the Boost.System stub libtorrent 1.2 links) ----------
build_boost() {
  done_step boost && return
  log "Boost $BOOST_VERSION"
  local archive src; archive="$(fetch "$BOOST_URL" "$BOOST_SHA256")"
  src="$(unpack "$archive" boost)"
  local arch_flags=""
  for arch in $ARCHS; do arch_flags+=" -arch $arch"; done
  (
    cd "$src"
    run boost ./bootstrap.sh --with-libraries=system --prefix="$PREFIX"
    run boost ./b2 -j"$JOBS" --prefix="$PREFIX" --with-system \
      toolset=clang link=static variant=release threading=multi \
      cxxflags="-std=c++20 -mmacosx-version-min=$MACOS_MIN$arch_flags" \
      linkflags="-mmacosx-version-min=$MACOS_MIN$arch_flags" install
  )
  mark_done boost
}

# --- Qt (static qtbase without GUI, plus the linguist tools qBittorrent needs)
build_qtbase() {
  done_step qtbase && return
  log "Qt $QT_VERSION qtbase (static, no GUI)"
  local archive src; archive="$(fetch "$QTBASE_URL" "$QTBASE_SHA256")"
  src="$(unpack "$archive" qtbase qtbase)"
  run qtbase cmake -S "$src" -B "$WORK/qtbase-build" "${COMMON_CMAKE[@]}" \
    -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DQT_BUILD_BENCHMARKS=OFF \
    -DFEATURE_gui=OFF -DFEATURE_widgets=OFF -DFEATURE_opengl=OFF \
    -DFEATURE_dbus=OFF -DFEATURE_icu=OFF -DFEATURE_glib=OFF \
    -DFEATURE_zstd=OFF -DFEATURE_brotli=OFF -DFEATURE_libproxy=OFF \
    -DFEATURE_gssapi=OFF -DFEATURE_macdeployqt=OFF \
    -DFEATURE_system_zlib=ON -DFEATURE_system_pcre2=OFF \
    -DFEATURE_system_doubleconversion=OFF -DFEATURE_system_libb2=OFF \
    -DFEATURE_openssl=ON -DFEATURE_openssl_linked=ON -DFEATURE_securetransport=OFF \
    -DOPENSSL_ROOT_DIR="$PREFIX" -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DFEATURE_sql=ON -DFEATURE_sql_sqlite=ON -DFEATURE_system_sqlite=OFF \
    -DFEATURE_sql_mysql=OFF -DFEATURE_sql_psql=OFF -DFEATURE_sql_odbc=OFF \
    -DFEATURE_sql_ibase=OFF -DFEATURE_sql_oci=OFF -DFEATURE_sql_db2=OFF \
    -DFEATURE_sql_mimer=OFF
  run qtbase cmake --build "$WORK/qtbase-build" --parallel "$JOBS"
  run qtbase cmake --install "$WORK/qtbase-build"
  mark_done qtbase
}

build_qttools() {
  done_step qttools && return
  log "Qt $QT_VERSION linguist tools"
  local archive src; archive="$(fetch "$QTTOOLS_URL" "$QTTOOLS_SHA256")"
  src="$(unpack "$archive" qttools qttools)"
  run qttools "$PREFIX/bin/qt-cmake" -S "$src" -B "$WORK/qttools-build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local;/opt/local" \
    -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
    -DFEATURE_linguist=ON -DFEATURE_assistant=OFF -DFEATURE_designer=OFF \
    -DFEATURE_pixeltool=OFF -DFEATURE_qdoc=OFF -DFEATURE_clang=OFF \
    -DFEATURE_clangcpp=OFF -DFEATURE_qtdiag=OFF -DFEATURE_qtplugininfo=OFF \
    -DFEATURE_distancefieldgenerator=OFF -DFEATURE_qdbus=OFF -DFEATURE_qev=OFF \
    -DFEATURE_qtattributionsscanner=OFF -DFEATURE_kmap2qmap=OFF \
    -DFEATURE_qtdbus=OFF
  run qttools cmake --build "$WORK/qttools-build" --parallel "$JOBS"
  run qttools cmake --install "$WORK/qttools-build"
  mark_done qttools
}

# --- libtorrent ----------------------------------------------------------------
build_libtorrent() {
  done_step libtorrent && return
  log "libtorrent $LIBTORRENT_VERSION"
  local archive src; archive="$(fetch "$LIBTORRENT_URL" "$LIBTORRENT_SHA256")"
  src="$(unpack "$archive" libtorrent libtorrent)"
  run libtorrent cmake -S "$src" -B "$WORK/libtorrent-build" "${COMMON_CMAKE[@]}" \
    -DCMAKE_CXX_STANDARD=20 \
    -Ddeprecated-functions=OFF \
    -DBOOST_ROOT="$PREFIX" -DBoost_NO_SYSTEM_PATHS=ON -DBoost_USE_STATIC_LIBS=ON \
    -DOPENSSL_ROOT_DIR="$PREFIX" -DOPENSSL_USE_STATIC_LIBS=TRUE
  run libtorrent cmake --build "$WORK/libtorrent-build" --parallel "$JOBS"
  run libtorrent cmake --install "$WORK/libtorrent-build"
  mark_done libtorrent
}

# --- qBittorrent (headless) -------------------------------------------------------
build_qbittorrent() {
  done_step qbittorrent && return
  log "qBittorrent $QBITTORRENT_VERSION (qbittorrent-nox)"
  local archive src; archive="$(fetch "$QBITTORRENT_URL" "$QBITTORRENT_SHA256")"
  src="$(unpack "$archive" qbittorrent qbittorrent)"
  run qbittorrent cmake -S "$src" -B "$WORK/qbittorrent-build" "${COMMON_CMAKE[@]}" \
    -DGUI=OFF -DWEBUI=ON -DSTACKTRACE=OFF -DTESTING=OFF \
    -DBOOST_ROOT="$PREFIX" -DBoost_NO_SYSTEM_PATHS=ON \
    -DOPENSSL_ROOT_DIR="$PREFIX" -DOPENSSL_USE_STATIC_LIBS=TRUE
  run qbittorrent cmake --build "$WORK/qbittorrent-build" --parallel "$JOBS"
  mark_done qbittorrent
}

# --- package -------------------------------------------------------------------------
package() {
  log "Packaging"
  local bin="$WORK/qbittorrent-build/qbittorrent-nox"
  [[ -x "$bin" ]] || bin="$(find "$WORK/qbittorrent-build" -type f -name qbittorrent-nox -perm -u+x | head -1)"
  [[ -x "$bin" ]] || { echo "error: qbittorrent-nox was not produced" >&2; exit 1; }

  cp "$bin" "$DIST/qbittorrent-nox"
  strip -S -x "$DIST/qbittorrent-nox"

  # The binary must depend on nothing outside macOS itself.
  local foreign
  # (Universal binaries print one "path (architecture …):" header per slice.)
  foreign="$(otool -L "$DIST/qbittorrent-nox" | grep -v ':$' | awk '{print $1}' \
    | grep -vE '^(/usr/lib/|/System/Library/)' || true)"
  if [[ -n "$foreign" ]]; then
    echo "error: qbittorrent-nox links non-system libraries:" >&2
    echo "$foreign" >&2
    exit 1
  fi

  # Ship the license of every component compiled into the binary.
  local licenses="$DIST/licenses"
  rm -rf "$licenses" && mkdir -p "$licenses"
  cp "$SRC/qbittorrent/COPYING" "$licenses/qBittorrent-COPYING.txt"
  cp "$SRC/libtorrent/LICENSE" "$licenses/libtorrent-LICENSE.txt"
  cp "$SRC/boost/LICENSE_1_0.txt" "$licenses/Boost-LICENSE_1_0.txt"
  local first_arch="${ARCHS%% *}"
  cp "$SRC/openssl-$first_arch/LICENSE.txt" "$licenses/OpenSSL-LICENSE.txt"
  mkdir -p "$licenses/Qt"
  cp "$SRC/qtbase/LICENSES/"*.txt "$licenses/Qt/"

  cat >"$DIST/VERSIONS.txt" <<EOF
qBittorrent $QBITTORRENT_VERSION (qbittorrent-nox)
libtorrent-rasterbar $LIBTORRENT_VERSION
Qt $QT_VERSION (qtbase, static)
OpenSSL $OPENSSL_VERSION (static)
Boost $BOOST_VERSION
Architectures: $ARCHS
Minimum macOS: $MACOS_MIN
EOF
  echo "Built $DIST/qbittorrent-nox"
  lipo -info "$DIST/qbittorrent-nox"
  du -h "$DIST/qbittorrent-nox" | cut -f1
}

build_openssl
build_boost
build_qtbase
build_qttools
build_libtorrent
build_qbittorrent
package
