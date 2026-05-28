// ============================================================
// main.bicep — SBM Infrastructure Orchestrator
// Version: 4.0 — Full feature flags for all services
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
param deployVnet            bool = true
param deployKeyVault        bool = true
param deployMonitoring      bool = true
param deployStorage         bool = true
param deploySql             bool = true    // Set false to skip SQL initially
param deployRedis           bool = true
param deployEventHub        bool = true
param deployAppService      bool = true
param deployScheduler       bool = true
param deployNatGateway      bool = true
param deployAppGateway      bool = false
param deployApim            bool = false
param deployDdosProtection  bool = false
param deployDr              bool = false

// ── Alert Parameters ──────────────────────────────────────────
param alertsEnabled                bool  = true
param alertEmailReceivers          array = []
param cpuThresholdPercent          int   = 80
param memoryThresholdPercent       int   = 85
param sqlDtuThresholdPercent       int   = 80
param redisMemoryThresholdPercent  int   = 80
param http5xxThreshold             int   = 10
param availabilityThresholdPercent int   = 99

// ── DR Parameters ─────────────────────────────────────────────

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
  params: { location: location, base: base, tags: commonTags }
}

// ── Module: NAT Gateway ───────────────────────────────────────
module natGateway 'modules/natgateway.bicep' = if (deployNatGateway) {
  name: 'deploy-natgw-${environment}'
  params: { location: location, base: base, tags: commonTags }
}

// ── Module: VNet ──────────────────────────────────────────────
module vnet 'modules/vnet.bicep' = if (deployVnet) {
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

module keyVault 'modules/keyvault.bicep' = if (deployKeyVault) {
  name: 'deploy-kv-${environment}'
  params: {
    location: location, base: base, tags: commonTags
    secretExpiryDays: kvSecretExpiryDays
    softDeleteRetentionDays: kvSoftDeleteRetentionDays
    allowedIpAddresses: kvIps
  }
}

// ── Module: Monitoring ────────────────────────────────────────
module monitoring 'modules/monitoring.bicep' = if (deployMonitoring) {
  name: 'deploy-monitoring-${environment}'
  params: { location: location, base: base, retentionDays: logAnalyticsRetentionDays, tags: commonTags }
}

// ── Module: Storage ───────────────────────────────────────────
module storage 'modules/storage.bicep' = if (deployStorage) {
  name: 'deploy-storage-${environment}'
  params: { location: location, base: base, storageSku: storageAccountSku, tags: commonTags }
}

// ── Module: SQL (conditional) ─────────────────────────────────
module sql 'modules/sql.bicep' = if (deploySql) {
  name: 'deploy-sql-${environment}'
  params: {
    location: location, base: base, tags: commonTags
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    sqlDatabaseSku: sqlDatabaseSku
    dataSubnetId: deployVnet ? vnet.outputs.dataSubnetId : ''
  }
}

// ── Module: Redis ─────────────────────────────────────────────
module redis 'modules/redis.bicep' = if (deployRedis) {
  name: 'deploy-redis-${environment}'
  params: {
    location: location, base: base, tags: commonTags
    redisSkuName: redisSkuName
    redisFamily: redisCacheFamily
    redisCapacity: redisCacheCapacity
  }
}

// ── Module: Event Hubs ────────────────────────────────────────
module eventHub 'modules/eventhub.bicep' = if (deployEventHub) {
  name: 'deploy-evh-${environment}'
  params: {
    location: location, base: base, tags: commonTags
    throughputUnits: eventHubThroughputUnits
    partitionCount: eventHubPartitionCount
    messageRetentionDays: eventHubMessageRetentionDays
  }
}

// ── SQL Connection String ─────────────────────────────────────
var sqlConnStr = deploySql ? 'Server=tcp:${sql.outputs.sqlServerFqdn},1433;Initial Catalog=${sql.outputs.sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;' : ''

// ── Module: App Services ──────────────────────────────────────
module appService 'modules/appservice.bicep' = if (deployAppService && deployVnet) {
  name: 'deploy-app-${environment}'
  params: {
    location: location, base: base, environment: environment, tags: commonTags
    appServicePlanSku: appServicePlanSku
    appServicePlanTier: appServicePlanTier
    appSubnetId: vnet.outputs.appSubnetId
    keyVaultUri: deployKeyVault ? keyVault.outputs.keyVaultUri : ''
    appInsightsFrontendKey: deployMonitoring ? monitoring.outputs.appInsightsFrontendKey : ''
    appInsightsFrontendConnStr: deployMonitoring ? monitoring.outputs.appInsightsFrontendConnStr : ''
    appInsightsBackendKey: deployMonitoring ? monitoring.outputs.appInsightsBackendKey : ''
    appInsightsBackendConnStr: deployMonitoring ? monitoring.outputs.appInsightsBackendConnStr : ''
    appInsightsFunctionKey: deployMonitoring ? monitoring.outputs.appInsightsFunctionKey : ''
    appInsightsFunctionConnStr: deployMonitoring ? monitoring.outputs.appInsightsFunctionConnStr : ''
    redisConnectionString: deployRedis ? redis.outputs.redisConnectionString : ''
    eventHubConnectionString: deployEventHub ? eventHub.outputs.eventHubConnectionString : ''
    eventHubName: deployEventHub ? eventHub.outputs.eventHubName : ''
    storageConnectionString: deployStorage ? storage.outputs.storageConnectionString : ''
    sqlConnectionString: sqlConnStr
  }
}

// ── Module: Scheduler ────────────────────────────────────────
module scheduler 'modules/scheduler.bicep' = if (deployScheduler) {
  name: 'deploy-scheduler-${environment}'
  params: { location: location, base: base, tags: commonTags }
}

// ── Module: Alerts ────────────────────────────────────────────
module alerts 'modules/alerts.bicep' = if (alertsEnabled && deployMonitoring && deployAppService) {
  name: 'deploy-alerts-${environment}'
  params: {
    base: base, tags: commonTags
    alertEmailReceivers: alertEmailReceivers
    appServicePlanId: appService.outputs.appServicePlanId
    frontendAppId: appService.outputs.frontendAppId
    backendAppId: appService.outputs.backendAppId
    sqlServerId: deploySql ? sql.outputs.sqlServerId : ''
    redisId: deployRedis ? redis.outputs.redisCacheId : ''
    keyVaultId: deployKeyVault ? keyVault.outputs.keyVaultId : ''
    storageAccountId: deployStorage ? storage.outputs.storageAccountId : ''
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
    location: location, base: base, environment: environment, tags: commonTags
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

// ── Module: Application Gateway ───────────────────────────────
module appGateway 'modules/appgateway.bicep' = if (deployAppGateway && deployVnet && deployAppService) {
  name: 'deploy-appgw-${environment}'
  params: {
    location: location, base: base, tags: commonTags
    gatewaySubnetId: vnet.outputs.gwSubnetId
    backendFqdn: appService.outputs.backendAppFqdn
  }
}

// ── Module: DR ───────────────────────────────────────────────
module dr 'modules/dr.bicep' = if (deployDr && deployAppService && deploySql) {
  name: 'deploy-dr-${environment}'
  params: {
    base: base, tags: commonTags
    primaryFrontendFqdn: appService.outputs.frontendAppFqdn
    primarySqlServerName: sql.outputs.sqlServerName
  }
}

// ── Outputs ───────────────────────────────────────────────────
output resourceGroupName  string = resourceGroup().name
output vnetName           string = deployVnet ? vnet.outputs.vnetName : 'VNet not deployed'
output keyVaultUri        string = deployKeyVault ? keyVault.outputs.keyVaultUri : 'Key Vault not deployed'
output frontendUrl        string = deployAppService ? appService.outputs.frontendAppUrl : 'App Service not deployed'
output backendUrl         string = deployAppService ? appService.outputs.backendAppUrl : 'App Service not deployed'
output functionUrl        string = deployAppService ? appService.outputs.functionAppUrl : 'App Service not deployed'
output sqlServerFqdn      string = deploySql ? sql.outputs.sqlServerFqdn : 'SQL not deployed'
output redisCacheHostName string = deployRedis ? redis.outputs.redisCacheHostName : 'Redis not deployed'
output eventHubNamespace  string = deployEventHub ? eventHub.outputs.eventHubNamespaceName : 'EventHub not deployed'
output storageAccountName string = deployStorage ? storage.outputs.storageAccountName : 'Storage not deployed'
output staticOutboundIp   string = deployNatGateway ? natGateway.outputs.staticPublicIp : 'NAT Gateway not deployed'
output apimGatewayUrl     string = deployApim ? apim.outputs.apimGatewayUrl : 'APIM not deployed'
output appGatewayPublicIp string = deployAppGateway ? appGateway.outputs.appGatewayPublicIp : 'AppGW not deployed'
output schedulerName      string = deployScheduler ? scheduler.outputs.logicAppName : 'Scheduler not deployed'
output alertActionGroupId string = alertsEnabled ? alerts.outputs.actionGroupId : 'Alerts not enabled'
output ddosPlanId         string = deployDdosProtection ? ddos.outputs.ddosPlanId : 'DDoS not deployed'
output trafficManagerFqdn string = deployDr ? dr.outputs.trafficManagerFqdn : 'DR not deployed'
