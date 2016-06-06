#!/bin/bash

CONFIGURATION_DIRTY=0

# Check that the configuration files are valid and have not change.
# Returns 0 if no changes have been detected else 1
function config() {
    CONFIGURATION_DIRTY=0
    echo "Checking configuration"

    # A map of files that can be configured in the repo.
    declare -A CONF_FILES
    local CONF_FILES=( ['cli/php.ini.erb']='php.ini' ['fpm/php.ini.erb']='php-fpm.ini' ['fpm/php-fpm.conf.erb']='php-fpm.conf' )

    # Install config files
    for file in "${!CONF_FILES[@]}"; do
        local CONF_TARGET_FILE=${CONF_FILES["${file}"]}
        local CONF_FILE=${OPENSHIFT_REPO_DIR}/.openshift/${file}
        local TARGET_FILE=${OPENSHIFT_PHP_DIR}/conf/${CONF_TARGET_FILE}

        # Try to use the current OPENSHIFT_DEPLOYMENTS_DIR
        if [ ! -f "${CONF_FILE}" ]; then
            CONF_FILE=${OPENSHIFT_DEPLOYMENTS_DIR}/current/repo/.openshift/${file}
        fi

        # If no custom config is used use the default
        if [ ! -f "${CONF_FILE}" ]; then
            CONF_FILE=${OPENSHIFT_PHP_DIR}/conf/${CONF_TARGET_FILE}.erb
        fi

        if [ ! -f "${TARGET_FILE}" ] || [ "`oo-erb ${CONF_FILE} | md5sum | awk '{print $1}'`" != "`md5sum ${TARGET_FILE} | awk '{print $1}'`" ]; then
            echo "- ${CONF_TARGET_FILE}: ${CONF_FILE}"
            oo-erb ${CONF_FILE} > ${TARGET_FILE}
            CONFIGURATION_DIRTY=1
        else
            echo "- ${CONF_TARGET_FILE}: No change"
        fi
    done

    return 0
}
