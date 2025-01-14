provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "random_pet" "avd" {
  length    = 2
  separator = ""
}

data "azurerm_subscription" "current" {}

##############################################
# AZURE IMAGE BUILDER
##############################################

resource "azurerm_resource_group" "avd" {
  name     = "rg-${random_pet.avd.id}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "avd" {
  name                = "msi-${random_pet.avd.id}"
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  tags                = var.tags
}

resource "azurerm_role_definition" "avd" {
  name        = "role-${random_pet.avd.id}"
  scope       = data.azurerm_subscription.current.id
  description = "Azure Image Builder access to create resources for the image build"

  permissions {
    actions = [
      "Microsoft.Compute/galleries/read",
      "Microsoft.Compute/galleries/images/read",
      "Microsoft.Compute/galleries/images/versions/read",
      "Microsoft.Compute/galleries/images/versions/write",
      "Microsoft.Compute/images/write",
      "Microsoft.Compute/images/read",
      "Microsoft.Compute/images/delete"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
    azurerm_resource_group.avd.id
  ]
}

resource "azurerm_role_assignment" "avd" {
  scope              = azurerm_resource_group.avd.id
  role_definition_id = azurerm_role_definition.avd.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.avd.principal_id
}

resource "azurerm_shared_image_gallery" "avd" {
  name                = "sig${random_pet.avd.id}"
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  tags                = var.tags
}

resource "azurerm_shared_image" "avd" {
  name                = "avd-${random_pet.avd.id}"
  gallery_name        = azurerm_shared_image_gallery.avd.name
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  os_type             = "Windows"
  #hyper_v_generation  = "V2"

  identifier {
    publisher = var.publisher
    offer     = var.offer
    sku       = "avd-${random_pet.avd.id}"
  }
}

##############################################
# AZURE FILES
##############################################

resource "azurerm_storage_account" "avd" {
  name                     = "sa${random_pet.avd.id}"
  resource_group_name      = azurerm_resource_group.avd.name
  location                 = azurerm_resource_group.avd.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "LRS"
  allow_blob_public_access = false
}

resource "azurerm_storage_share" "avd" {
  name                 = "profiles"
  storage_account_name = azurerm_storage_account.avd.name
  quota                = 100
}

#################################################
# AZURE EVENT GRID FOR SECURE AIB
#################################################

data "azuread_group" "aib" {
  display_name     = "AIB"
  security_enabled = true
}

resource "azurerm_storage_account" "avd_installs" {
  name                     = "sa${random_pet.avd.id}installs"
  resource_group_name      = azurerm_resource_group.avd.name
  location                 = azurerm_resource_group.avd.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_storage_account.avd_installs.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_group.aib.object_id
}

resource "azurerm_storage_account" "avd_func" {
  name                     = "func${random_pet.avd.id}storage"
  resource_group_name      = azurerm_resource_group.avd.name
  location                 = azurerm_resource_group.avd.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_application_insights" "avd" {
  name                = "func${random_pet.avd.id}-appinsights"
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  application_type    = "web"
}

resource "azurerm_app_service_plan" "avd" {
  name                = "func${random_pet.avd.id}-plan"
  resource_group_name = azurerm_resource_group.avd.name
  location            = azurerm_resource_group.avd.location
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "avd" {
  name                       = "func${random_pet.avd.id}"
  resource_group_name        = azurerm_resource_group.avd.name
  location                   = azurerm_resource_group.avd.location
  app_service_plan_id        = azurerm_app_service_plan.avd.id
  storage_account_name       = azurerm_storage_account.avd_func.name
  storage_account_access_key = azurerm_storage_account.avd_func.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME              = "powershell"
    FUNCTIONS_WORKER_RUNTIME_VERSION      = "~7"
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.avd.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.avd.connection_string
  }

  version = "~3"
}

resource "azurerm_role_assignment" "avd_func" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_function_app.avd.identity[0].principal_id
}

resource "azurerm_eventgrid_system_topic" "avd" {
  name                   = "eg-${random_pet.avd.id}Topic"
  resource_group_name    = azurerm_resource_group.avd.name
  location               = "Global"
  source_arm_resource_id = data.azurerm_subscription.current.id
  topic_type             = "Microsoft.Resources.Subscriptions"
}

# this cannot be done until the function app has been deployed
resource "azurerm_eventgrid_system_topic_event_subscription" "avd" {
  name                  = "eg-${random_pet.avd.id}Subscription"
  resource_group_name   = azurerm_resource_group.avd.name
  system_topic          = azurerm_eventgrid_system_topic.avd.name
  event_delivery_schema = "EventGridSchema"

  included_event_types = [
    "Microsoft.Resources.ResourceWriteSuccess"
  ]

  advanced_filter {
    string_contains {
      key = "data.resourceProvider"
      values = [
        "Microsoft.Compute"
      ]
    }

    string_contains {
      key = "data.operationName"
      values = [
        "Microsoft.Compute/virtualMachines/write"
      ]
    }

    string_contains {
      key = "data.authorization.evidence.principalId"
      values = [
        azurerm_user_assigned_identity.avd.principal_id
      ]
    }
  }

  azure_function_endpoint {
    function_id                       = "${azurerm_function_app.avd.id}/functions/AIBIdentity"
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }
}

# resource "azurerm_automation_account" "avd" {
#   name                = "aa-${random_pet.avd.id}"
#   location            = azurerm_resource_group.avd.location
#   resource_group_name = azurerm_resource_group.avd.name

#   sku_name = "Basic"
# }

