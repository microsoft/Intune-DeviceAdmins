# Intune Deletion Automation

Powershell script used to delete objects from Intune. It works by getting a Graph API token using an MSI Client Id and deletes an Intune object using the Graph API.

## Prerequisites

- To delete Intune Mobile Apps, MSI should have Graph API permission: **DeviceManagementApps.ReadWrite.All**
- To delete Intune Device Configuration Profiles or Group Policy Configurations, MSI should have Graph API permission: **DeviceManagementConfiguration.ReadWrite.All**
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Delete-IntuneObjects.ps1
2. Manually configure the following variables for your own environment:
   - MobileAppClientId: Azure MSI Client Id used to get the Graph API access token
   - DeviceConfigProfileClientId: Azure MSI Client Id used to get the Graph API access token
   - GroupPolicyClientId: Azure MSI Client Id used to get the Graph API access token
   - MobileAppId: The Intune Mobile Application Id being deleted
   - DeviceConfigurationProfileId: The Intune Device Configuration Profile Id being deleted
   - GroupPolicyConfigurationId: The Intune Group Policy Configuration Id being deleted
3. Run the Powershell script

## Notes

The Intune Deletion Automation script was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft.
