# Intune PoC — Terraform configuration
# Author: Evelyn Schmid
# Version: 1.0
# Creation date: 2026-05-11
#
# What this manages:
# - Entra groups + user
# - Windows compliance policy
# - Autopilot deployment profile + assignment
# - Win32 app deployment (Chocolatey)
# - Custom Enrollment Status Page
#
#
#
# => Important page for later import of existing intune resources!!!! https://developer.hashicorp.com/terraform/cli/import


#Terraform settings block
terraform {
    required_providers {                                    #List of all used providers to make this happen
        azurerm = {                                         #azurerm lets Terraform manage Azure resources (resource groups, VMs, etc.). Authentication via Service Principal. Permissions must be granted there.
            source  = "hashicorp/azurerm"                   #Source where the provider was downloaded from.
            version = "~> 3.0"                              #Allow any 3.x version, but not 4.x.
        }
        azuread = {                                        #azuread lets Terraform manage Entra ID objects (used here for groups, users, and group memberships).
            source  = "hashicorp/azuread"                  #Source where the provider was downloaded from.
            version = "~> 3.0"                             #Allow any 3.x version, but not 4.x.
        }
        microsoft365wp = {                                 #microsoft365wp lets Terraform manage microsoft365 object. In this case, Intune objects like:
                                                           #Compliance policies, Autopilot profiles, assignment of Autopilot profiles to device groups, win32 Chocolatey app deployment and its assignment and the deployment of the ESP profile.
            source  = "terraprovider/microsoft365wp"       #Source where the provider was downloaded from.
            version = "~> 0.1"                             #Allow any 0.1.x version, but not 0.2.x.
        }
    }
}

#Provider configuration block. Runtime settings for each provider.
#Empty means "User defaukt" settings.
provider "azurerm" {
    features {}                                           #Required empty block for azurerm. This enables the default Azure features.
}

provider "azuread" {}                                     #azuread is needed to creat Entra ID groups and Entra ID user plus their mememberships. The provider gets here activated with default settings. (auth + tenant taken from environ1ment / Azure CLI / Service Principal)

provider "microsoft365wp" {}                              #microsoft365wp is needed to create intune objects. It's activated with default settings.

resource "azurerm_resource_group" "terraform-intune-poc" {  #Creates the Azure resource group that acts as a container for all resources deployed by this script.
    name     = "terraform-intune-poc"                       #Name of the resource group in Azure
    location = "switzerlandnorth"                           #Azure region where the resource group live
}

resource "microsoft365wp_device_compliance_policy" "DG_Win1x_Default" {     #Creates as Intune compliance policy for Windows 10/11 devices.
    display_name = "DG_Win1x_Default"                                       #Name of the policy as it appears in the Intune portal
    description  = "Default compliance policy for all Windows devices"      #Description shown in the Intune portal

    windows10 = {                                                           #Settings for the compliance policy to check on windows company managed devices.
        bitlocker_enabled                          = true
        secure_boot_enabled                        = true
        code_integrity_enabled                     = true
        firewall_enabled                           = true
        tpm_required                               = true
        defender_enabled                           = true
        os_minimum_version                         = "10.0.22631"
        password_required                          = true
        password_block_simple                      = true
        password_minimum_length                    = 8
        password_expiration_days                   = 365
        password_previous_password_block_count     = 3
        password_minutes_of_inactivity_before_lock = 15
    }

    scheduled_actions_for_rule = [
        {
            scheduled_action_configurations = [
                {
                    action_type        = "block"
                    grace_period_hours = 0
                }
            ]
        }
    ]
}

/*
resource "microsoft365wp_device_compliance_policy" "DG_Linux_Base" {        #Template for future Linux compliance policy
}
*/

/*
resource "microsoft365wp_device_compliance_policy" "DG_MacOS_Default" {     #Template for future Mac OS compliance policy
}
*/

resource "azuread_group" "DR_Intune_Users_PD" {                             #Azure Group-object "DG-Intune-Users-PD" has been created
    display_name     = "DG-Intune-Users-PD"
    security_enabled = true
    mail_enabled     = false
}

resource "azuread_group" "DG_Intune_Users_All" {                             #Azure Group-object "DG-Intune-Users-All" has been created
    display_name     = "DG-Intune-Users-All"
    security_enabled = true
    mail_enabled     = false
}

resource "azuread_group" "DG_Intune_LocalAdmin_CH" {                          #Azure Group-object "DG_Intune_LocalAdmin_CH" has been created
    display_name     = "DG_Intune_LocalAdmin_CH"
    security_enabled = true
    mail_enabled     = false
}

resource "azuread_group" "DG_Intune_CM_NBS_CH_Devices" {                      #Azure Group-object "DG-Intune-CM-NBS-CH-Devices" has been created
    display_name     = "DG-Intune-CM-NBS-CH-Devices"
    security_enabled = true
    mail_enabled     = false
}

resource "azuread_user" "george_balla" {                                        #Azure User-object "George Balla" has been created
    display_name        = "George Balla"
    user_principal_name = "george.balla@evelynschmidhotmail.onmicrosoft.com"
    mail_nickname       = "george.balla"
    password            = "P@ssw0rd123!"
}

resource "azuread_group_member" "george_localadmin" {                           #User Gorge Balla assigned to group local admin
    group_object_id  = azuread_group.DG_Intune_LocalAdmin_CH.object_id
    member_object_id = azuread_user.george_balla.object_id
}

resource "microsoft365wp_azure_ad_windows_autopilot_deployment_profile" "DG_CH_NBS_UserDrivenAAD" {     #Creates a new Windows Autopilot deployment profile
    display_name            = "DG_CH_NBS_UserDrivenAAD"
    locale                  = "de-CH"
    device_name_template    = "DG-CH-NBS-%RAND:5%"
    preprovisioning_allowed = true

    out_of_box_experience_setting = {
        eula_hidden             = true
        privacy_settings_hidden = true
        escape_link_hidden      = true
        user_type               = "standard"
    }
}

resource "microsoft365wp_azure_ad_windows_autopilot_deployment_profile_assignment" "DG_CH_NBS_assignment" {     #Assigns the Autopilot deployment profile to a device group
    azure_ad_windows_autopilot_deployment_profile_id = microsoft365wp_azure_ad_windows_autopilot_deployment_profile.DG_CH_NBS_UserDrivenAAD.id
    target = { group = { group_id = azuread_group.DG_Intune_CM_NBS_CH_Devices.object_id } }
}

/*
resource "microsoft365wp_device_management_configuration_policy_json" "DG_LAN_SOLO" {           #Creats the device configurion to set up the WiFi Lan_Solo on all assigned devices.
    name = "DG_LAN-SOLO"
    platforms = "windows10"
    technologies = "mdm"
    settings = [
        SSID = "LAN SOLO"
        Connect_automatically = true
        Security = WPAPersonal
        Metered = false
    ]
}
*/

/*
resource "microsoft365wp_mobile_app" "chocolatey" {                         #Creates the app deployement for chocolety on all windows company managed devices.
    display_name = "Chocolatey"
    description = "Chocolatey Package Manager"
    publisher = "Chocolatey"
    notes = "Manual package"
    
    win32_lob_app = {
        install_command_line = "powershell.exe -executionpolicy bypass .\\install.ps1"
        uninstall_command_line = "powershell.exe -executionpolicy bypass .\\install.ps1"

        install_experience = {
            run_as_account = "system"
            device_restart_behavior = "allow"
        }

        return_codes = [
            { return_code = 0, type = "success" },
            { return_code = 1707, type = "success" },
            {return_code = 3010, type = "softReboot" },
            { return_code = 1641, type = "hardReboot" },
            { return_code = 1618, type = "retry" },
        ]

        minimum_supported_operating_system = {
            v10_1607 = true
        }

        detection_rules = [
            {
                file_system = {
                    path = "c:\\ProgramData"
                    file_or_folder_name = "Chocolatey"
                    detection_type = "exists"
                    check_32_bit_on_64_system = false
                }
            }
        ]

        #Todo: replace witht he actual .intunewin path=> source_file = "./apps/chocolatey/chocolatey.intunewin"?
    }
}


resource "microsoft365wp_mobile_app_assignment" "chocolatey_required_devices" {         #Assigns Chocolatey as requiered to all company managed in specific device group.
    mobile_app_id = microsoft365wp_mobile_app.chocolatey.id
    intent = "required"

    target = {
        group = {
            group_id = azuread_group.DG_Intune_CM_NBS_CH_Devices.object_id
            }
    }
}


resource "microsoft365wp_mobile_app_assignment" "chocolatey_available_users" {              #Makes Chocolatey available for all user in specific group.
    mobile_app_id = microsoft365wp_mobile_app.chocolatey.id
    intent = "available"

    target = {
        group = {
            group_id = azuread_group.DG_Intune_Users_All.object_id
        }
    }
}

resource "microsoft365wp_device_enrollment_configuration" "DG_ESP_Default" {                    #Creates the Enrollment Status Page (ESP) shown during Autopilot setup on Windows Devices.
    display_name = "DG_ESP_Default"
    description = "Default Enrollment Status Page Profile for Windows Autopilot devices"
    priority = 1

    windows10_esp = {
        show_installation_progress = true
        install_progress_timeout_in_minutes = 60
        custom_error_message = "yoyoyo, setup is taking longer than expected. Unfortunatelly, you ahve to sit with it. there's nobody to contact."
        allow_log_collection_on_install_failure = true
        track_install_progress_for_autopilot_only = true
    }

    assignments = [
        {
            target = {
                group = {
                    group_id = azuread_group.DG_Intune_CM_NBS_CH_Devices.object_id
                }
            }
        }
    ]
}
*/