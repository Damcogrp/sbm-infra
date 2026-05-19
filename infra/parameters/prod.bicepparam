// ============================================================
// parameters/prod.bicepparam
// Environment: PROD
// Azure:       CLIENT subscription
// AppGW:       true  (WAF v2 enabled)
// APIM:        true  (Standard tier — SLA backed)
// NatGateway:  true  (static IP for on-prem DB2 access)
//
// CLIENT SETUP CHECKLIST:
// Before running this pipeline the client must:
// 1. Add GitHub secret: AZURE_CLIENT_ID_PROD
// 2. Add GitHub secret: AZURE_TENANT_ID_PROD
// 3. Add GitHub secret: AZURE_SUBSCRIPTION_ID_PROD
// 4. Add GitHub secret: SQL_ADMIN_PASSWORD_PROD
// 5. Update location below to match client's preferred region
// 6. Update vnetAddressPrefix to avoid clash with client's network
// ============================================================

using '../main.bicep'

param environment            = 'prod'
param projectName            = 'sbm'
param location               = 'centralindia'     // TODO: update to client's region
param regionShort            = 'cin'              // TODO: update to match location

// ── Feature Flags ─────────────────────────────────────────────
param deployAppGateway       = true
param deployApim             = true
param deployNatGateway       = true

// ── Compute ───────────────────────────────────────────────────
param appServicePlanSku      = 'P2v3'
param appServicePlanTier     = 'PremiumV3'

// ── Database ──────────────────────────────────────────────────
param sqlAdminLogin          = 'sbmadmin'
param sqlDatabaseSku         = 'S3'

// ── Redis ─────────────────────────────────────────────────────
param redisSkuName           = 'Standard'
param redisCacheFamily       = 'C'
param redisCacheCapacity     = 2

// ── Event Hub ─────────────────────────────────────────────────
param eventHubThroughputUnits      = 2
param eventHubPartitionCount       = 4
param eventHubMessageRetentionDays = 7

// ── Storage ───────────────────────────────────────────────────
param storageAccountSku      = 'Standard_GRS'

// ── Monitoring ────────────────────────────────────────────────
param logAnalyticsRetentionDays = 90

// ── Network ───────────────────────────────────────────────────
// TODO: Confirm these ranges do not clash with client's existing network
param vnetAddressPrefix      = '10.5.0.0/16'
param appSubnetPrefix        = '10.5.1.0/24'
param dataSubnetPrefix       = '10.5.2.0/24'
param gwSubnetPrefix         = '10.5.3.0/24'

// ── APIM ──────────────────────────────────────────────────────
param apimPublisherEmail     = 'infra@damcogroup.com'
param apimPublisherName      = 'Damco Solutions'
