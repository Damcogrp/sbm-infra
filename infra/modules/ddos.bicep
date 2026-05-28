// ============================================================
// modules/ddos.bicep
// DDoS Protection Standard Plan
// Deployed only when deploy_ddos_protection: true in config.yml
// Cost: ~$2,944/month — enable for PROD only
// CAF name: ddos-sbm-{env}-{region}
// ============================================================

param location string
param base string
param tags object

var ddosPlanName = 'ddos-${base}'

// ── DDoS Protection Plan ──────────────────────────────────────
resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-04-01' = {
  name: ddosPlanName
  location: location
  tags: tags
  properties: {}
}

output ddosPlanId string = ddosPlan.id
output ddosPlanName string = ddosPlan.name
