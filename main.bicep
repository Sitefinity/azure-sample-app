@description('Name of Azure Website')
param siteName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of Azure App Service Plan')
param hostingPlanName string

@minValue(1)
@maxValue(3)
@description('App Service Plan\'s instance count')
param appServicePlanInstances int = 1

@description('App Service Plan\'s pricing tier.')
param appServicePlanTier string = 'S3'

@description('SQL Azure DB Server name')
param sqlServerName string

@description('SQL Azure DB administrator username')
param administratorLogin string

@description('SQL Azure DB administrator password')
@secure()
param administratorLoginPassword string

@description('Database name')
param databaseName string

resource sqlServerName_resource 'Microsoft.Sql/servers@2014-04-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlServerName_databaseName 'Microsoft.Sql/servers/databases@2014-04-01' = {
  parent: sqlServerName_resource
  name: databaseName
  location: location
  properties: {
    edition: 'Standard'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: '21474836480'
    requestedServiceObjectiveId: '455330e1-00cd-488b-b5fa-177c226f28b7'
  }
}

resource sqlServerName_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallrules@2014-04-01' = {
  parent: sqlServerName_resource
  name: 'AllowAllWindowsAzureIps'
  
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource hostingPlanName_resource 'Microsoft.Web/serverfarms@2021-01-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: appServicePlanTier
    capacity: appServicePlanInstances
  }
}

resource siteName_resource 'Microsoft.Web/sites@2021-01-01' = {
  name: siteName
  location: resourceGroup().location
  tags: {
    'hidden-related:/subscriptions/${subscription().subscriptionId}/resourcegroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/${hostingPlanName}': 'empty'
  }
  properties: {
    
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourcegroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/${hostingPlanName}'
  }
  dependsOn: [
    hostingPlanName_resource
  ]
}

resource siteName_web 'Microsoft.Web/Sites/sourcecontrols@2015-08-01' = {
  parent: siteName_resource
  location: location
  name: 'web'
  properties: {
    repoUrl: 'https://github.com/Sitefinity/azure-sample-app'
    branch: 'master'
    isManualIntegration: true
  }
}

resource siteName_connectionstrings 'Microsoft.Web/sites/config@2021-01-01' = {
  parent: siteName_resource
  name: 'connectionstrings'
  properties: {
    defaultConnection: {
     
      value: 'Data Source=tcp:${sqlServerName_resource.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databaseName};User Id=${administratorLogin}@${sqlServerName};Password=${administratorLoginPassword};'
      type: 'SQLAzure'
    }
  }
  dependsOn: [
    siteName_web
    sqlServerName_databaseName
  ]
}

resource siteName_appsettings 'Microsoft.Web/sites/config@2021-01-01' = {
  parent: siteName_resource
  name: 'appsettings'
  
  properties: {
    'sf-env:ConnectionStringParams:defaultConnection': 'Backend=azure'
    'sf-env:ConnectionStringName': 'defaultConnection'
  }
}
