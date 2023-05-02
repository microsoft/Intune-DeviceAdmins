# Search Proactive Remediation Scripts

Powershell script used to search through Proacive Remediation Scripts in Intune for a list of keywords.
It works by getting a Graph API token using an MSI Client Id and searches through the scripts of each
Intune object using the Graph API. An HTML Report is also generated in the local filepath with the results.

## Prerequisites

- MSI should have Graph API permission: **DeviceManagementConfiguration.Read.All**
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Search-ProactiveRemediationScripts.ps1
2. Manually configure the following variables for your own environment:
   - ClientId: Azure MSI Client Id used to get the Graph API access token
   - KeyWords: Comma separated keywords you want to search for
3. Run the Powershell script

## Notes

The Search Proactive Remediation Scripts Automation was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft.
