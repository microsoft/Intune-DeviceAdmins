# Provision Win32 App

Powershell script used to Provision a Win 32 App to be uploaded to Intune. It works by getting a Graph API token using an MSI Client Id and then uploads the intunewin file into Intune.

## Prerequisites

- Windows 10 version 1607 or later (Enterprise, Pro, and Education versions)
- Client should have Graph API permission: **DeviceManagementApps.ReadWrite.All**
- Powershell ISE
- Microsoft Win32 Content Prep Tool
- Application file being uploaded to Intune

### Steps:

1. Download Microsoft Win32 Content Prep Tool
2. Run the IntuneWinAppUtil.exe and specify the following parameters: folder with setup files, path to .exe or .msi application file, and the output folder to send the .intunewin file
3. Open PowerShell ISE in elevated mode and open the following script: Provision-Win32App.ps1
4. Manually configure the following variables for your own environment:
   - ClientId: Azure MSI Client Id used to get the Graph API access token
   - SourceFile: This is the path to the Intunewin file
   - PowerShellDetectionScript: This is the path to the detection script
   - Publisher: The publisher of the application
   - Description: Description of the application
5. Modify New-DetectionRule, Get-DefaultReturnCodes, and Upload-Win32Lob function parameters as needed based on requirmements
6. Run the Powershell script

## Notes

The Provision Win32 App script was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft.
