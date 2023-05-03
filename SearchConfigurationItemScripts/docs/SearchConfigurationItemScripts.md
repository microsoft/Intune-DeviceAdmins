# Search Configuration Item Scripts

Powershell script used to used to search through Configuration Item Scripts in SCCM for a list of keywords.
It works by connecting to SCCM and searches through the scripts of each Configuration Item for the keywords. An HTML Report is also generated in the local filepath with the results.

## Prerequisites

- SCCM Connection
- Powershell ISE

### Steps:

1. Open PowerShell ISE in elevated mode and open the following script: Search-ConfigurationItemScripts.ps1
2. Manually configure the following variables for your own environment:
   - SiteCode: SCCM Site Code
   - SiteServer: SCCM Site Server
   - KeyWords: Comma separated keywords you want to search for
3. Run the Powershell script

## Notes

The Search Configuration Item Scripts Automation was originally created for use inside of Microsoft. We have modified it to be more generic, so it can be used as a template for other Intune environments outside of Microsoft.
