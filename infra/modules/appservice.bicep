// ============================================================
// modules/appservice.bicep
// CAF names:
//   Plan:     asp-sbm-{env}-cin today
//   Frontend: app-sbm-{env}-cin-fe
//   Backend:  app-sbm-{env}-cin-be
//   EventBus: func-sbm-{env}-cin-evb
// ============================================================

param location string
param base string
param environment string
param appServicePlanSku string = 'B2'
param appServicePlanTier string = 'Basic'
param appSubnetId string
param keyVaultUri string
param tags object

param appInsightsFrontendKey string
param appInsightsFrontendConnStr string
param appInsightsBackendKey string
param appInsightsBackendConnStr string
param appInsightsFunctionKey string
param appInsightsFunctionConnStr string

param redisConnectionString string
param eventHubConnectionString string
param eventHubName string
param storageConnectionString string
param sqlConnectionString string

var aspName      = 'asp-${base}'
var feAppName    = 'app-${base}-fe'
var beAppName    = 'app-${base}-be'
var funcAppName  = 'func-${base}-evb'

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
  tags: union(tags, { Component: 'frontend', Stack: 'angular-v21' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
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
  tags: union(tags, { Component: 'backend', Stack: 'dotnet-8' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
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

// ── EventBus Function App (Adapter + Integration Layer) ───────
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: funcAppName
  location: location
  kind: 'functionapp'
  tags: union(tags, { Component: 'eventbus', Stack: 'dotnet-functions-v4' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
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

output appServicePlanId string = appServicePlan.id
output frontendAppUrl string = 'https://${frontendApp.properties.defaultHostName}'
output backendAppUrl string = 'https://${backendApp.properties.defaultHostName}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output frontendAppName string = frontendApp.name
output backendAppName string = backendApp.name
output functionAppName string = functionApp.name
