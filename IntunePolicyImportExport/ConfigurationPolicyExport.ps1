
Function GenerateFilePath
{
	
    $currentdate = get-date -uformat "%Y-%m-%d_%H.%M.%S" 
    $LogFilePath = ([Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath) + "\IntuneConfigPolicyExport" + $currentdate
    
    $FileExists = Test-Path $LogFilePath

    if ($FileExists -eq $False){New-Item $LogFilePath -type directory}
    
    #$LogFilePath = $LogFilePath + "\"
   
	#Return $LogFilePath
}


function Get-AuthToken {



[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $User
)

$userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User

$tenant = $userUpn.Host

Import-Module AzureAD
$AadModule = Get-Module -Name "AzureAD" -ListAvailable
$adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

$clientId = "XXXXXXXXXXXXXXXXXXXX" #Microsoft Intune Powershell clientID GUID.

$redirectUri = "urn:ietf:wg:oauth:2.0:oob"

$resourceAppIdURI = "https://graph.microsoft.com"

$authority = "https://login.microsoftonline.com/$Tenant"

    try {

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

    # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
    # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession

    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"

    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

        # If the accesstoken is valid then create the authentication header

        if($authResult.AccessToken){

        # Creating header for Authorization token

        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'="Bearer " + $authResult.AccessToken
            'ExpiresOn'=$authResult.ExpiresOn
            }

        return $authHeader

        }

        else {

        Write-Host
        Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
        Write-Host
        break

        }

    }

    catch {

    write-host $_.Exception.Message -f Red
    write-host $_.Exception.ItemName -f Red
    write-host
    break

    }

}

####################################################

Function Get-DeviceConfigurationPolicyDcv1(){



[cmdletbinding()]

$graphApiVersion = "beta"
$DCP_resource = "deviceManagement/deviceConfigurations"
    
    try {
    
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
    
    }
    
    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}


<#Function Get-SettingsCatalogPolicy(){

<#
.SYNOPSIS
This function is used to get Settings Catalog policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Settings Catalog policies
.EXAMPLE
Get-SettingsCatalogPolicy
Returns any Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform windows10
Returns any Windows 10 Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform macOS
Returns any MacOS Settings Catalog policies configured in Intune
.NOTES
NAME: Get-SettingsCatalogPolicy
#>

<#[cmdletbinding()]

param
(
 [parameter(Mandatory=$false)]
 [ValidateSet("windows10","macOS","ios","Android")]
 [ValidateNotNullOrEmpty()]
 [string]$Platform
)

$graphApiVersion = "beta"

    if($Platform){
        
        #$Resource = "deviceManagement/configurationPolicies?`$filter=platforms has '$Platform' and technologies has 'mdm'"
        $Resource = "deviceManagement/configurationPolicies"

    }

    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }
    #>


####################################################
<# apps protection policies#>

Function Get-DeviceAppPolicies(){



[cmdletbinding()]

$graphApiVersion = "beta"
$DCP_resource = "deviceAppManagement/managedAppPolicies"
    
    try {
    
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
    
    }
    
    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

#############################################################



Function Get-DeviceACPpolicies(){



[cmdletbinding()]

$graphApiVersion = "beta"
$DCP_resource1 = "deviceAppManagement/MobileAppConfigurations"
$DCP_resource2 = "deviceAppManagement/targetedManagedAppConfigurations"
$allACPItems = @()
    
    try {
    
        #platform based ACP policies
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource1)"
        $items1 = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

        #non-platform based ACP policies
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource2)"
        $items2 = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        $allACPItems = $items1 + $items2
        #$allACPItems = $items1
        
    }
    
    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

    return $allACPItems

}


##############################################################

Function Get-SettingsCatalogPolicySettings(){

<#
.SYNOPSIS
This function is used to get Settings Catalog policy Settings from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Settings Catalog policy Settings
.EXAMPLE
Get-SettingsCatalogPolicySettings -policyid policyid
Returns any Settings Catalog policy Settings configured in Intune
.NOTES
NAME: Get-SettingsCatalogPolicySettings
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $policyid
)

$graphApiVersion = "beta"
$Resource = "deviceManagement/configurationPolicies('$policyid')/settings?`$expand=settingDefinitions"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

        $Response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)

        $AllResponses = $Response.value
     
        $ResponseNextLink = $Response."@odata.nextLink"

        while ($ResponseNextLink -ne $null){

            $Response = (Invoke-RestMethod -Uri $ResponseNextLink -Headers $authToken -Method Get)
            $ResponseNextLink = $Response."@odata.nextLink"
            $AllResponses += $Response.value

        }

        return $AllResponses

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

#################################################################

Function Get-DeviceConfigurationPolicyDCV2(){



[cmdletbinding()]

$graphApiVersion = "beta"
$DCP_resource = "deviceManagement/configurationPolicies"
$allItems = @()
    
    try {
    
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
    #(Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
    
    
    #handle page Odata query page issu
    $items = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
    
        if ($items.'@odata.nextLink') {

        do {

            $items = Invoke-RestMethod -Uri $items.'@odata.nextLink' -Headers $authToken -Method Get

                                          
            
            $allItems += $items.value
           

        } until (!($items.'@odata.nextLink'))    
    }
    
    return $allItems
    
    }
    
    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}

####################################################

Function Export-JSONData(){



param (

$JSON,
$ExportPath

)

    try {

        if($JSON -eq "" -or $JSON -eq $null){

        write-host "No JSON specified, please specify valid JSON..." -f Red

        }

        elseif(!$ExportPath){

        write-host "No export path parameter set, please provide a path to export the file" -f Red

        }

        elseif(!(Test-Path $ExportPath)){

        write-host "$ExportPath doesn't exist, can't export JSON Data" -f Red

        }

        else {

        $JSON1 = ConvertTo-Json $JSON -Depth 99

        $JSON_Convert = $JSON1 | ConvertFrom-Json

        if( $JSON_Convert.displayName) {    $displayName = $JSON_Convert.displayName } #for DCV1
        if( $JSON_Convert.Name) {    $displayName = $JSON_Convert.Name } #for DCV2


        # Updating display name to follow file naming conventions - https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247%28v=vs.85%29.aspx
        $DisplayName = $DisplayName -replace '\<|\>|:|"|/|\\|\||\?|\*', "_"

        $Properties = ($JSON_Convert | Get-Member | ? { $_.MemberType -eq "NoteProperty" }).Name

            $FileName_CSV = "$DisplayName" + ".csv"
            $FileName_JSON = "$DisplayName" +  ".json"

            $Object = New-Object System.Object

                foreach($Property in $Properties){

                $Object | Add-Member -MemberType NoteProperty -Name $Property -Value $JSON_Convert.$Property

                }

            write-host "Export Path:" "$ExportPath"

           # $Object | Export-Csv -LiteralPath "$ExportPath\$FileName_CSV" -Delimiter "," -NoTypeInformation -Append  # save as CSV
            $JSON1 | Set-Content -LiteralPath "$ExportPath\$FileName_JSON"
            #write-host "CSV created in $ExportPath\$FileName_CSV..." -f cyan
            write-host "JSON created in $ExportPath\$FileName_JSON..." -f cyan
            
        }

    }

    catch {

    $_.Exception

    }

}

####################################################

#region Authentication

write-host

# Checking if authToken exists before running authentication
if($global:authToken){

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

        if($TokenExpires -le 0){

        write-host "Authentication Token expired" $TokenExpires "minutes ago" -ForegroundColor Yellow
        write-host

            # Defining User Principal Name if not present

            if($User -eq $null -or $User -eq ""){

            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
            Write-Host

            }

        $global:authToken = Get-AuthToken -User $User

        }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    if($User -eq $null -or $User -eq ""){

    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host

    }

# Getting the authorization token
$global:authToken = Get-AuthToken -User $User

}

#endregion

####################################################

$ExportPath = GenerateFilePath

write-host $ExportPath -ForegroundColor  Green
####################################################

#Retrive DCV1 configuration policies

#$DCPs = Get-DeviceConfigurationPolicyDcv1 

if($DCPs)
{
    foreach($DCP in $DCPs){

    write-host "DCV1 Device Configuration Policy:"$DCP.displayName -f Yellow
    
    Export-JSONData -JSON $DCP -ExportPath "$ExportPath"
    Write-Host

    }


}


#Retrive apps protection policies
$APPS = Get-DeviceAppPolicies 
if($APPS)
{
    
   
    $ExportAPP = "$ExportPath" + "\MAM_APP"
   
    $FileExists = Test-Path $ExportAPP
    if ($FileExists -eq $False) {    New-Item $ExportAPP -type directory}

    foreach($APP in $APPs){

    write-host "Device Apps Protection Policy:"$APP.displayName -f Yellow
    Export-JSONData -JSON $APP -ExportPath "$ExportAPP"
    Write-Host

    }


}

#Retrive apps configuration policies
$ACPs =  Get-DeviceACPpolicies
if($ACPs)
{
    
    $ExportACP = "$ExportPath" + "\MAM_ACP"
    $FileExists = Test-Path $ExportACP

    if ($FileExists -eq $False) {    New-Item $ExportACP -type directory}
    
    foreach($ACP in $ACPs){

    write-host "Device Apps Configuration Policy:"$ACP.displayName -f Yellow
    Export-JSONData -JSON $ACP -ExportPath $ExportACP
    Write-Host

    }


}

######################################################################

#Retrive DCV2 configuration policies

#$Policies = Get-DeviceConfigurationPolicyDCV2 


if($Policies){

    foreach($policy in $Policies){

        Write-Host $policy.name -ForegroundColor Yellow

        $AllSettingsInstances = @()

        $policyid = $policy.id
        $Policy_Technologies = $policy.technologies
        $Policy_Platforms = $Policy.platforms
        $Policy_Name = $Policy.name
        $Policy_Description = $policy.description

        $PolicyBody = New-Object -TypeName PSObject

        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'name' -Value "$Policy_Name"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'description' -Value "$Policy_Description"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'platforms' -Value "$Policy_Platforms"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'technologies' -Value "$Policy_Technologies"

        # Checking if policy has a templateId associated
        if($policy.templateReference.templateId){

            Write-Host "Found template reference" -f Cyan
            $templateId = $policy.templateReference.templateId

            $PolicyTemplateReference = New-Object -TypeName PSObject

            Add-Member -InputObject $PolicyTemplateReference -MemberType 'NoteProperty' -Name 'templateId' -Value $templateId

            Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'templateReference' -Value $PolicyTemplateReference

        }

        $SettingInstances = Get-SettingsCatalogPolicySettings -policyid $policyid

        $Instances = $SettingInstances.settingInstance

        foreach($object in $Instances){

            $Instance = New-Object -TypeName PSObject

            Add-Member -InputObject $Instance -MemberType 'NoteProperty' -Name 'settingInstance' -Value $object
            $AllSettingsInstances += $Instance

        }

        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'settings' -Value @($AllSettingsInstances)

        Export-JSONData -JSON $PolicyBody -ExportPath "$ExportPath"
        Write-Host

    }

}

else {

    Write-Host "No Settings Catalog policies found..." -ForegroundColor Red
    Write-Host

}