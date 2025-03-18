using 'main.bicep'

param resourceGroupName = 'IDPS-RG'
param resourceGroupLocation = 'japaneast'
// ---- for Firewall Rule ----
// your ip address for SSH (ex. xxx.xxx.xxx.xxx)
param myipaddress = '<Public IP your PC Address>'

// ---- param for Hub ----
param hubVNetName = 'Hub-VNet'
param hubVNetAddress = '10.0.0.0/16'
param hubSubnetName1 = 'Hub-VMSubnet'
param hubSubnetAddress1 = '10.0.0.0/24'
param hubSubnetName2 = 'AzureFirewallSubnet'
param hubSubnetAddress2 = '10.0.110.0/26'
param hubSubnetName3 = 'Hub-JumpSubnet'
param hubSubnetAddress3 = '10.0.10.0/24'
param hubvmName1 = 'hub-client'
param hubvmName2 = 'hub-jump'

// ---- param for Azure Firewall ----
param firewallName = 'hub-fw-premium'

// ---- Common param for VM ----
param vmSizeLinux = 'Standard_B2s'
param adminUserName = 'cloudadmin'
param adminPassword = 'msjapan1!msjapan1!'

// ----param for Azure Storage----
param baseStorageAccountName = 'idpswebtest'

// ----param for Log Analytics workspace----
param workspaceName = 'IDPS-LAW'
