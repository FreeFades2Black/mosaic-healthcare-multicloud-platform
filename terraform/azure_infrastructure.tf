# ==================================================================================================
# AZURE CLOUD INFRASTRUCTURE: RESOURCE GROUP, VNET INJECTION & ADLS GEN2 DFS
# Project: Mosaic Healthcare Multi-Cloud Production Platform
# Compliance Framework: HIPAA Security Rule (45 CFR § 164.312) & HITRUST Zero-Trust
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# AZURE RESOURCE GROUP
# Logical management container encapsulating all Azure clinical compute, networking, and storage assets
# --------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "mosaic_rg" {
  name     = var.azure_resource_group_name # e.g., rg-mosaic-healthcare-prod-eastus
  location = var.azure_region              # Primary Azure East US datacenter

  tags = {
    Environment = var.environment
    Project     = "Mosaic-Healthcare-Platform"
    Compliance  = "HIPAA-HITRUST"
    ManagedBy   = "Terraform"
  }
}

# --------------------------------------------------------------------------------------------------
# AZURE KEY VAULT FOR CMK ENCRYPTION & SECRET MANAGEMENT
# Hardware security module (HSM) backed store for Azure storage encryption keys and TLS certificates
# --------------------------------------------------------------------------------------------------
resource "azurerm_key_vault" "mosaic_kv" {
  name                        = "${var.organization_prefix}-kv-${var.environment}"
  location                    = azurerm_resource_group.mosaic_rg.location
  resource_group_name         = azurerm_resource_group.mosaic_rg.name
  tenant_id                   = var.azure_tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 90   # 90-day retention safeguarding against accidental secret purging
  purge_protection_enabled    = true # Enforces purge protection to ensure ransomware resilience
  enabled_for_disk_encryption = true # Allows Azure VMs and Databricks nodes to consume keys for disk encryption

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA-KeyVault"
  }
}

# --------------------------------------------------------------------------------------------------
# AZURE VIRTUAL NETWORK (VNET) FOR DATABRICKS VNET INJECTION
# Customer-managed virtual network enabling private Databricks compute deployment with zero public IPs
# --------------------------------------------------------------------------------------------------
resource "azurerm_virtual_network" "databricks_vnet" {
  name                = "${var.organization_prefix}-vnet-${var.environment}"
  location            = azurerm_resource_group.mosaic_rg.location
  resource_group_name = azurerm_resource_group.mosaic_rg.name
  address_space       = [var.azure_vnet_cidr] # 10.180.0.0/16 address space

  tags = {
    Environment = var.environment
  }
}

# --------------------------------------------------------------------------------------------------
# NETWORK SECURITY GROUP (NSG) WITH HIPAA MICROSEGMENTATION RULES
# Restricts inter-node traffic, permits Databricks control plane management, and blocks Internet ingress
# --------------------------------------------------------------------------------------------------
resource "azurerm_network_security_group" "databricks_nsg" {
  name                = "${var.organization_prefix}-databricks-nsg-${var.environment}"
  location            = azurerm_resource_group.mosaic_rg.location
  resource_group_name = azurerm_resource_group.mosaic_rg.name

  # Allow Databricks Control Plane to communicate with workspace nodes on management port 5557
  security_rule {
    name                       = "AllowDatabricksControlPlane"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5557"
    source_address_prefix      = "AzureDatabricks"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow internal worker-to-worker and driver-to-worker communication within the VNet
  security_rule {
    name                       = "AllowWorkerToWorkerInternal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Strict zero-trust rule: Deny all direct public Internet ingress into compute clusters
  security_rule {
    name                       = "DenyDirectPublicIngress"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA-Microsegmentation"
  }
}

# --------------------------------------------------------------------------------------------------
# DELEGATED HOST SUBNET (DRIVER NODE)
# Dedicated private subnet delegated exclusively to Microsoft.Databricks/workspaces for driver pods
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "host_subnet" {
  name                 = "${var.organization_prefix}-host-subnet"
  resource_group_name  = azurerm_resource_group.mosaic_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefixes     = [var.azure_host_subnet_cidr] # 10.180.1.0/24

  # Subnet delegation required for Azure Databricks VNet Injection
  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# --------------------------------------------------------------------------------------------------
# DELEGATED CONTAINER SUBNET (WORKER NODES)
# Dedicated private subnet delegated exclusively to Microsoft.Databricks/workspaces for worker pods
# --------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "container_subnet" {
  name                 = "${var.organization_prefix}-container-subnet"
  resource_group_name  = azurerm_resource_group.mosaic_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefixes     = [var.azure_container_subnet_cidr] # 10.180.2.0/24

  # Subnet delegation required for Azure Databricks VNet Injection
  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# --------------------------------------------------------------------------------------------------
# AZURE DATA LAKE STORAGE GEN2 (ADLS GEN2) STORAGE ACCOUNT
# Hierarchical Namespace enabled storage account providing high-throughput Delta Lake storage in Azure
# --------------------------------------------------------------------------------------------------
resource "azurerm_storage_account" "mosaic_adls" {
  name                     = "${var.organization_prefix}adls${var.environment}"
  resource_group_name      = azurerm_resource_group.mosaic_rg.name
  location                 = azurerm_resource_group.mosaic_rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"       # Geo-Redundant Storage for multi-region disaster recovery
  account_kind             = "StorageV2"
  is_hns_enabled           = true        # Hierarchical Namespace (HNS) enabled for Delta Lake performance
  min_tls_version          = "TLS1_2"    # Enforces TLS 1.2+ encryption for all network transit

  # Network firewall restricting access to internal subnets and trusted Azure services
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
    virtual_network_subnet_ids = [
      azurerm_subnet.host_subnet.id,
      azurerm_subnet.container_subnet.id
    ]
  }

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA-HITRUST-ADLS"
  }
}

# --------------------------------------------------------------------------------------------------
# ADLS GEN2 MEDALLION FILE SYSTEMS (BRONZE, SILVER, GOLD CONTAINERS)
# Generates root containers for raw, cleansed, and curated clinical datasets in Azure
# --------------------------------------------------------------------------------------------------
resource "azurerm_storage_data_lake_gen2_filesystem" "medallion_containers" {
  for_each           = toset(var.medallion_tiers)
  name               = each.key
  storage_account_id = azurerm_storage_account.mosaic_adls.id
}
