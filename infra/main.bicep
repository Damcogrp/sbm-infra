// ============================================================
// main.bicep — SBM Infrastructure Orchestrator
// Version: 4.0
// Changes:
//   - Expanded alerts (availability, http5xx, KV access denied)
//   - DR Strategy (Traffic Manager + SQL Failover Group)
//   - DDoS Protection Standard (configurable flag)
//   - UAT environment support
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
param deployAppGateway      bool = false
param deployApim            bool = false
param deployNatGateway      bool = true
param deployScheduler       bool = true
param deployDdosProtection  bool = false   // DDoS Standard — prod only
param deployDr              bool = false   // DR — prod only

// ── Alert Parameters ──────────────────────────────────────────
param alertsEnabled               bool  = true
param alertEmailReceivers         array = []
param cpuThresholdPercent         int   = 80
param memoryThresholdPercent      int   = 85
param sqlDtuThresholdPercent      int   = 80
param redisMemoryThresholdPercent int   = 80
param http5xxThreshold            int   = 10
param availabilityThresholdPercent int  = 99

// ── DR Parameters ─────────────────────────────────────────────
param drSecondaryLocation    string = 'southindia'
param drSecondaryRegionShort string = 'sin'
param drSqlFailover          bool   = false
param drTrafficManager       bool   = false

// ── App Service Parameters ────────────────────────────────────
param appServicePlanSku  string = 'B1'
param appServicePlanTier string = 'Basic'

// ── SQL Parameters ────────────────────────────────────────────
param sqlAdminLogin    string = 'sbmadmin'
@secure()
param sqlAdminPassword string = ''
param sqlDatabaseSku   string = 'S1'

// ── Redis Parameters ──────────────────────────────────────────
@allowed(['Basic', 'Standard', 'Premium'])
param redisSkuName      string = 'Standard'
@allowed(['C', 'P'])
param redisCacheFamily  string = 'C'
param redisCacheCapacity int   = 1

// ── Event Hub Parameters ──────────────────────────────────────
param eventHubThroughputUnits      int = 1
param eventHubPartitionCount       int = 2
param eventHubMessageRetentionDays int = 7

// ── Storage Parameters ────────────────────────────────────────
param storageAccountSku string = 'Standard_LRS'

// ── Monitoring Parameters ─────────────────────────────────────
param logAnalyticsRetentionDays int = 30

// ── Network Parameters ────────────────────────────────────────
param vnetAddressPrefix string = '10.0.0.0/24'
param appSubnetPrefix   string = '10.0.0.0/27'
param dataSubnetPrefix  string = '10.0.0.32/27'
param gwSubnetPrefix    string = '10.0.0.64/27'

// ── Key Vault Parameters ──────────────────────────────────────
param kvSecretExpiryDays        int   = 45
param kvSoftDeleteRetentionDays int   = 7
param kvAllowedIpAddresses      array = []

// ── APIM Parameters ───────────────────────────────────────────
param apimPublisherEmail string = 'infra@damcogroup.com'
param apimPublisherName  string = 'Damco Solutions'

// ── Tags ──────────────────────────────────────────────────────
var commonTags = {
  Project:     projectName
  Environment: environment
  Owner:       'damco-infra-team'
  ManagedBy:   'damco'
  Client:      'seaboard-marine'
  CostCenter:  '${projectName}-${environment}'
  DeployedBy:  'github-actions'
}

var base = '${projectName}-${environment}-${regionShort}'

// ── Module: DDoS Protection ───────────────────────────────────
module ddos 'modules/ddos.bicep' = if (deployDdosProtection) {
  name: 'deploy-ddos-${environment}'
  params: {
    location: location
    base: base
    tags: commonTags
  }
}

// ── Module: NAT Gateway ───────────────────────────────────────
module natGateway 'modules/natgateway.bicep' = if (deployNatGateway) {
  name: 'deploy-natgw-${environment}'
  params: {
    location: location
    base: base
    tags: commonTags
  }
}

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
    ddosPlanId: deployDdosProtection ? ddos.outputs.ddosPlanId : ''
    tags: commonTags
  }
}

// ── Module: Key Vault ─────────────────────────────────────────
var natIp = deployNatGateway ? natGateway.outputs.staticPublicIp : ''
var kvIps = empty(natIp) ? kvAllowedIpAddresses : concat(kvAllowedIpAddresses, [natIp])

module keyVault 'modules/keyvault.bicep' = {
  name: 'deploy-kv-${environment}'
  params: {
    location: location
    base: base
    tags: commonTags
    secretExpiryDays: kvSecretExpiryDays
    softDeleteRetentionDays: kvSoftDeleteRetentionDays
    allowedIpAddresses: kvIps
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
    dataSubnetId: vnet.outputs.dataSubnetId
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

// ── Module: Scheduler ────────────────────────────────────────
module scheduler 'modules/scheduler.bicep' = if (deployScheduler) {
  name: 'deploy-scheduler-${environment}'
  params: {
    location: location
    base: base
    tags: commonTags
  }
}

// ── Module: Alerts (expanded) ────────────────────────────────
module alerts 'modules/alerts.bicep' = if (alertsEnabled) {
  name: 'deploy-alerts-${environment}'
  params: {
    base: base
    tags: commonTags
    alertEmailReceivers: alertEmailReceivers
    appServicePlanId: appService.outputs.appServicePlanId
    frontendAppId: appService.outputs.frontendAppId
    backendAppId: appService.outputs.backendAppId
    functionAppId: appService.outputs.functionAppId
    sqlServerId: sql.outputs.sqlServerId
    redisId: redis.outputs.redisCacheId
    keyVaultId: keyVault.outputs.keyVaultId
    storageAccountId: storage.outputs.storageAccountId
    logAnalyticsId: monitoring.outputs.logAnalyticsId
    cpuThresholdPercent: cpuThresholdPercent
    memoryThresholdPercent: memoryThresholdPercent
    sqlDtuThresholdPercent: sqlDtuThresholdPercent
    redisMemoryThresholdPercent: redisMemoryThresholdPercent
    http5xxThreshold: http5xxThreshold
    availabilityThresholdPercent: availabilityThresholdPercent
  }
}

// ── Module: APIM ─────────────────────────────────────────────
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

// ── Module: Application Gateway ───────────────────────────────
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

// ── Module: DR ───────────────────────────────────────────────
module dr 'modules/dr.bicep' = if (deployDr && drTrafficManager) {
  name: 'deploy-dr-${environment}'
  params: {
    base: base
    tags: commonTags
    primaryLocation: location
    primaryFrontendFqdn: appService.outputs.frontendAppFqdn
    primaryBackendFqdn: appService.outputs.backendAppFqdn
    primarySqlServerId: sql.outputs.sqlServerId
    primarySqlServerName: sql.outputs.sqlServerName
    secondaryLocation: drSecondaryLocation
    secondaryRegionShort: drSecondaryRegionShort
  }
}

// ── Outputs ───────────────────────────────────────────────────
output frontendUrl        string = appService.outputs.frontendAppUrl
output backendUrl         string = appService.outputs.backendAppUrl
output functionUrl        string = appService.outputs.functionAppUrl
output keyVaultUri        string = keyVault.outputs.keyVaultUri
output sqlServerFqdn      string = sql.outputs.sqlServerFqdn
output redisCacheHostName string = redis.outputs.redisCacheHostName
output eventHubNamespace  string = eventHub.outputs.eventHubNamespaceName
output logAnalyticsId     string = monitoring.outputs.logAnalyticsId
output storageAccountName string = storage.outputs.storageAccountName
output vnetName           string = vnet.outputs.vnetName
output resourceGroupName  string = resourceGroup().name
output staticOutboundIp   string = deployNatGateway ? natGateway.outputs.staticPublicIp : 'NAT Gateway not deployed'
output apimGatewayUrl     string = deployApim ? apim.outputs.apimGatewayUrl : 'APIM not deployed'
output appGatewayPublicIp string = deployAppGateway ? appGateway.outputs.appGatewayPublicIp : 'AppGW not deployed'
output schedulerName      string = deployScheduler ? scheduler.outputs.logicAppName : 'Scheduler not deployed'
output alertActionGroupId string = alertsEnabled ? alerts.outputs.actionGroupId : 'Alerts not enabled'
output ddosPlanId         string = deployDdosProtection ? ddos.outputs.ddosPlanId : 'DDoS not deployed'
output trafficManagerFqdn string = (deployDr && drTrafficManager) ? dr.outputs.trafficManagerFqdn : 'DR not deployed'
