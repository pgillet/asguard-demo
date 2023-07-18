#!/bin/sh

set -eux

VAULT_ADDR=${VAULT_ADDR}
VAULT_KEY_NAME=${VAULT_KEY_NAME}
VAULT_ROLE=${VAULT_ROLE}

WORK_DIR=/dist
CACHE_DIR=${CACHE_DIR:-/cache}

BOOTSTRAP_DIR=${BOOTSTRAP_DIR:-/asguard}
cd ${BOOTSTRAP_DIR}
export PATH=${BOOTSTRAP_DIR}:${PATH}

# Get the JWT token for the GCE instance that runs this container
INST_ID_TOKEN=$(wget \
  --header "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=vault/${VAULT_ROLE}&format=full" -qO -)

AUTH_PAYLOAD="{\"role\": \"${VAULT_ROLE}\", \"jwt\": \"${INST_ID_TOKEN}\"}"

# GCE login
CLIENT_TOKEN=$(wget \
    --post-data "${AUTH_PAYLOAD}" \
    ${VAULT_ADDR}/v1/auth/gcp/login -O - | \
    jq -r '.auth.client_token')

PAYLOAD="{\"ciphertext\": \"$(cat ${WORK_DIR}/passphrase.enc)\"}"

# Decrypt the application
wget \
    --header "X-Vault-Token: ${CLIENT_TOKEN}" \
    --post-data "${PAYLOAD}" \
    ${VAULT_ADDR}/v1/transit/decrypt/${VAULT_KEY_NAME} -O - | jq -r '.data.plaintext' | openssl aes-256-cbc -d -salt -in ${WORK_DIR}/app.enc -out ${CACHE_DIR}/app.tar.gz -pass stdin

# Unpack
tar xvf ${CACHE_DIR}/app.tar.gz -C ${CACHE_DIR}

# Execute arg command
cd ${CACHE_DIR}
/bin/sh -c "$1"
