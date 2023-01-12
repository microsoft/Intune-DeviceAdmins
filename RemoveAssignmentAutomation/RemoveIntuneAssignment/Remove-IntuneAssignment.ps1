<#
.SYNOPSIS
    Remove Intune Mobile App, Device Configuration Profile, and Group Policy Configuration assignments
.DESCRIPTION
    Powershell script used to remove object assignments from Intune. 
    It works by getting a Graph API token using an MSI Client Id
    and removes an assignment from an Intune object using the Graph API.
.PARAMETER MobileAppClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Mobile Apps
.PARAMETER DeviceConfigProfileClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Device Configuration Profiles
.PARAMETER GroupPolicyClientId
    Azure MSI Client Id used to get the Graph API access token for Intune Group Policy Configurations
.PARAMETER MobileAppId
    The Intune Mobile Application Id with the assignment being removed
.PARAMETER MobileAppAssignmentId
    The Intune Mobile Application Assignment Id being removed
.PARAMETER DeviceConfigurationProfileId
    The Intune Device Configuration Profile Id with the assignment being removed
.PARAMETER DeviceConfigurationProfileAssignmentId
    The Intune Device Configuration Profile Assignment Id being removed
.PARAMETER GroupPolicyConfigurationId
    The Intune Group Policy Configuration Id with the assignment being removed
.PARAMETER GroupPolicyConfigurationAssignmentId
    The Intune Group Policy Configuration Assignment Id being removed
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

function Remove-IntuneMobileApp {
    param(
            $MobileAppId,
            $AssignmentId
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
            $AssignmentGraphURI = "$($AppGraphUrl)/assignments/$($AssignmentId)"
            Write-Output "Attempting to remove Intune Mobile App Assignment Id - $($AssignmentId) using Url - $($AssignmentGraphURI)"
            Invoke-RestMethod -Uri $AssignmentGraphURI -Headers $AppHeaders -Method Delete -ErrorAction Stop
            Write-Output "Successfully removed Intune Mobile App Assignment Id - $($AssignmentId)" 
        }
        else
        {
            Write-Output "Intune Mobile Application with mobileAppId: $($mobileAppId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Mobile App Assignment Removal Failed with id: $($AssignmentId)"
        Write-Error $_.Exception.Message
    }
}

function Remove-IntuneDeviceConfigurationProfile { 
    param(
            $DeviceConfigProfileId,
            $AssignmentId
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
            $AssignmentGraphURI = "$($DeviceConfigProfileGraphUrl)/assignments/$($AssignmentId)"
            Write-Output "Attempting to remove Device Configuration Profile Assignment Id - $($AssignmentId) using Url - $($AssignmentGraphURI)"
            Invoke-RestMethod -Uri $AssignmentGraphURI -Headers $DeviceConfigProfileHeaders -Method Delete -ErrorAction Stop 
            Write-Output "Successfully removed Intune Device Configuration Profile Assignment Id - $($AssignmentId)" 
        }
        else
        {
            Write-Output "Intune Device Configuration Profile with DeviceConfigProfileId: $($DeviceConfigProfileId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Device Configuration Profile Assignment Removal Failed with id: $($DeviceConfigProfileId)"
        Write-Error $_.Exception.Message
    }
}

function Remove-IntuneGroupPolicy {

    param(
            $GroupPolicyConfigurationId,
            $AssignmentId
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
            $AssignmentGraphURI = "$($AppGraphUrl)/assignments/$($AssignmentId)"
            Write-Output "Attempting to remove Group Policy Configuration Assignment Id - $($AssignmentId) using Url - $($AssignmentGraphURI)"
            Invoke-RestMethod -Uri $AssignmentGraphURI -Headers $GroupPolicyHeaders -Method Delete -ErrorAction Stop 
            Write-Output "Successfully removed Group Policy Configuration Assignment Id - $($AssignmentId)" 
        }
        else
        {
            Write-Output "Intune Group Policy Configuration with GroupPolicyConfigurationId: $($GroupPolicyConfigurationId) not found"
        }
    }
    catch [System.Exception] 
    {
        Write-Output "Intune Group Policy Configuration Removal Failed with id: $($AssignmentId)"
        Write-Error $_.Exception.Message
    }
}

Write-Output "------------------- Starting Delete Intune Object Assignments Script -------------------"
$MobileAppId = '' #Mobile App Id to delete
$MobileAppAssignmentId = '' #Mobile App Assignment Id to delete
$DeviceConfigurationProfileId = '' #Device Configuration Profile Id to delete
$DeviceConfigurationProfileAssignmentId = '' #Device Configuration Profile Assignment Id to delete
$GroupPolicyConfigurationId = '' #Group Policy Configuration Id to delete
$GroupPolicyConfigurationAssignmentId = '' #Group Policy Configuration Assignment Id to delete

if($MobileAppAssignmentId)
{
    Remove-IntuneMobileApp -MobileAppId $MobileAppId -AssignmentId $MobileAppAssignmentId
}

if($DeviceConfigurationProfileAssignmentId)
{
    Remove-IntuneDeviceConfigurationProfile -DeviceConfigProfileId $DeviceConfigurationProfileId -AssignmentId $DeviceConfigurationProfileAssignmentId
}

if($GroupPolicyConfigurationAssignmentId)
{
    Remove-IntuneGroupPolicy -GroupPolicyConfigurationId $DeviceGroupPolicyId -AssignmentId $GroupPolicyConfigurationAssignmentId
}