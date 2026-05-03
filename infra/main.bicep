// ============================================================
// main.bicep — SBM Infrastructure Orchestrator
// Naming: Microsoft CAF standard
// Tagging: Damco enterprise standard
// Region: Central India (cin)
// ============================================================

targetScope = 'resourceGroup'

// ── Parameters ───────────────────────────────────────────────
@description('Deployment environment')
@allowed(['dev', 'qa', 'uat', 'prod'])
param environment string

@description('Short project code used in all resource names')
param projectName string = 'sbm'

@description('Azure region short code for naming')
param regionShort string = 'cin'

@description('Azure region for deployment')
param location string = 'centralindia'

@description('App Service Plan SKU')
param appServicePlanSku string = 'B2'

@description('App Service Plan tier')
param appServicePlanTier string = 'Basic'

@description('SQL admin login name')
param sqlAdminLogin string = 'sbmadmin'

@description('SQL admin password — injected by pipeline from Key Vault')
@secure()
param sqlAdminPassword string

@description('SQL Database SKU')
param sqlDatabaseSku string = 'S1'

@description('Redis Cache SKU')
param redisCacheSku string = 'C1'

@description('Redis Cache family')
param redisCacheFamily string = 'C'

@description('Redis Cache capacity')
param redisCacheCapacity int = 1

@description('Event Hub throughput units')
param eventHubThroughputUnits int = 1

@description('Event Hub partition count')
param eventHubPartitionCount int = 2

@description('Event Hub message retention in days')
param eventHubMessageRetentionDays int = 7

@description('Storage account SKU')
param storageAccountSku string = 'Standard_LRS'

@description('Log Analytics retention in days')
param logAnalyticsRetentionDays int = 30

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('App subnet prefix')
param appSubnetPrefix string = '10.0.1.0/24'

@description('Data subnet prefix')
param dataSubnetPrefix string = '10.0.2.0/24'

// ── Mandatory tags applied to all resources ───────────────────
var commonTags = {
  Project: projectName
  Environment: environment
  Owner: 'damco-infra-team'
  ManagedBy: 'damco'
  Client: 'seaboard-marine'
  CostCenter: '${projectName}-${environment}-2026'
  DeployedBy: 'azure-devops'
  CreatedOn: '2026-04-26'
}

// ── Naming variables (CAF standard) ──────────────────────────
var base = '${projectName}-${environment}-${regionShort}'

// ── Module: VNet ──────────────────────────────────────────────
module vnet 'modules/vnet.bicep' = {
  name: 'deploy-vnet-${environment}'
  params: {
    location: location
    base: base
    vnetAddressPrefix: vnetAddressPrefix
    appSubnetPrefix: appSubnetPrefix
    dataSubnetPrefix: dataSubnetPrefix
    tags: commonTags
  }
}

// ── Module: Key Vault ─────────────────────────────────────────
module keyVault 'modules/keyvault.bicep' = {
  name: 'deploy-kv-${environment}'
  params: {
    location: location
    base: base
    tags: commonTags
  }
}

// ── Module: Monitoring ────────────────────────────────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring-${environment}'
  params: {
    location: location
    base: base
    retentionDays: logAnalyticsRetentionDays
    tags: commonTags
  }
}

// ── Module: Storage ───────────────────────────────────────────
module storage 'modules/storage.bicep' = {
  name: 'deploy-storage-${environment}'
  params: {
    location: location
    projectName: projectName
    environment: environment
    regionShort: regionShort
    storageSku: storageAccountSku
    tags: commonTags
  }
}

// ── Module: SQL ───────────────────────────────────────────────
module sql 'modules/sql.bicep' = {
  name: 'deploy-sql-${environment}'
  params: {
    location: location
    base: base
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    sqlDatabaseSku: sqlDatabaseSku
    tags: commonTags
  }
}

// ── Module: Redis ─────────────────────────────────────────────
module redis 'modules/redis.bicep' = {
  name: 'deploy-redis-${environment}'
  params: {
    location: location
    base: base
    redisSku: redisCacheSku
    redisFamily: redisCacheFamily
    redisCapacity: redisCacheCapacity
    tags: commonTags
  }
}

// ── Module: Event Hubs ────────────────────────────────────────
module eventHub 'modules/eventhub.bicep' = {
  name: 'deploy-evh-${environment}'
  params: {
    location: location
    base: base
    throughputUnits: eventHubThroughputUnits
    partitionCount: eventHubPartitionCount
    messageRetentionDays: eventHubMessageRetentionDays
    tags: commonTags
  }
}

// ── Module: App Services ──────────────────────────────────────
module appService 'modules/appservice.bicep' = {
  name: 'deploy-app-${environment}'
  params: {
    location: location
    base: base
    environment: environment
    appServicePlanSku: appServicePlanSku
    appServicePlanTier: appServicePlanTier
    appSubnetId: vnet.outputs.appSubnetId
    keyVaultUri: keyVault.outputs.keyVaultUri
    appInsightsFrontendKey: monitoring.outputs.appInsightsFrontendKey
    appInsightsFrontendConnStr: monitoring.outputs.appInsightsFrontendConnStr
    appInsightsBackendKey: monitoring.outputs.appInsightsBackendKey
    appInsightsBackendConnStr: monitoring.outputs.appInsightsBackendConnStr
    appInsightsFunctionKey: monitoring.outputs.appInsightsFunctionKey
    appInsightsFunctionConnStr: monitoring.outputs.appInsightsFunctionConnStr
    redisConnectionString: redis.outputs.redisConnectionString
    eventHubConnectionString: eventHub.outputs.eventHubConnectionString
    eventHubName: eventHub.outputs.eventHubName
    storageConnectionString: storage.outputs.storageConnectionString
    sqlConnectionString: sql.outputs.sqlConnectionString
    tags: commonTags
  }
}

// ── Outputs ───────────────────────────────────────────────────
output frontendUrl string = appService.outputs.frontendAppUrl
output backendUrl string = appService.outputs.backendAppUrl
output functionUrl string = appService.outputs.functionAppUrl
output keyVaultUri string = keyVault.outputs.keyVaultUri
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output redisCacheHostName string = redis.outputs.redisCacheHostName
output eventHubNamespace string = eventHub.outputs.eventHubNamespaceName
output logAnalyticsId string = monitoring.outputs.logAnalyticsId
output storageAccountName string = storage.outputs.storageAccountName
output vnetName string = vnet.outputs.vnetName
output resourceGroupName string = resourceGroup().name
