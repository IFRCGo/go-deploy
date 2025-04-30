#!/bin/bash

set -x
set -e

az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

cd base-infrastructure/terraform

# Replace the backend state key in the main.tf to pick the right deployment environment
sed -i "s/ENVIRONMENT_TO_REPLACE/$TF_VAR_environment/g" main.tf

terraform init
terraform plan
# terraform apply -auto-approve
