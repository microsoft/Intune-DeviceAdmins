# Intune Assignment Removal Automation

Powershell script used to remove object assignments from Intune. It works by getting a Graph API token using an MSI Client Id and removes an Intune assignment using the Graph API.

## Prerequisites

- To remove Intune Mobile App Assignments, MSI should have Graph API permission: **DeviceManagementApps.ReadWrite.All**
- To remove Intune Device Configuration Profile or Group Policy Configuration Assignments, MSI should have Graph API permission: **DeviceManagementConfiguration.ReadWrite.All**
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Remove-IntuneAssignment.ps1
2. Manually configure the following variables for your own environment:
   - MobileAppClientId: Azure MSI Client Id used to get the Graph API access token
   - DeviceConfigProfileClientId: Azure MSI Client Id used to get the Graph API access token
   - GroupPolicyClientId: Azure MSI Client Id used to get the Graph API access token
   - MobileAppId: The Intune Mobile Application with assignment being removed
   - MobileAppAssignmentId: The Intune Mobile Application Assignment Id being removed
   - DeviceConfigurationProfileId: The Intune Device Configuration Profile with assignment being removed
   - DeviceConfigurationProfileAssignmentId: The Intune Device Configuration Profile Assignment Id being removed
   - GroupPolicyConfigurationId: The Intune Group Policy Configuration with assignment being removed
   - GroupPolicyConfigurationAssignmentId: The Intune Group Policy Configuration Assignment Id being removed
3. Run the Powershell script

## Notes

The Intune Assignment Removal Automation script was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft.
