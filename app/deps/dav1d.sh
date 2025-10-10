#!/usr/bin/env bash
set -ex
DEPS_DIR=$(dirname ${BASH_SOURCE[0]})
cd "$DEPS_DIR"
. common
process_args "$@"

VERSION=1.5.0
# Prefer official release tarball which has a stable checksum
FILENAME=dav1d-$VERSION.tar.xz
PROJECT_DIR=dav1d-$VERSION

cd "$SOURCES_DIR"

if [[ -d "$PROJECT_DIR" ]]
then
    echo "$PWD/$PROJECT_DIR" found
else
    # Try to download from official release mirrors with detached sha256 file
    set +e
    ok=0
    for base in \
        "https://downloads.videolan.org/pub/videolan/dav1d/$VERSION" \
        "https://code.videolan.org/videolan/dav1d/-/releases/$VERSION/downloads" \
    ; do
        echo "Attempting download from $base"
        rm -f "$FILENAME" "$FILENAME.sha256"
        if wget -q "$base/$FILENAME" -O "$FILENAME" && wget -q "$base/$FILENAME.sha256" -O "$FILENAME.sha256"; then
            if command -v sha256sum >/dev/null 2>&1; then
                sha256sum -c "$FILENAME.sha256" && ok=1 || ok=0
            else
                shasum -a256 -c "$FILENAME.sha256" && ok=1 || ok=0
            fi
        fi
        [[ $ok -eq 1 ]] && break
    done
    set -e
    if [[ $ok -ne 1 ]]; then
        echo "Failed to download and verify $FILENAME" >&2
        exit 1
    fi
    tar xf "$FILENAME"  # First level directory is "$PROJECT_DIR"
fi

mkdir -p "$BUILD_DIR/$PROJECT_DIR"
cd "$BUILD_DIR/$PROJECT_DIR"

if [[ -d "$DIRNAME" ]]
then
    echo "'$PWD/$DIRNAME' already exists, not reconfigured"
    cd "$DIRNAME"
else
    mkdir "$DIRNAME"
    cd "$DIRNAME"

    conf=(
        --prefix="$INSTALL_DIR/$DIRNAME"
        --libdir=lib
        -Denable_tests=false
        -Denable_tools=false
        # Always build dav1d statically
        --default-library=static
    )

    if [[ "$BUILD_TYPE" == cross ]]
    then
        case "$HOST" in
            win32)
                conf+=(
                    --cross-file="$SOURCES_DIR/$PROJECT_DIR/package/crossfiles/i686-w64-mingw32.meson"
                )
                ;;

            win64)
                conf+=(
                    --cross-file="$SOURCES_DIR/$PROJECT_DIR/package/crossfiles/x86_64-w64-mingw32.meson"
                )
                ;;

            *)
                echo "Unsupported host: $HOST" >&2
                exit 1
        esac
    fi

    meson setup . "$SOURCES_DIR/$PROJECT_DIR" "${conf[@]}"
fi

ninja
ninja install
