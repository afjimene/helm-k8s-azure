#!/usr/bin/env bash
set -e

REPO_USERNAME="<yourRepoUsername>"
REPO_PASSWORD="<yourRepoPassword>"
CX_VERSION="6.3.0"
TAG_WEB_SDK="1.15.2"
TAG_UNIVERSAL_COLLECTION="3.3.13"

AUTH_URL="http://identity.docker.internal"
PROV_URL="http://kubernetes.docker.internal/api/provisioning"
IDENTITY_ARGS="--identity-client-id=bb-tooling-client --identity-realm=backbase --identity-grant-type=password --identity-scope=openid"
TRIES=30
AUTH_USER="admin"
AUTH_PWD="admin"

BOM_FILE="cx-bom-${CX_VERSION}.pom"

echo "Getting the ${CX_VERSION} cx bom.."
curl -s -u "${REPO_USERNAME}":"${REPO_PASSWORD}" "https://repo.backbase.com/backbase-6-release/com/backbase/cxp/cx-bom/${CX_VERSION}/${BOM_FILE}" -o "${BOM_FILE}"

echo "Extracting statics version.."
TAG_IMPORT_TOOL=$(cat "${BOM_FILE}" | grep -oP "<cx6-import-tool.version>(.*)</cx6-import-tool.version>" | cut -d ">" -f 2 | cut -d "<" -f 1)
TAG_CXP_MANAGER=$(cat "${BOM_FILE}" | grep -oP "<experience-manager.version>(.*)</experience-manager.version>" | cut -d ">" -f 2 | cut -d "<" -f 1)
TAG_EDITORIAL_COLLECTION=$(cat "${BOM_FILE}" | grep -oP "<editorial-collection.version>(.*)</editorial-collection.version>" | cut -d ">" -f 2 | cut -d "<" -f 1)

echo "Extracted the following tags:"
echo "TAG_IMPORT_TOOL: ${TAG_IMPORT_TOOL}"
echo "TAG_CXP_MANAGER: ${TAG_CXP_MANAGER}"
echo "TAG_EDITORIAL_COLLECTION: ${TAG_EDITORIAL_COLLECTION}"
echo "TAG_UNIVERSAL_COLLECTION: ${TAG_UNIVERSAL_COLLECTION}"
echo "TAG_WEB_SDK: ${TAG_WEB_SDK}"


echo "Download statics.."
curl -u "${REPO_USERNAME}":"${REPO_PASSWORD}" -n -L -O "https://repo.backbase.com/backbase-6-release/com/backbase/tools/cx/cx6-import-tool-cli/${TAG_IMPORT_TOOL}/cx6-import-tool-cli-${TAG_IMPORT_TOOL}.jar"
curl -u "${REPO_USERNAME}":"${REPO_PASSWORD}" -n -L -O "https://repo.backbase.com/backbase-6-release/com/backbase/cxp/experience-manager/${TAG_CXP_MANAGER}/experience-manager-${TAG_CXP_MANAGER}.zip"
curl -u "${REPO_USERNAME}":"${REPO_PASSWORD}" -n -L -O "https://repo.backbase.com/backbase-6-release/com/backbase/cxp/editorial-collection/${TAG_EDITORIAL_COLLECTION}/editorial-collection-${TAG_EDITORIAL_COLLECTION}.zip"
curl -u "${REPO_USERNAME}":"${REPO_PASSWORD}" -n -L -O "https://repo.backbase.com/expert-release-local/com/backbase/widget/collection/collection-universal/${TAG_UNIVERSAL_COLLECTION}/collection-universal-${TAG_UNIVERSAL_COLLECTION}.zip"
curl -u "${REPO_USERNAME}":"${REPO_PASSWORD}" -n -L -O "https://repo.backbase.com/expert-release-local/com/backbase/web-sdk/collection/collection-bb-web-sdk/${TAG_WEB_SDK}/collection-bb-web-sdk-${TAG_WEB_SDK}.zip"

function fn_check_health {
    local ENDPOINT=${1}
    local TRY_COUNTER=0
    local RESPONSE=

    echo; echo "Checking $ENDPOINT availability.."

    while ([ "$RESPONSE" != '200' ] && [ "$TRY_COUNTER" -lt "$TRIES" ])
    do
        echo "Ping $ENDPOINT .... try $TRY_COUNTER"
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 --connect-timeout 3 "$ENDPOINT")
        echo "$RESPONSE"
        let "TRY_COUNTER=TRY_COUNTER+1"

        if [ "$RESPONSE" != '200' ]; then
            sleep 3
        fi
    done

    if [ "$RESPONSE" != '200' ]; then
        echo "$ENDPOINT is not ready after $TRY_COUNTER tries"
        exit 1
    fi
}

function fn_provisioning() {
    max_retries=3
    artifact=$1
    pwd

    while [ $max_retries -gt 0 ]; do

        java -jar cx6-import-tool-cli-${TAG_IMPORT_TOOL}.jar \
            --fail-fast \
            --import ${artifact} \
            --username ${AUTH_USER} \
            --password ${AUTH_PWD} \
            --target-ctx ${PROV_URL} \
            --auth-url ${AUTH_URL} \
            --retry-max-attempts 200 \
            --retry-back-off-period 3000 \
            ${IDENTITY_ARGS}

        if [ $? -eq 0 ]; then
            break
        else
            max_retries=$((max_retries - 1))
            if [ $max_retries -eq 0 ]; then
                break
            fi
        fi
    done
}

echo "Checking Health.."
fn_check_health "http://kubernetes.docker.internal/api/provisioning/actuator/health"
fn_check_health "http://kubernetes.docker.internal/api/portal/actuator/health"
fn_check_health "http://kubernetes.docker.internal/api/contentservices/actuator/health"
fn_check_health "http://identity.docker.internal/auth/realms/backbase/.well-known/openid-configuration"

echo "Import Statics.."
fn_provisioning editorial-collection-${TAG_EDITORIAL_COLLECTION}.zip
fn_provisioning experience-manager-${TAG_CXP_MANAGER}.zip
fn_provisioning collection-universal-${TAG_UNIVERSAL_COLLECTION}.zip
fn_provisioning collection-bb-web-sdk-${TAG_WEB_SDK}.zip
