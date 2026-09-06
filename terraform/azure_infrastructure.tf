# --------------------------------------------------------------------------------------------------
# AZURE INFRASTRUCTURE: RESOURCE GROUP, VNET INJECTION & ADLS GEN2 HIERARCHICAL STORAGE
# Mosaic Healthcare Multi-Cloud Production Platform
# --------------------------------------------------------------------------------------------------

# --- Azure Resource Group ---
resource "azurerm_resource_group" "mosaic_rg" {
  name     = var.azure_resource_group_name
  location = var.azure_region

  tags = {
    Environment = var.environment
    Project     = "Mosaic-Healthcare-Platform"
    Compliance  = "HIPAA-HITRUST"
    ManagedBy   = "Terraform"
  }
}

# --- Azure Key Vault for CMK Encryption ---
resource "azurerm_key_vault" "mosaic_kv" {
  name                        = "${var.organization_prefix}-kv-${var.environment}"
  location                    = azurerm_resource_group.mosaic_rg.location
  resource_group_name         = azurerm_resource_group.mosaic_rg.name
  tenant_id                   = var.azure_tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  enabled_for_disk_encryption = true

  tags = {
    Environment = var.environment
    Compliance  = "HIPAA-KeyVault"
  }
}

# --- Azure Virtual Network for Databricks VNet Injection ---
resource "azurerm_virtual_network" "databricks_vnet" {
  name                = "${var.organization_prefix}-vnet-${var.environment}"
  location            = azurerm_resource_group.mosaic_rg.location
  resource_group_name = azurerm_resource_group.mosaic_rg.name
  address_space       = [var.azure_vnet_cidr]

  tags = {
    Environment = var.environment
  }
}

# --- Network Security Group with HIPAA Isolation Rules ---
resource "azurerm_network_security_group" "databricks_nsg" {
  name                = "${var.organization_prefix}-databricks-nsg-${var.environment}"
  location            = azurerm_resource_group.mosaic_rg.location
  resource_group_name = azurerm_resource_group.mosaic_rg.name

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

# --- Delegated Host Subnet (Driver Node) ---
resource "azurerm_subnet" "host_subnet" {
  name                 = "${var.organization_prefix}-host-subnet"
  resource_group_name  = azurerm_resource_group.mosaic_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefixes     = [var.azure_host_subnet_cidr]

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

# --- Delegated Container Subnet (Worker Nodes) ---
resource "azurerm_subnet" "container_subnet" {
  name                 = "${var.organization_prefix}-container-subnet"
  resource_group_name  = azurerm_resource_group.mosaic_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefixes     = [var.azure_container_subnet_cidr]

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

# --- Azure Data Lake Storage Gen2 (ADLS Gen2) Account ---
resource "azurerm_storage_account" "mosaic_adls" {
  name                     = "${var.organization_prefix}adls${var.environment}"
  resource_group_name      = azurerm_resource_group.mosaic_rg.name
  location                 = azurerm_resource_group.mosaic_rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant for healthcare disaster recovery
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # Hierarchical Namespace enabled for Delta Lake
  min_tls_version          = "TLS1_2"

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

# --- ADLS Gen2 File Systems (Medallion Layers) ---
resource "azurerm_storage_data_lake_gen2_filesystem" "medallion_containers" {
  for_each           = toset(var.medallion_tiers)
  name               = each.key
  storage_account_id = azurerm_storage_account.mosaic_adls.id
}
