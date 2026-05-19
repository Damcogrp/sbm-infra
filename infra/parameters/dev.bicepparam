// ============================================================
// parameters/dev.bicepparam
// Environment: DEV
// Azure:       Damco subscription
// AppGW:       false (not needed for dev)
// APIM:        false (not needed for dev)
// NatGateway:  false (not needed for dev)
// ============================================================

using '../main.bicep'

param environment            = 'dev'
param projectName            = 'sbm'
param location               = 'centralindia'
param regionShort            = 'cin'

// ── Feature Flags ─────────────────────────────────────────────
param deployAppGateway       = false
param deployApim             = false
param deployNatGateway       = false

// ── Compute ───────────────────────────────────────────────────
param appServicePlanSku      = 'B2'
param appServicePlanTier     = 'Basic'

// ── Database ──────────────────────────────────────────────────
param sqlAdminLogin          = 'sbmadmin'
param sqlDatabaseSku         = 'S1'

// ── Redis ─────────────────────────────────────────────────────
param redisSkuName           = 'Standard'
param redisCacheFamily       = 'C'
param redisCacheCapacity     = 1

// ── Event Hub ─────────────────────────────────────────────────
param eventHubThroughputUnits      = 1
param eventHubPartitionCount       = 2
param eventHubMessageRetentionDays = 7

// ── Storage ───────────────────────────────────────────────────
param storageAccountSku      = 'Standard_LRS'

// ── Monitoring ────────────────────────────────────────────────
param logAnalyticsRetentionDays = 30

// ── Network ───────────────────────────────────────────────────
param vnetAddressPrefix      = '10.0.0.0/16'
param appSubnetPrefix        = '10.0.1.0/24'
param dataSubnetPrefix       = '10.0.2.0/24'
param gwSubnetPrefix         = '10.0.3.0/24'
