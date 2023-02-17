<#
.SYNOPSIS
    Verify Delete Intune Mobile Apps, Device Configuration Profiles, and Group Policy Configurations
.DESCRIPTION
    Powershell script used to verify objects exist in Intune before deletion. 
    It works by getting a Graph API token using an MSI Client Id
    and verifies Intune objects exist using the Graph API.
.PARAMETER MobileAppClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Mobile Apps
.PARAMETER DeviceConfigProfileClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Device Configuration Profiles
.PARAMETER GroupPolicyClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Group Policy Configurations
.PARAMETER MobileAppId
    The Intune Mobile Application Id being verified
.PARAMETER DeviceConfigurationProfileId
    The Intune Device Configuration Profile Id being verified
.PARAMETER GroupPolicyConfigurationId
    The Intune Group Policy Configuration Id being verified
.NOTES
    Version:        1.0
    Creation date:  2/6/2023
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

function Verify-IntuneMobileApp {
    param(
            $MobileAppId
        )
    try 
    {
        $MobileAppClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementApps.Read.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($MobileAppClientId)"
        $AppHeaders = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $MobileAppClientId
        $AppGraphUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($mobileAppId)"
        Write-Output "Getting Mobile app using Url: $($AppGraphUrl)"
        $MobileApp = Invoke-RestMethod -Uri $AppGraphUrl -Method Get -Headers $AppHeaders
        if($MobileApp) 
        {
            $MobileAppName = $MobileApp.displayName
            Write-Output "Successfully found Intune Mobile App - $($MobileAppName) with MobileAppId - $($MobileAppId) in Intune" 
        }
        else
        {
            Write-Output "Intune Mobile Application with mobileAppId: $($mobileAppId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Mobile App Verify Deletion Failed with id: $($MobileAppId)"
        Write-Error $_.Exception.Message
    }
}

function Verify-IntuneDeviceConfigurationProfile { 
    param(
            $DeviceConfigProfileId
        )
    try 
    {
        $DeviceConfigProfileClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementConfiguration.Read.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($DeviceConfigProfileClientId)"
        $DeviceConfigProfileHeaders = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $DeviceConfigProfileClientId
        $DeviceConfigProfileGraphUrl = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/$($DeviceConfigProfileId)"
        Write-Output "Getting Device Configuration Profile using Url: $($DeviceConfigProfileGraphUrl)"
        $DeviceConfigProfile = Invoke-RestMethod -Uri $DeviceConfigProfileGraphUrl -Method Get -Headers $DeviceConfigProfileHeaders
        if($DeviceConfigProfile) 
        {
            $DeviceConfigProfileName = $DeviceConfigProfile.displayName
            Write-Output "Successfully found Intune Device Configuration Profile - $($DeviceConfigProfileName) with DeviceConfigProfileId - $($DeviceConfigProfileId) in Intune" 
        }
        else
        {
            Write-Output "Intune Device Configuration Profile with DeviceConfigProfileId: $($DeviceConfigProfileId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Device Configuration Profile Verify Deletion Failed with id: $($DeviceConfigProfileId)"
        Write-Error $_.Exception.Message
    }
}

function Verify-IntuneGroupPolicy {

    param(
            $GroupPolicyConfigurationId
        )
    try 
    {
        $GroupPolicyClientId = "" #Enter your Client Id for getting access token
        #This Client Id must have Graph API permission: DeviceManagementConfiguration.Read.All
        
        Write-Output "Getting microsoft graph api access headers using client id - $($GroupPolicyClientId)"
        $GroupPolicyHeaders = Get-MsiAuthHeaders -ResourceUri "https://graph.microsoft.com" -ClientId $GroupPolicyClientId
        $GroupPolicyConfigurationUrl = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($GroupPolicyConfigurationId)"
        Write-Output "Getting Group Policy Configuration using Url: $($GroupPolicyConfigurationUrl)"
        $GroupPolicy = Invoke-RestMethod -Uri $GroupPolicyConfigurationUrl -Method Get -Headers $GroupPolicyHeaders
        if($GroupPolicy) 
        {
            $GroupPolicyName = $GroupPolicy.displayName
            Write-Output "Successfully fouund Group Policy Configuration - $($GroupPolicyName) with GroupPolicyConfigurationId - $($GroupPolicyConfigurationId) in Intune" 
        }
        else
        {
            Write-Output "Intune Group Policy Configuration with GroupPolicyConfigurationId: $($GroupPolicyConfigurationId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Group Policy Configuration Verify Deletion Failed with id: $($GroupPolicyConfigurationId)"
        Write-Error $_.Exception.Message
    }
}

Write-Output "------------------- Starting Verify Intune Object Deletion Script -------------------"
$MobileAppId = '' #Mobile App Id to verify before deletion
$DeviceConfigurationProfileId = '' #Device Configuration Profile Id to verify before deletion
$GroupPolicyConfigurationId = '' #Group Policy Configuration Id to verify before deletion

if($MobileAppId)
{
    Verify-IntuneMobileApp -MobileAppId $MobileAppId
}

if($DeviceConfigurationProfileId)
{
    Verify-IntuneDeviceConfigurationProfile -DeviceConfigProfileId $DeviceConfigurationProfileId
}

if($GroupPolicyConfigurationId)
{
    Verify-IntuneGroupPolicy -GroupPolicyConfigurationId $DeviceGroupPolicyId
}