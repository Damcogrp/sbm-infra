// ============================================================
// modules/scheduler.bicep
// Azure Logic App — Separate scheduler service
// CAF name: logic-sbm-{env}-{region}-sched
// ============================================================

param location string
param base string
param tags object

var logicAppName = 'logic-${base}-sched'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: union(tags, { Component: 'scheduler', Purpose: 'background-job-scheduler' })
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        Recurrence: {
          recurrence: {
            frequency: 'Day'
            interval: 1
            startTime: '2026-01-01T00:00:00Z'
            timeZone: 'India Standard Time'
          }
          type: 'Recurrence'
        }
      }
      actions: {}
      outputs: {}
    }
    parameters: {}
  }
}

output logicAppId string = logicApp.id
output logicAppName string = logicApp.name
// Note: listCallbackUrl removed — not supported on Recurrence trigger type
