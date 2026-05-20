// ============================================================
// main.bicep — SBM Infrastructure Orchestrator
// Naming:  Microsoft CAF standard
// Tagging: Damco enterprise standard
// Version: 2.0 — Multi-env, APIM, AppGW, NAT Gateway
// ============================================================

targetScope = 'resourceGroup'

// ── Core Parameters ───────────────────────────────────────────
@description('Deployment environment')
@allowed(['dev', 'test', 'qa', 'uat', 'prod'])
param environment string

@description('Short project code used in all resource names')
@minLength(2)
@maxLength(6)
param projectName string = 'sbm'

@description('Azure region short code for naming')
param regionShort string = 'cin'

@description('Azure region for deployment')
param location string = 'centralindia'

// ── Feature Flags ─────────────────────────────────────────────
@description('Deploy Application Gateway (WAF v2) — false for dev, true for qa/prod')
param deployAppGateway bool = false

@description('Deploy Azure API Management — false for dev, true for qa/prod')
param deployApim bool = false

@description('Deploy NAT Gateway for static outbound IP (backend → on-prem DB2)')
param deployNatGateway bool = false

// ── App Service Parameters ────────────────────────────────────
@description('App Service Plan SKU name')
param appServicePlanSku string = 'B2'

@description('App Service Plan SKU tier')
param appServicePlanTier string = 'Basic'

// ── SQL Parameters ────────────────────────────────────────────
@description('SQL admin login name')
param sqlAdminLogin string = 'sbmadmin'

@description('SQL admin password — injected by pipeline from Key Vault / GitHub Secret')
@secure()
param sqlAdminPassword string

@description('SQL Database SKU')
param sqlDatabaseSku string = 'S1'

// ── Redis Parameters ──────────────────────────────────────────
@description('Redis Cache SKU tier')
@allowed(['Basic', 'Standard', 'Premium'])
param redisSkuName string = 'Standard'

@description('Redis Cache family')
@allowed(['C', 'P'])
param redisCacheFamily string = 'C'

@description('Redis Cache capacity')
param redisCacheCapacity int = 1

// ── Event Hub Parameters ──────────────────────────────────────
@description('Event Hub throughput units')
param eventHubThroughputUnits int = 1

@description('Event Hub partition count')
param eventHubPartitionCount int = 2

@description('Event Hub message retention in days')
param eventHubMessageRetentionDays int = 7

// ── Storage Parameters ────────────────────────────────────────
@description('Storage account SKU')
param storageAccountSku string = 'Standard_LRS'

// ── Monitoring Parameters ─────────────────────────────────────
@description('Log Analytics retention in days')
param logAnalyticsRetentionDays int = 30

// ── Network Parameters ────────────────────────────────────────
@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('App subnet prefix')
param appSubnetPrefix string = '10.0.1.0/24'

@description('Data subnet prefix')
param dataSubnetPrefix string = '10.0.2.0/24'

@description('Gateway subnet prefix — required when deployAppGateway = true')
param gwSubnetPrefix string = '10.0.3.0/24'

// ── APIM Parameters ───────────────────────────────────────────
@description('APIM publisher email')
param apimPublisherEmail string = 'infra@damcogroup.com'

@description('APIM publisher name')
param apimPublisherName string = 'Damco Solutions'

// ── Tags ──────────────────────────────────────────────────────
var commonTags = {
  Project: projectName
  Environment: environment
  Owner: 'damco-infra-team'
  ManagedBy: 'damco'
  Client: 'seaboard-marine'
  CostCenter: '${projectName}-${environment}'
  DeployedBy: 'github-actions'
}

// ── Naming base ───────────────────────────────────────────────
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
    gwSubnetPrefix: gwSubnetPrefix
    deployAppGateway: deployAppGateway
    natGatewayId: deployNatGateway ? natGateway.outputs.natGatewayId : ''
    tags: commonTags
  }
}

// ── Module: NAT Gateway (Static Outbound IP) ──────────────────
module natGateway 'modules/natgateway.bicep' = if (deployNatGateway) {
  name: 'deploy-natgw-${environment}'
  params: {
    location: location
    base: base
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
    base: base
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
    redisSkuName: redisSkuName
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

// ── SQL Connection String ─────────────────────────────────────
var sqlConnStr = 'Server=tcp:${sql.outputs.sqlServerFqdn},1433;Initial Catalog=${sql.outputs.sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

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
    sqlConnectionString: sqlConnStr
    tags: commonTags
  }
}

// ── Module: APIM (optional) ───────────────────────────────────
module apim 'modules/apim.bicep' = if (deployApim) {
  name: 'deploy-apim-${environment}'
  params: {
    location: location
    base: base
    environment: environment
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    tags: commonTags
  }
}

// ── Module: Application Gateway (optional) ────────────────────
module appGateway 'modules/appgateway.bicep' = if (deployAppGateway) {
  name: 'deploy-appgw-${environment}'
  params: {
    location: location
    base: base
    gatewaySubnetId: vnet.outputs.gwSubnetId
    backendFqdn: appService.outputs.backendAppFqdn
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
output staticOutboundIp string = deployNatGateway ? natGateway.outputs.staticPublicIp : 'NAT Gateway not deployed — enable deployNatGateway=true'
output apimGatewayUrl string = deployApim ? apim.outputs.apimGatewayUrl : 'APIM not deployed — enable deployApim=true'
output appGatewayPublicIp string = deployAppGateway ? appGateway.outputs.appGatewayPublicIp : 'AppGW not deployed — enable deployAppGateway=true'
