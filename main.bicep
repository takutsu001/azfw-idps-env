targetScope = 'subscription'

/*
------------------
param section
------------------
*/
// ---- param for Common ----
param resourceGroupName string
param resourceGroupLocation string
param myipaddress string

// ----param for Hub----
param hubVNetName string
param hubVNetAddress string
// VM Subnet
param hubSubnetName1 string 
param hubSubnetAddress1 string
// Firewall Subnet
param hubSubnetName2 string 
param hubSubnetAddress2 string
// Jump Subnet
param hubSubnetName3 string 
param hubSubnetAddress3 string

// ---- param for Azure Firewall ----
param firewallName string

// ----param for VM----
param vmSizeLinux string
param hubvmName1 string
param hubvmName2 string
@secure()
param adminUserName string
@secure()
param adminPassword string

// ----param for Azure Storage----
param baseStorageAccountName string

// ----param for Log Analytics workspace----
param workspaceName string

/*
------------------
resource section
------------------
*/

resource newRG 'Microsoft.Resources/resourceGroups@2021-04-01' = { 
  name: resourceGroupName 
  location: resourceGroupLocation 
} 

/*
---------------
module section
---------------
*/

// Create Hub Environment (VM-Linux VNet, Subnet, NSG, LAW)
module HubModule './modules/hubEnv.bicep' = { 
  scope: newRG 
  name: 'CreateHubEnv' 
  params: { 
    location: resourceGroupLocation
    hubVNetName: hubVNetName
    hubVNetAddress: hubVNetAddress
    myipaddress: myipaddress
    hubSubnetName1: hubSubnetName1
    hubSubnetAddress1: hubSubnetAddress1
    hubSubnetName2: hubSubnetName2
    hubSubnetAddress2: hubSubnetAddress2
    hubSubnetName3: hubSubnetName3
    hubSubnetAddress3: hubSubnetAddress3
    hubvmName1: hubvmName1
    hubvmName2: hubvmName2
    vmSizeLinux: vmSizeLinux
    adminUserName: adminUserName
    adminPassword: adminPassword
    firewallName: firewallName
    baseStorageAccountName: baseStorageAccountName
    workspaceName: workspaceName
  } 
}
