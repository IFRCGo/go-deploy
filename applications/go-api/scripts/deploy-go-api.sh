#!/bin/bash

set -x
set -e

# if environment is production, then we get the credentials for the production cluster.
# else we get the credentials for the staging cluster
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
if [[ "${ENVIRONMENT}" == "production" ]]; then
    echo "Getting credentials for production cluster..."
    az aks get-credentials --resource-group ifrcpgo002rg --name ifrcpgo-cluster
else
    echo "Getting credentials for staging cluster..."
    az aks get-credentials --resource-group ifrctgo002rg --name ifrctgo-cluster
fi

helm upgrade --dry-run --install --wait \
    -f ../helm/ifrcgo-helm/values.yaml \
    -f ../helm/ifrcgo-helm/values-${ENVIRONMENT}.yaml \
    ifrcgo-helm \
    ../helm/ifrcgo-helm \
    --set env.DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY} \
    --set env.DJANGO_DB_USER=${DJANGO_DB_USER} \
    --set env.DJANGO_DB_PASS=${DJANGO_DB_PASS} \
    --set env.DJANGO_DB_HOST=${DJANGO_DB_HOST} \
    --set env.DJANGO_DB_PORT=${DJANGO_DB_PORT} \
    --set env.AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT} \
    --set env.AZURE_STORAGE_KEY=${AZURE_STORAGE_KEY} \
    --set env.EMAIL_API_ENDPOINT=${EMAIL_API_ENDPOINT} \
    --set env.EMAIL_HOST=${EMAIL_HOST} \
    --set env.EMAIL_PORT=${EMAIL_PORT} \
    --set env.EMAIL_USER=${EMAIL_USER} \
    --set env.EMAIL_PASS=${EMAIL_PASS} \
    --set env.TEST_EMAILS=${TEST_EMAILS} \
    --set env.AWS_TRANSLATE_ACCESS_KEY=${AWS_TRANSLATE_ACCESS_KEY} \
    --set env.AWS_TRANSLATE_SECRET_KEY=${AWS_TRANSLATE_SECRET_KEY} \
    --set env.AWS_TRANSLATE_REGION=${AWS_TRANSLATE_REGION} \
    --set env.MOLNIX_API_BASE=${MOLNIX_API_BASE} \
    --set env.MOLNIX_USERNAME=${MOLNIX_USERNAME} \
    --set env.MOLNIX_PASSWORD=${MOLNIX_PASSWORD} \
    --set env.ERP_API_ENDPOINT=${ERP_API_ENDPOINT} \
    --set env.ERP_API_SUBSCRIPTION_KEY=${ERP_API_SUBSCRIPTION_KEY} \
    --set env.FDRS_APIKEY=${FDRS_APIKEY} \
    --set env.FDRS_CREDENTIAL=${FDRS_CREDENTIAL} \
    --set env.HPC_CREDENTIAL=${HPC_CREDENTIAL} \
    --set env.APPLICATION_INSIGHTS_INSTRUMENTATION_KEY=${APPLICATION_INSIGHTS_INSTRUMENTATION_KEY} \
    --set env.GO_FTPHOST=${GO_FTPHOST} \
    --set env.GO_FTPUSER=${GO_FTPUSER} \
    --set env.GO_FTPPASS=${GO_FTPPASS} \
    --set env.GO_DBPASS=${GO_DBPASS} \
    --set env.APPEALS_USER=${APPEALS_USER} \
    --set env.APPEALS_PASS=${APPEALS_PASS} \
    --set env.IFRC_TRANSLATION_GET_API_KEY=${IFRC_TRANSLATION_GET_API_KEY} \
    --set env.IFRC_TRANSLATION_HEADER_API_KEY=${IFRC_TRANSLATION_HEADER_API_KEY} \
    --set secrets.API_TLS_CRT=${API_TLS_CRT} \
    --set secrets.API_TLS_KEY=${API_TLS_KEY} \
    --set secrets.API_ADDITIONAL_DOMAIN_TLS_CRT=${API_ADDITIONAL_DOMAIN_TLS_CRT} \
    --set secrets.API_ADDITIONAL_DOMAIN_TLS_KEY=${API_ADDITIONAL_DOMAIN_TLS_KEY}
