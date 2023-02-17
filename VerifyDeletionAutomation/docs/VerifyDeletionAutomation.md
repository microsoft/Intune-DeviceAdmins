# Verify Delete Intune Automation

Powershell script used to verify objects are in Intune. It works by getting a Graph API token using an MSI Client Id and gets the Intune object using the Graph API.

## Prerequisites

- To verify Intune Mobile Apps, MSI should have Graph API permission: **DeviceManagementApps.Read.All**
- To verify Intune Device Configuration Profiles or Group Policy Configurations, MSI should have Graph API permission: **DeviceManagementConfiguration.Read.All**
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Verify-DeleteIntuneObjects.ps1
2. Manually configure the following variables for your own environment:
   - MobileAppClientId: Azure MSI Client Id used to get the Graph API access token
   - DeviceConfigProfileClientId: Azure MSI Client Id used to get the Graph API access token
   - GroupPolicyClientId: Azure MSI Client Id used to get the Graph API access token
   - MobileAppId: The Intune Mobile Application Id being verified
   - DeviceConfigurationProfileId: The Intune Device Configuration Profile Id being verified
   - GroupPolicyConfigurationId: The Intune Group Policy Configuration Id being verified
3. Run the Powershell script

## Notes

The Verify Delete Intune Automation script was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft.
