VENVMAN_PYTHON_DIR=${VENVMAN_ROOT_DIR}/python/cpython
VENVMAN_PYTHON_VERSIONS_DIR=${VENVMAN_ROOT_DIR}/python/versions
CPYTHON_URL="https://github.com/python/cpython"


_venvman_get_python_bin_path() {
    VERSION=$1

    VERSION_PARTS=$(echo "${VERSION}" | tr '.' ' ')
    VERSION_MAJOR=$(echo "$VERSION_PARTS" | awk "{print \$1}")
    VERSION_MINOR=$(echo "$VERSION_PARTS" | awk "{print \$2}")
    VERSION_PATCH=$(echo "$VERSION_PARTS" | awk "{print \$3}")


    BINARY_PATH=$(which python${VERSION}) || BINARY_PATH=""
    if [ -n "$BINARY_PATH" ]; then
        echo $BINARY_PATH
        return 0
    fi
        
    if [ ! -d "${VENVMAN_PYTHON_VERSIONS_DIR}/${VERSION}" ]; then
        return 1
    fi

    BINARY_PATHS=$(\
        find ${VENVMAN_PYTHON_VERSIONS_DIR}/${VERSION} \
            -type f \
            -executable \
            -name "python${VERSION_MAJOR}.${VERSION_MINOR}" \
    )

    BINARY_PATH_FOUND=""
    for BINARY_PATH in $BINARY_PATHS; do
        BINARY_PATH_FOUND=$BINARY_PATH
        break
    done
    
    if [ -n "$BINARY_PATH_FOUND" ]; then
        echo $BINARY_PATH_FOUND
        return 0
    else
        return 1
    fi
}


_venvman_build_python_version_from_source() {
    VERSION="$1"

    VERSION_PARTS=$(echo "${VERSION}" | tr '.' ' ')
    VERSION_MAJOR=$(echo "$VERSION_PARTS" | awk "{print \$1}")
    VERSION_MINOR=$(echo "$VERSION_PARTS" | awk "{print \$2}")
    VERSION_PATCH=$(echo "$VERSION_PARTS" | awk "{print \$3}")
    
    if BIN_PATH=$(_venvman_get_python_bin_path $VERSION); then
        echo "python${VERSION} already exists at ${BIN_PATH}"
        return 0
    fi
    
    if [ ! -d "$VENVMAN_PYTHON_DIR" ]; then
        echo "The repo "$CPYTHON_URL" was not found at ${VENVMAN_PYTHON_DIR}."
        echo "To continue, it must be cloned to that location."
        printf "Would you like to clone the repo and continue now? [Y/n]: "
        read -r response
        case "$response" in
            Y|y)
                mkdir -p ${VENVMAN_PYTHON_DIR}
                git clone ${CPYTHON_URL} ${VENVMAN_PYTHON_DIR}
                mkdir -p ${VENVMAN_PYTHON_VERSIONS_DIR}
                ;;
            *)
                echo "Exiting. The ${CPYTHON_URL} needs to be cloned to continue."
                return 0
                ;;
        esac
    fi

    MY_PWD="$(pwd)"
    cd $VENVMAN_PYTHON_DIR || return 1
    git checkout main > /dev/null 2&>1
    git reset --hard origin/main > /dev/null 2&>1
    git pull > /dev/null 2&>1
    git fetch --all > /dev/null 2&>1

    TAGS=$(git tag | grep $VERSION)
    if [ -z $TAGS ]; then
        echo "$VERSION not found on ${CPYTHON_URL}" >&2
        echo "Please see ${CPYTHON_URL} for available versions." >&2
        cd $MY_PWD
        return 1
    else
        for TAG in $TAGS; do
            TAG=$TAG
            break
        done
    fi
    
    echo "$VERSION is available with tag=${TAG} at ${CPYTHON_URL}."
    echo "We can continue and configure the install now."
    echo "The resulting installation will be located at ${VENVMAN_PYTHON_VERSIONS_DIR}/${VERSION}"
    echo "The following is what will be ran:"
    echo
    echo "cd ${VENVMAN_PYTHON_DIR}"
    echo "git checkout "$TAG""
    echo "git reset --hard "$TAG""
    echo "make distclean"
    echo "./configure --prefix="${VENVMAN_PYTHON_VERSIONS_DIR}/${VERSION}""
    echo "make"
    echo "make install"
    echo
    printf "Would you like to continue with the install now? [Y/n]: "
    read -r response
    case "$response" in
        Y|y)
            ;;
        *)
            echo "Exiting the install."
            cd $MY_PWD && return 1
            ;;
    esac
    
    git checkout "$TAG" || return 1
    git reset --hard "$TAG"

    make distclean || return 1
    ./configure --prefix="${VENVMAN_PYTHON_VERSIONS_DIR}/${VERSION}" || return 1
    if [ $(command -v nproc &> /dev/null) ]; then
        make -j$(nproc) || cd $MY_PWD && return 1
    else
        make || cd $MY_PWD return 1
    fi
    make install

    if [ "$?" -gt 0 ]; then
        echo "make install fail" >&2
        return 1
    fi

    if ! _venvman_get_python_bin_path $VERSION > /dev/null; then
        echo "Install fail. Binary not found."
        return 1
    fi
}
