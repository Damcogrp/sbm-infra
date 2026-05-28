// ============================================================
// modules/alerts.bicep
// Expanded alerts — Mrugesh points 3a, 3b, 3c:
//   - Availability/health alerts per component
//   - http_5xx_threshold (Log Analytics query alert)
//   - Key Vault access denied alert
// ============================================================

param base string
param tags object
param alertEmailReceivers array = []

// ── Resource IDs ──────────────────────────────────────────────
param appServicePlanId string
param frontendAppId string = ''
param backendAppId string = ''
param sqlServerId string = ''
param redisId string = ''
param keyVaultId string = ''
param storageAccountId string = ''
param logAnalyticsId string = ''

// ── Thresholds ────────────────────────────────────────────────
param cpuThresholdPercent int = 80
param memoryThresholdPercent int = 85
param sqlDtuThresholdPercent int = 80
param redisMemoryThresholdPercent int = 80
param http5xxThreshold int = 10          // Point 3b: http 5xx threshold
param availabilityThresholdPercent int = 99  // Point 3a: availability threshold

var actionGroupName = 'ag-${base}'

// ── Action Group ──────────────────────────────────────────────
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'SBM-Alerts'
    enabled: true
    emailReceivers: [for receiver in alertEmailReceivers: {
      name: receiver.name
      emailAddress: receiver.email
      useCommonAlertSchema: true
    }]
  }
}

// ── Alert: CPU High ───────────────────────────────────────────
resource alertCpu 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${base}-cpu-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'App Service Plan CPU usage is high'
    severity: 2
    enabled: true
    scopes: [ appServicePlanId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: cpuThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: Memory High ────────────────────────────────────────
resource alertMemory 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${base}-memory-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'App Service Plan memory usage is high'
    severity: 2
    enabled: true
    scopes: [ appServicePlanId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemory'
          metricName: 'MemoryPercentage'
          operator: 'GreaterThan'
          threshold: memoryThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: SQL DTU High ───────────────────────────────────────
resource alertSqlDtu 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(sqlServerId)) {
  name: 'alert-${base}-sql-dtu'
  location: 'global'
  tags: tags
  properties: {
    description: 'SQL Server DTU consumption is high'
    severity: 2
    enabled: true
    scopes: [ sqlServerId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighDTU'
          metricName: 'dtu_consumption_percent'
          operator: 'GreaterThan'
          threshold: sqlDtuThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: Redis Memory High ──────────────────────────────────
resource alertRedis 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(redisId)) {
  name: 'alert-${base}-redis-memory'
  location: 'global'
  tags: tags
  properties: {
    description: 'Redis Cache memory usage is high'
    severity: 2
    enabled: true
    scopes: [ redisId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighRedisMemory'
          metricName: 'usedmemorypercentage'
          operator: 'GreaterThan'
          threshold: redisMemoryThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Alert: Key Vault Availability ────────────────────────────
resource alertKv 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(keyVaultId)) {
  name: 'alert-${base}-kv-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Key Vault availability dropped'
    severity: 1
    enabled: true
    scopes: [ keyVaultId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'KvAvailability'
          metricName: 'Availability'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Point 3c: Alert: Key Vault Access Denied ─────────────────
resource alertKvAccessDenied 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(keyVaultId)) {
  name: 'alert-${base}-kv-access-denied'
  location: 'global'
  tags: tags
  properties: {
    description: 'Key Vault is returning access denied errors — possible unauthorized access attempt'
    severity: 1
    enabled: true
    scopes: [ keyVaultId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'KvAccessDenied'
          metricName: 'ServiceApiResult'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'StatusCode'
              operator: 'Include'
              values: [ '403' ]
            }
          ]
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Point 3a: Alert: Frontend App Availability ────────────────
resource alertFrontendAvailability 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(frontendAppId)) {
  name: 'alert-${base}-fe-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Frontend App Service availability is low'
    severity: 1
    enabled: true
    scopes: [ frontendAppId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FeAvailability'
          metricName: 'Availability'
          operator: 'LessThan'
          threshold: availabilityThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Point 3a: Alert: Backend App Availability ─────────────────
resource alertBackendAvailability 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(backendAppId)) {
  name: 'alert-${base}-be-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Backend App Service availability is low'
    severity: 1
    enabled: true
    scopes: [ backendAppId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'BeAvailability'
          metricName: 'Availability'
          operator: 'LessThan'
          threshold: availabilityThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Point 3a: Alert: Storage Account Availability ─────────────
resource alertStorageAvailability 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(storageAccountId)) {
  name: 'alert-${base}-storage-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Storage Account availability is low'
    severity: 1
    enabled: true
    scopes: [ storageAccountId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'StorageAvailability'
          metricName: 'Availability'
          operator: 'LessThan'
          threshold: availabilityThresholdPercent
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

// ── Point 3b: Alert: HTTP 5xx errors (Log Analytics query) ────
// Uses scheduled query rule — more powerful than metric alerts
resource alertHttp5xx 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = if (!empty(logAnalyticsId)) {
  name: 'alert-${base}-http-5xx'
  location: resourceGroup().location
  tags: tags
  properties: {
    description: 'HTTP 5xx error rate is high — backend application errors'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [ logAnalyticsId ]
    criteria: {
      allOf: [
        {
          query: 'AppRequests | where ResultCode startswith "5" | summarize ErrorCount = count() by bin(TimeGenerated, 5m) | where ErrorCount > ${http5xxThreshold}'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [ actionGroup.id ]
    }
  }
}

output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
