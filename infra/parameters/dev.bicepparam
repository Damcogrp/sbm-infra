// ============================================================
// parameters/dev.bicepparam
// SBM Dev environment — Damco subscription — Central India
// All values aligned to CAF naming and Damco tagging standard
// ============================================================

using '../main.bicep'

param environment            = 'dev'
param projectName            = 'sbm'
param regionShort            = 'cin'
param location               = 'centralindia'

param appServicePlanSku      = 'B2'
param appServicePlanTier     = 'Basic'

param sqlAdminLogin          = 'sbmadmin'
param sqlAdminPassword       = ''          // injected by pipeline — never hardcode
param sqlDatabaseSku         = 'S1'

param redisCacheSku          = 'C1'
param redisCacheFamily       = 'C'
param redisCacheCapacity     = 1

param eventHubThroughputUnits      = 1
param eventHubPartitionCount       = 2
param eventHubMessageRetentionDays = 7

param storageAccountSku      = 'Standard_LRS'
param logAnalyticsRetentionDays = 30

param vnetAddressPrefix      = '10.0.0.0/16'
param appSubnetPrefix        = '10.0.1.0/24'
param dataSubnetPrefix       = '10.0.2.0/24'
