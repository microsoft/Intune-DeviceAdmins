<#
.SYNOPSIS
    Delete Intune Mobile Apps, Device Configuration Profiles, and Group Policy Configurations
.DESCRIPTION
    Powershell script used to delete objects from Intune. 
    It works by getting a Graph API token using an MSI Client Id
    and deletes an Intune object using the Graph API.
.PARAMETER MobileAppClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Mobile Apps
.PARAMETER DeviceConfigProfileClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Device Configuration Profiles
.PARAMETER GroupPolicyClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Group Policy Configurations
.PARAMETER MobileAppId
    The Intune Mobile Application Id being deleted
.PARAMETER DeviceConfigurationProfileId
    The Intune Device Configuration Profile Id being deleted
.PARAMETER GroupPolicyConfigurationId
    The Intune Group Policy Configuration Id being deleted
.NOTES
    Version:        1.0
    Creation date:  1/9/2023
    Purpose/Change: Open Source example
#>

function Get-MsiAuthHeaders
{
    param
    (
        [Parameter(Mandatory=$true)]
        [Validateset("https://graph.microsoft.com","https://vault.azure.net","https://management.azure.com","https://database.windows.net")]
        $ResourceUri,
        [Parameter(Mandatory=$true)]
        $ClientId
    )

    $msiEndpoint = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$($ResourceUri)&client_id=$($ClientId)"
    $response = Invoke-WebRequest -Uri $msiEndpoint -Headers @{"Metadata"= $true} -UseBasicParsing
    $responseJson = ConvertFrom-Json -InputObject $response
    $AccessToken = $responseJson.access_token
    $Headers =  @{
    'Content-Type'='application/json'
    'Authorization'="Bearer " + $AccessToken
   }
    return $Headers
}

function Delete-IntuneMobileApp {
    param(
            $MobileAppId
        )
    try 
    {
        $MobileAppClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementApps.ReadWrite.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($MobileAppClientId)"
        $AppHeaders = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $MobileAppClientId
        $AppGraphUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($mobileAppId)"
        Write-Output "Getting Mobile app using Url: $($AppGraphUrl)"
        $MobileApp = Invoke-RestMethod -Uri $AppGraphUrl -Method Get -Headers $AppHeaders
        if($MobileApp) 
        {
            $MobileAppName = $MobileApp.displayName
            Write-Output "Attempting to delete Intune Mobile App - $($MobileAppName) using Url - $($AppGraphUrl)"
            Invoke-RestMethod -Uri $AppGraphUrl -Headers $AppHeaders -Method Delete -ErrorAction Stop 
            Write-Output "Successfully deleted Intune Mobile App - $($MobileAppName) with MobileAppId - $($MobileAppId)" 
        }
        else
        {
            Write-Output "Intune Mobile Application with mobileAppId: $($mobileAppId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Mobile App Deletion Failed with id: $($MobileAppId)"
        Write-Error $_.Exception.Message
    }
}

function Delete-IntuneDeviceConfigurationProfile { 
    param(
            $DeviceConfigProfileId
        )
    try 
    {
        $DeviceConfigProfileClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementConfiguration.ReadWrite.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($DeviceConfigProfileClientId)"
        $DeviceConfigProfileHeaders = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $DeviceConfigProfileClientId
        $DeviceConfigProfileGraphUrl = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/$($DeviceConfigProfileId)"
        Write-Output "Getting Device Configuration Profile using Url: $($DeviceConfigProfileGraphUrl)"
        $DeviceConfigProfile = Invoke-RestMethod -Uri $DeviceConfigProfileGraphUrl -Method Get -Headers $DeviceConfigProfileHeaders
        if($DeviceConfigProfile) 
        {
            $DeviceConfigProfileName = $DeviceConfigProfile.displayName
            Write-Output "Attempting to delete Device Configuration Profile - $($DeviceConfigProfileName) using Url - $($DeviceConfigProfileGraphUrl)"
            Invoke-RestMethod -Uri $DeviceConfigProfileGraphUrl -Headers $DeviceConfigProfileHeaders -Method Delete -ErrorAction Stop 
            Write-Output "Successfully deleted Intune Device Configuration Profile - $($DeviceConfigProfileName) with DeviceConfigProfileId - $($DeviceConfigProfileId)" 
        }
        else
        {
            Write-Output "Intune Device Configuration Profile with DeviceConfigProfileId: $($DeviceConfigProfileId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Device Configuration Profile Deletion Failed with id: $($DeviceConfigProfileId)"
        Write-Error $_.Exception.Message
    }
}

function Delete-IntuneGroupPolicy {

    param(
            $GroupPolicyConfigurationId
        )
    try 
    {
        $GroupPolicyClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementConfiguration.ReadWrite.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($GroupPolicyClientId)"
        $GroupPolicyHeaders = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $GroupPolicyClientId
        $GroupPolicyConfigurationUrl = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($GroupPolicyConfigurationId)"
        Write-Output "Getting Group Policy Configuration using Url: $($GroupPolicyConfigurationUrl)"
        $GroupPolicy = Invoke-RestMethod -Uri $GroupPolicyConfigurationUrl -Method Get -Headers $GroupPolicyHeaders
        if($GroupPolicy) 
        {
            $GroupPolicyName = $GroupPolicy.displayName
            Write-Output "Attempting to delete Group Policy Configuration - $($GroupPolicyName) using Url - $($GroupPolicyConfigurationUrl)"
            Invoke-RestMethod -Uri $GroupPolicyConfigurationUrl -Headers $GroupPolicyHeaders -Method Delete -ErrorAction Stop 
            Write-Output "Successfully deleted Group Policy Configuration - $($GroupPolicyName) with GroupPolicyConfigurationId - $($GroupPolicyConfigurationId)" 
        }
        else
        {
            Write-Output "Intune Group Policy Configuration with GroupPolicyConfigurationId: $($GroupPolicyConfigurationId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Group Policy Configuration Deletion Failed with id: $($GroupPolicyConfigurationId)"
        Write-Error $_.Exception.Message
    }
}

Write-Output "------------------- Starting Delete Intune Objects Script -------------------"
$MobileAppId = '' #Mobile App Id to delete
$DeviceConfigurationProfileId = '' #Device Configuration Profile Id to delete
$GroupPolicyConfigurationId = '' #Group Policy Configuration Id to delete

if($MobileAppId)
{
    Delete-IntuneMobileApp -MobileAppId $MobileAppId
}

if($DeviceConfigurationProfileId)
{
    Delete-IntuneDeviceConfigurationProfile -DeviceConfigProfileId $DeviceConfigurationProfileId
}

if($GroupPolicyConfigurationId)
{
    Delete-IntuneGroupPolicy -GroupPolicyConfigurationId $DeviceGroupPolicyId
}