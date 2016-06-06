#!/usr/bin/env bash

function php_lfs_download_and_extact() {
    echo "Preparing PHP:";

    # Resolve some information
    local LFS_FILE="${OPENSHIFT_PHP_DIR}/usr/php-${PHP_VERSION}.tar.gz"
    local DOWNLOAD_FILE="${OPENSHIFT_PHP_DIR}/usr/php-${PHP_VERSION}_actual.tar.gz"
    local EXTRACT_DIR="${OPENSHIFT_PHP_DIR}/usr/"

    # Check mimetype (LFS maybe installed)
    local LFS_FILE_MIMETYPE=$(file -b --mime-type "${LFS_FILE}")
    if [ "${LFS_FILE_MIMETYPE}" = "application/gzip" ]; then
        unpack "${LFS_FILE}" "${EXTRACT_DIR}"
        return 0
    fi
    if [ "${LFS_FILE_MIMETYPE}" != "text/plain" ]; then
        echo "Unsupported mimetype found for file ${LFS_FILE}"
    fi

    # Fetch the LFS OID
    echo "- Fetching package OID"
    local LFS_OID_REGEX='\soid (\w+):(\w+)'
    if [[ ! $(cat "${LFS_FILE}") =~ ${LFS_OID_REGEX} ]]; then
        echo "Unable to locale oid in ${LFS_FILE}"
        exit 1
    fi
    local LFS_OID="${BASH_REMATCH[2]}"
    local LFS_METADATA_URL="${LFS_ENDPOINT}/objects/${LFS_OID}"

    # Download file if needed
    if [ ! -f "${DOWNLOAD_FILE}" ]; then
        # Fetch download link
        echo "- Fetching download URL"
        local LFS_JSON=$(
          wget \
            --progress=dot \
            --output-document=- \
            --header='Accept: application/vnd.git-lfs+json' \
            --header='Content-Type: application/vnd.git-lfs+json' \
            "${LFS_METADATA_URL}"
        );
        if [ $? -ne 0 ]; then
            echo "Failed to download ${LFS_FILE} metadata from ${LFS_METADATA_URL}"
            exit 1
        fi

        local DOWNLOAD_URL=$(echo "${LFS_JSON}" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["_links"]["download"]["href"]')
        if [ $? -ne 0 ]; then
            echo "Failed to parse metadata from ${LFS_METADATA_URL}"
            exit 1
        fi

        # Download the file
        echo "- Downloading package"
        wget --progress=dot --output-document="${DOWNLOAD_FILE}" "${DOWNLOAD_URL}"
        if [ $? -ne 0 ]; then
            rm -f  "${DOWNLOAD_FILE}"
            echo "Failed to download ${LFS_FILE} from ${DOWNLOAD_URL}"
        fi
    else
        echo "- Skipping download package exists"
    fi

    unpack "${DOWNLOAD_FILE}" "${EXTRACT_DIR}"

    return 0
}

function unpack() {
    if [ -z "${1}" ] || [ -z "${2}" ]; then
        echo "extract: expected two arguments"
        exit -1
    fi

    set +e

    echo "- Extracting"
    tar xfz "${1}" --directory="${2}"
    if [ $? -ne 0 ]; then
        gunzip -c "${1}" | tar xfz - --directory="${2}"

        if [ $? -ne 0 ]; then
            echo "Failed to extract data ${1} into ${2}. Please remove the file manually any try again."
            exit 1
        fi
    fi

    rm -f "${1}"

    set -e

    return 0
}
