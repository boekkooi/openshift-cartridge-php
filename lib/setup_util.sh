#!/usr/bin/env bash

function php_download_and_unpack() {
    echo "Preparing PHP:";

    local EXTRACT_DIR="${OPENSHIFT_PHP_DIR}/usr/"
    local FILENAME="php-${PHP_VERSION}.tar.gz"

    local TARGET_FILE="${OPENSHIFT_PHP_DIR}/usr/${FILENAME}"
    local TARGET_FILE_MIMETYPE=$(file -b --mime-type "${TARGET_FILE}")

    local LFS_FILE="${OPENSHIFT_PHP_DIR}/usr/${FILENAME}.lfs"

    # In case the archive exist just unpack
    if [ "${TARGET_FILE_MIMETYPE}" = "application/gzip" ]; then
        unpack "${TARGET_FILE}" "${EXTRACT_DIR}"
        return $?
    fi

    # Move the file if it is a LFS file
    if [ "${TARGET_FILE_MIMETYPE}" = "text/plain" ]; then
        mv "${TARGET_FILE}" "${LFS_FILE}"
    fi

    # First check if any of the download servers has the file
    for ARCHIVE_SERVER in "${ARCHIVE_SERVERS[@]}"; do
        local rc=0
        php_archive_download "${ARCHIVE_SERVER}/${FILENAME}" "${TARGET_FILE}" || rc=$?
        if [ $rc -eq 0 ]; then
            unpack "${TARGET_FILE}" "${EXTRACT_DIR}"
            return $?
        fi
    done

    # Fallback to use github LFS
    php_lfs_download "${LFS_FILE}" "${TARGET_FILE}"
    unpack "${TARGET_FILE}" "${EXTRACT_DIR}"
    return $?
}

function php_archive_download() {
    if [ -z "${1}" ] || [ -z "${2}" ]; then
        echo "php_archive_download: expected two arguments"
        exit -1
    fi

    # Resolve some information
    local DOWNLOAD_URL="${1}"
    local DOWNLOAD_FILE="${2}"

    # Download the file
    echo "- Downloading package from ${DOWNLOAD_URL}"

    local rc=0
    wget --progress=dot --output-document="${DOWNLOAD_FILE}" "${DOWNLOAD_URL}" || rc=$?
    if [ ${rc} -ne 0 ]; then
        rm -f  "${DOWNLOAD_FILE}"
        echo "Failed to download ${DOWNLOAD_FILE} from ${DOWNLOAD_URL}"
        return 1
    fi

    return 0
}

function php_lfs_download() {
    if [ -z "${1}" ] || [ -z "${2}" ]; then
        echo "php_lfs_download: expected two arguments"
        exit -1
    fi

    # Resolve some information
    local LFS_FILE="${1}"
    local DOWNLOAD_FILE="${2}"

    # Fetch the LFS OID
    echo "- Fetching package OID"
    local LFS_OID_REGEX='\soid (\w+):(\w+)'
    if [[ ! $(cat "${LFS_FILE}") =~ ${LFS_OID_REGEX} ]]; then
        echo "Unable to locale oid in ${LFS_FILE}"
        exit 1
    fi
    local LFS_OID="${BASH_REMATCH[2]}"
    local LFS_METADATA_URL="${LFS_ENDPOINT}/objects/${LFS_OID}"

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
        exit 1
    fi

    return 0
}

function unpack() {
    if [ -z "${1}" ] || [ -z "${2}" ]; then
        echo "unpack: expected two arguments"
        exit -1
    fi

    set +e

    echo "- Checking MD5"
    pushd "$( dirname "${1}" )"
    md5sum --check "${1}.md5"
    if [ $? -ne 0 ]; then
        echo "Invalid file signature!"
        exit 1
    fi
    popd

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
