// ============================================================
// modules/redis.bicep
// CAF name: redis-sbm-{env}-cin
// ============================================================

param location string
param base string
param redisSku string = 'C1'
param redisFamily string = 'C'
param redisCapacity int = 1
param tags object

var redisCacheName = 'redis-${base}'

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisCacheName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard'
      family: redisFamily
      capacity: redisCapacity
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

output redisCacheId string = redisCache.id
output redisCacheName string = redisCache.name
output redisCacheHostName string = redisCache.properties.hostName
output redisPrimaryKey string = redisCache.listKeys().primaryKey
output redisConnectionString string = '${redisCache.properties.hostName}:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
