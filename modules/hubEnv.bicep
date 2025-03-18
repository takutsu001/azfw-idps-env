/*
------------------
param section
------------------
*/
param location string
param hubVNetName string 
param myipaddress string
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
// for Azure Firewall
param firewallName string
// for VM
param hubvmName1 string
param hubvmName2 string
param vmSizeLinux string
@secure()
param adminUserName string
@secure()
param adminPassword string
// for Azure Storage
param baseStorageAccountName string
// for Log Analytics workspace
param workspaceName string

/*
------------------
var section
------------------
*/
// VM Subnet
var hubSubnet1 = { 
  name: hubSubnetName1 
  properties: { 
    addressPrefix: hubSubnetAddress1
  }
}
// Firewall Subnet
var hubSubnet2 = { 
  name: hubSubnetName2 
  properties: { 
    addressPrefix: hubSubnetAddress2
  }
}
// Jump Subnet
var hubSubnet3 = { 
  name: hubSubnetName3 
  properties: { 
    addressPrefix: hubSubnetAddress3
    networkSecurityGroup: {
      id: nsgDefault.id
      }
  }
} 

// Get the Azure Firewall private IP
var firewallPrivateIp = azfw.properties.ipConfigurations[0].properties.privateIPAddress

// Storage Account Name
// uniqueStringの最初の5文字を取得
var uniquePart = substring(uniqueString(resourceGroup().id), 0, 5)
var storageAccountName = '${baseStorageAccountName}${uniquePart}'


/*
------------------
resource section
------------------
*/

// create network security group for hub vnet
resource nsgDefault 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: '${hubVNetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
        description: 'SSH access permission from your own PC.'
        protocol: 'TCP'
        sourcePortRange: '*'
        destinationPortRange: '22'
        sourceAddressPrefix: myipaddress
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 1000
        direction: 'Inbound'
      }
    }
  ]
}
}

// create hubVNet & hubSubnet
resource hubVNet 'Microsoft.Network/virtualNetworks@2023-04-01' = { 
  name: hubVNetName 
  location: location 
  properties: { 
    addressSpace: { 
      addressPrefixes: [ 
        hubVNetAddress 
      ] 
    } 
    subnets: [ 
      hubSubnet1
      hubSubnet2
      hubSubnet3
    ]
  }
  // Get subnet information where VMs are connected
  resource hubVMSubnet 'subnets' existing = {
    name: hubSubnetName1
  }
  // Get subnet information where Azure Firewall is connected
  resource hubFirewallSubnet 'subnets' existing = {
    name: hubSubnetName2
  }
  // Get subnet information where Jump VM is connected
  resource hubJumpSubnet 'subnets' existing = {
    name: hubSubnetName3
  }
}

// create public ip address for Azure Firewall
resource azfwPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${firewallName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Create Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-04-01' = {
  name: '${firewallName}-policy'
  location: location
  properties: {
    sku: {
      tier: 'Premium'
    }
    threatIntelMode: 'Alert'
  }
}

// create Azure Firewall in hubVNet
resource azfw 'Microsoft.Network/azureFirewalls@2023-04-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      tier: 'Premium'
      name: 'AZFW_VNet'
    }
    ipConfigurations: [
      {
        name: 'azfw-ipconfig'
        properties: {
          subnet: {
            id: hubVNet::hubFirewallSubnet.id
          }
          publicIPAddress: {
            id: azfwPublicIp.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

// Create UDR
resource routeTable 'Microsoft.Network/routeTables@2023-04-01' = {
  name: 'UDR-AFW'
  location: location
  properties: {
    routes: [
      {
        name: 'DefaultRoute-to-AFW'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

// Associate Route Table with Hub-VMSubnet
resource hubVmSubnetForUDR 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  parent: hubVNet
  name: hubSubnetName1
  properties: {
    addressPrefix: hubSubnetAddress1
    routeTable: {
      id: routeTable.id
    }
  }
}

// create VM in VMSubnet
// create network interface for Linux VM
resource networkInterface1 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${hubvmName1}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: hubVNet::hubVMSubnet.id
          }
        }
      }
    ]
  }
}

// create Linux vm in VMSubnet
resource centosVM1 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: hubvmName1
  location: location
  plan: {
    name: 'centos-8-0-free'
    publisher: 'cognosys'
    product: 'centos-8-0-free'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSizeLinux
    }
    osProfile: {
      computerName: hubvmName1
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'cognosys'
       offer: 'centos-8-0-free'
        sku: 'centos-8-0-free'
        version: 'latest'
      }
      osDisk: {
        name: '${hubvmName1}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface1.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// create VM in JumpSubnet
// create public ip address for Linux VM
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${hubvmName2}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// create network interface for Linux VM
resource networkInterface2 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${hubvmName2}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: hubVNet::hubJumpSubnet.id
          }
        }
      }
    ]
  }
}

// create Linux vm in VMSubnet
resource centosVM2 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: hubvmName2
  location: location
  plan: {
    name: 'centos-8-0-free'
    publisher: 'cognosys'
    product: 'centos-8-0-free'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSizeLinux
    }
    osProfile: {
      computerName: hubvmName2
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'cognosys'
       offer: 'centos-8-0-free'
        sku: 'centos-8-0-free'
        version: 'latest'
      }
      osDisk: {
        name: '${hubvmName2}-disk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface2.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// create Storage Account for Azure Files
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// create log analytics workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

/*
------------------
output section
------------------
*/

// return the private ip address of the vm to use from parent template
@description('return the private ip address of the vm to use from parent template')
output vmPrivateIp1 string = networkInterface1.properties.ipConfigurations[0].properties.privateIPAddress
output vmPrivateIp2 string = networkInterface2.properties.ipConfigurations[0].properties.privateIPAddress
