#!/bin/bash

# Download Vault
VAULT_VERSION=1.2.3
curl https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip -o vault.zip
unzip vault.zip
chmod u+x vault

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_ROOT_TOKEN_ID=root

# Start Vault in dev mode
nohup vault server -dev -dev-listen-address=0.0.0.0:8200 -dev-root-token-id=${VAULT_ROOT_TOKEN_ID} &

# Wait until the Vault server has actually started
sleep 5

# Login to vault
echo $VAULT_ROOT_TOKEN_ID | vault login --no-print=true -

# Enable the Transit secrets engine which generates or encrypts data in-transit
vault secrets enable transit

# Create dev policy
vault policy write asguard-policy policy-dev.hcl

# Enable the Google Cloud auth method
vault auth enable gcp

# Give Vault server the JSON key of a service account with the required GCP permissions:
# roles/iam.serviceAccountKeyAdmin
# roles/compute.viewer

# These allow Vault to:
# - Verify that the service account associated with authenticating GCE instance exists
# - Get the corresponding public keys for verifying JWTs signed by service account private keys.
# - Verify authenticating GCE instances exist
# - Compare bound fields for GCE roles (zone/region, labels, or membership in given instance groups)

vault write auth/gcp/config credentials=@credentials.json

# The GCE instances that are authenticating against Vault must have the following role: roles/iam.serviceAccountTokenCreator

ROLE=asguard-gce-role

# Create role for GCE instance authentication
vault write auth/gcp/role/${ROLE} \
    type="gce" \
    policies="asguard-policy" \
    bound_projects="asguard" \
    bound_zones="europe-west1-b" \
    bound_labels="foo:bar,zip:zap,gruik:grok"


