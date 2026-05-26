#!/bin/bash
# ============================================================
# deploy-qa-client.sh
# ============================================================
# SBM QA Infrastructure Deployment Script
# For use by CLIENT on their Azure subscription
#
# PREREQUISITES (client must complete before running):
# 1. Azure CLI installed or use Azure Cloud Shell
# 2. Login to Azure: az login
# 3. Set correct subscription: az account set --subscription <your-subscription-id>
#
# CUSTOMISE THESE VALUES BEFORE RUNNING:
# - LOCATION: your preferred Azure region
# - REGION_SHORT: short code for your region
# - SQL_PASSWORD: strong password for SQL admin
# - Network prefixes: confirm they don't clash with your network
# ============================================================

set -e

# ── CLIENT CONFIGURABLE VALUES ────────────────────────────────
PROJECT="sbm"
ENV="qa"
LOCATION="centralindia"          # ← Change to your preferred Azure region
REGION_SHORT="cin"               # ← Change to match your region (e.g. eus, weu)
RESOURCE_GROUP="rg-${PROJECT}-${ENV}-${REGION_SHORT}"
DEPLOY_NAME="deploy-sbm-qa-$(date +%Y%m%d%H%M)"

# SQL Password — must contain uppercase, lowercase, number and special char
SQL_PASSWORD="SBMAdmin@QA2026"   # ← Change to your preferred strong password

# Network — confirm these ranges don't clash with your existing network
VNET_PREFIX="10.3.0.0/23"
APP_SUBNET="10.3.0.0/26"
DATA_SUBNET="10.3.0.64/26"
GW_SUBNET="10.3.0.128/26"

# ── DO NOT CHANGE BELOW THIS LINE ────────────────────────────
echo "============================================"
echo "  SBM QA Infrastructure Deployment"
echo "  Client Azure Subscription"
echo "  Resource Group : $RESOURCE_GROUP"
echo "  Location       : $LOCATION"
echo "  Region Short   : $REGION_SHORT"
echo "============================================"
echo ""

# Step 1: Clone repo
echo "Step 1: Cloning sbm-infra repo..."
cd ~
rm -rf sbm-infra-deploy
git clone https://github.com/Damcogrp/sbm-infra.git sbm-infra-deploy
cd sbm-infra-deploy
echo "✅ Repo cloned"

# Step 2: Install Bicep
echo "Step 2: Installing Bicep CLI..."
az bicep install
az bicep version
echo "✅ Bicep ready"

# Step 3: Create Resource Group
echo "Step 3: Creating resource group..."
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags \
    Project=$PROJECT \
    Environment=$ENV \
    ManagedBy=damco \
    Client=seaboard-marine \
    DeployedBy=client-cloudshell
echo "✅ Resource group: $RESOURCE_GROUP"

# Step 4: Deploy Infrastructure
echo "Step 4: Deploying QA infrastructure..."
echo "This will take approximately 10-15 minutes..."
echo ""

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters \
    environment=$ENV \
    projectName=$PROJECT \
    location=$LOCATION \
    regionShort=$REGION_SHORT \
    deployAppGateway=true \
    deployApim=true \
    deployNatGateway=true \
    deployScheduler=true \
    alertsEnabled=true \
    appServicePlanSku=P1v3 \
    appServicePlanTier=PremiumV3 \
    sqlAdminLogin=sbmadmin \
    sqlAdminPassword="$SQL_PASSWORD" \
    sqlDatabaseSku=S2 \
    redisSkuName=Standard \
    redisCacheFamily=C \
    redisCacheCapacity=2 \
    eventHubThroughputUnits=2 \
    eventHubPartitionCount=4 \
    eventHubMessageRetentionDays=7 \
    storageAccountSku=Standard_GRS \
    logAnalyticsRetentionDays=60 \
    vnetAddressPrefix=$VNET_PREFIX \
    appSubnetPrefix=$APP_SUBNET \
    dataSubnetPrefix=$DATA_SUBNET \
    gwSubnetPrefix=$GW_SUBNET \
    kvSecretExpiryDays=45 \
    kvSoftDeleteRetentionDays=30 \
  --name "$DEPLOY_NAME" \
  --mode Incremental
echo ""
echo "✅ Deployment complete"

# Step 5: List all resources
echo ""
echo "Step 5: Deployed resources:"
az resource list \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name:name, Type:type}" \
  -o table

# Step 6: Print key outputs
echo ""
echo "============================================"
echo "  KEY OUTPUTS"
echo "============================================"

echo ""
echo "Static Outbound IP (share with Damco for DB2 whitelist):"
az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name "pip-${PROJECT}-${ENV}-${REGION_SHORT}-nat" \
  --query ipAddress -o tsv 2>/dev/null || echo "Check pip-*-nat in Azure Portal"

echo ""
echo "App Gateway Public IP (for DNS/domain mapping):"
az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name "pip-${PROJECT}-${ENV}-${REGION_SHORT}-agw" \
  --query ipAddress -o tsv 2>/dev/null || echo "Check pip-*-agw in Azure Portal"

echo ""
echo "Key Vault URI:"
az keyvault show \
  --name "kv-${PROJECT}-${ENV}-${REGION_SHORT}-02" \
  --resource-group $RESOURCE_GROUP \
  --query properties.vaultUri -o tsv 2>/dev/null || \
az keyvault show \
  --name "kv-${PROJECT}-${ENV}-${REGION_SHORT}" \
  --resource-group $RESOURCE_GROUP \
  --query properties.vaultUri -o tsv 2>/dev/null || echo "Check Key Vault in Azure Portal"

echo ""
echo "Frontend App URL:"
az webapp show \
  --name "app-${PROJECT}-${ENV}-${REGION_SHORT}-fe" \
  --resource-group $RESOURCE_GROUP \
  --query defaultHostName -o tsv 2>/dev/null | sed 's/^/https:\/\//' || echo "Check App Services in Azure Portal"

echo ""
echo "Backend App URL:"
az webapp show \
  --name "app-${PROJECT}-${ENV}-${REGION_SHORT}-be" \
  --resource-group $RESOURCE_GROUP \
  --query defaultHostName -o tsv 2>/dev/null | sed 's/^/https:\/\//' || echo "Check App Services in Azure Portal"

echo ""
echo "============================================"
echo "  ✅ SBM QA INFRASTRUCTURE READY!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Share Static Outbound IP with Damco team for DB2 firewall whitelisting"
echo "2. Point your domain DNS to the App Gateway Public IP"
echo "3. Add required secrets to Key Vault"
echo ""
echo "To delete this environment:"
echo "az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""
