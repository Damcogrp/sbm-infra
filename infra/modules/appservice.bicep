// ============================================================
// modules/appservice.bicep
// CAF names:
//   Plan:     asp-sbm-{env}-cin
//   Frontend: app-sbm-{env}-cin-fe
//   Backend:  app-sbm-{env}-cin-be
//   EventBus: func-sbm-{env}-cin-evb
// ============================================================

@description('Azure region for deployment')
param location string

@description('Base naming token: {project}-{env}-{region}')
param base string

@description('Deployment environment label')
param environment string

@description('App Service Plan SKU name')
param appServicePlanSku string

@description('App Service Plan SKU tier')
param appServicePlanTier string

@description('Subnet resource ID for VNet integration')
param appSubnetId string

@description('Key Vault URI for app configuration')
param keyVaultUri string

param tags object

// ── App Insights ──────────────────────────────────────────────
param appInsightsFrontendKey string
param appInsightsFrontendConnStr string
param appInsightsBackendKey string
param appInsightsBackendConnStr string
param appInsightsFunctionKey string
param appInsightsFunctionConnStr string

// ── Connection strings ────────────────────────────────────────
@secure()
param redisConnectionString string

@secure()
param eventHubConnectionString string

param eventHubName string

@secure()
param storageConnectionString string

@secure()
param sqlConnectionString string

// ── Naming ────────────────────────────────────────────────────
var aspName     = 'asp-${base}'
var feAppName   = 'app-${base}-fe'
var beAppName   = 'app-${base}-be'
var funcAppName = 'func-${base}-evb'

// ── App Service Plan ──────────────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: aspName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
    tier: appServicePlanTier
  }
  kind: 'app'
  properties: { reserved: false }
}

// ── Frontend App (Angular v21) ────────────────────────────────
resource frontendApp 'Microsoft.Web/sites@2022-09-01' = {
  name: feAppName
  location: location
  identity: { type: 'SystemAssigned' }
  tags: union(tags, { Component: 'frontend', Stack: 'angular-v21' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/health'
      appSettings: [
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY',        value: appInsightsFrontendKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsFrontendConnStr }
        { name: 'ENVIRONMENT',                           value: environment }
        { name: 'KEY_VAULT_URI',                         value: keyVaultUri }
      ]
    }
  }
}

resource frontendVnet 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: frontendApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appSubnetId
    swiftSupported: true
  }
}

// ── Backend App (.NET Core Modular Monolith) ──────────────────
resource backendApp 'Microsoft.Web/sites@2022-09-01' = {
  name: beAppName
  location: location
  identity: { type: 'SystemAssigned' }
  tags: union(tags, { Component: 'backend', Stack: 'dotnet-8' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
      alwaysOn: true
      healthCheckPath: '/api/health'
      netFrameworkVersion: 'v8.0'
      appSettings: [
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY',        value: appInsightsBackendKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsBackendConnStr }
        { name: 'ENVIRONMENT',                           value: environment }
        { name: 'KEY_VAULT_URI',                         value: keyVaultUri }
        { name: 'Redis__ConnectionString',               value: redisConnectionString }
        { name: 'EventHub__ConnectionString',            value: eventHubConnectionString }
        { name: 'EventHub__Name',                        value: eventHubName }
      ]
      connectionStrings: [
        {
          name: 'SqlConnection'
          connectionString: sqlConnectionString
          type: 'SQLAzure'
        }
      ]
    }
  }
}

resource backendVnet 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: backendApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appSubnetId
    swiftSupported: true
  }
}

// ── EventBus Function App ─────────────────────────────────────
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: funcAppName
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  tags: union(tags, { Component: 'eventbus', Stack: 'dotnet-functions-v4' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      appSettings: [
        { name: 'AzureWebJobsStorage',                   value: storageConnectionString }
        { name: 'FUNCTIONS_EXTENSION_VERSION',           value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME',              value: 'dotnet' }
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY',        value: appInsightsFunctionKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsFunctionConnStr }
        { name: 'EventHubConnection',                    value: eventHubConnectionString }
        { name: 'ENVIRONMENT',                           value: environment }
        { name: 'KEY_VAULT_URI',                         value: keyVaultUri }
      ]
    }
  }
}

resource functionVnet 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: appSubnetId
    swiftSupported: true
  }
}

// ── Outputs ───────────────────────────────────────────────────
output appServicePlanId string = appServicePlan.id
output frontendAppUrl string = 'https://${frontendApp.properties.defaultHostName}'
output backendAppUrl string = 'https://${backendApp.properties.defaultHostName}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output backendAppFqdn string = backendApp.properties.defaultHostName
output frontendAppName string = frontendApp.name
output backendAppName string = backendApp.name
output functionAppName string = functionApp.name
output frontendPrincipalId string = frontendApp.identity.principalId
output backendPrincipalId string = backendApp.identity.principalId
output functionPrincipalId string = functionApp.identity.principalId
