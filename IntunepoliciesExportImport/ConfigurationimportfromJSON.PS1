

function Get-AuthToken {



[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $User
)

$userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User

$tenant = $userUpn.Host
write-host $tenant

Import-Module AzureAD
$AadModule = Get-Module -Name "AzureAD" -ListAvailable
$adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

$clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"

$redirectUri = "urn:ietf:wg:oauth:2.0:oob"

$resourceAppIdURI = "https://graph.microsoft.com"

$authority = "https://login.microsoftonline.com/$Tenant"

    try {

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    write-host $authContext

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

Function Add-DeviceConfigurationPolicy(){


[cmdletbinding()]

param
(
    $JSON,
    $DCP_resource_end
)

$graphApiVersion = "beta"
$DCP_resource = $DCP_resource_end
Write-host $json -f blue
    try {

        if($JSON -eq "" -or $JSON -eq $null){

        write-host "No JSON specified, please specify valid JSON for the Device Configuration Policy..." -f Red

        }

        else {

        Test-JSON -JSON $JSON
       
         write-host  $DCP_resource -f Yellow

         $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
         Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType "application/json"
          
        # Invoke-RestMethod -useBasicParsing -Uri $uri -Headers $authToken -Method Post -Body $JSON  -ContentType "application/json"

        }

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

Function Test-JSON(){



param (

$JSON

)

    try {

    $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
    $validJson = $true

    }

    catch {

    $validJson = $false
    $_.Exception

    }

    if (!$validJson){
    
    Write-Host "Provided JSON isn't in valid JSON format" -f Red
    break

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

	

$ImportPath = Read-Host -Prompt "Please specify a folder path to a JSON files to import data from e.g. C:\IntuneOutput\Policies"

# Replacing quotes for Test-Path
$ImportPath = $ImportPath.replace('"','')

if(!(Test-Path "$ImportPath")){

Write-Host "Import Path for JSON file doesn't exist..." -ForegroundColor Red
Write-Host "Script can't continue..." -ForegroundColor Red
Write-Host
break

}

####################################################
$Jsonfiles = Get-ChildItem -Path $ImportPath

if($Jsonfiles -eq $null){

Write-Host "Import folder for JSON file is empty..." -ForegroundColor Red
Write-Host "Script can't continue..." -ForegroundColor Red
Write-Host
break

}

foreach ( $jsonfile in $Jsonfiles)

{

    $ImportPath1 = $ImportPath +"\" + $jsonfile

    $JSON_Data = gc "$ImportPath1"

    # Excluding entries that are not required - id,createdDateTime,lastModifiedDateTime,version
    $JSON_Convert = $JSON_Data | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty id,createdDateTime,lastModifiedDateTime,version,supportsScopeTags

   if($JSON_Convert.'@odata.type' -ne $null)
    {    
        $OdataString = $JSON_Convert.'@odata.type'.ToLower()
        write-host $OdataString -ForegroundColor Green

        if($OdataString.Contains("protectionpolicy") -or $OdataString.Contains("managedappprotection") -or $OdataString.Contains("targetedmanagedappconfiguration"))
        { 
     
            $DCP_resource_end = "deviceAppManagement/ManagedAppPolicies"
            $DisplayName = $JSON_Convert.displayName

        }
        elseif($OdataString.Contains("appconfiguration"))
        { 
     
            $DCP_resource_end = "deviceAppManagement/MobileAppConfigurations"
            $DisplayName = $JSON_Convert.displayName

        }
        elseif($JSON_Convert.displayName)
        {   
            $DCP_resource_end = "deviceManagement/deviceConfigurations"
            $DisplayName = $JSON_Convert.displayName
         }

        elseif($JSON_Convert.Name)
        { 
    
          $DCP_resource_end = "deviceManagement/configurationPolicies"  
          $DisplayName = $JSON_Convert.Name
        }

    }
    else {

            #$DCP_resource_end = "deviceAppManagement/MobileAppConfigurations"

            $DCP_resource_end = "deviceAppManagement/TargetedManagedAppConfigurations"
            $DisplayName = $JSON_Convert.displayName
    }

    $JSON_Output = $JSON_Convert | ConvertTo-Json -Depth 99
            
    write-host
    write-host "Device Configuration Policy '$DisplayName' Found..." -ForegroundColor Yellow
    write-host
    #$JSON_Output
    write-host
    Write-Host "Adding Device Configuration Policy '$DisplayName'" -ForegroundColor Yellow
    Add-DeviceConfigurationPolicy -JSON $JSON_Output $DCP_resource_end
}