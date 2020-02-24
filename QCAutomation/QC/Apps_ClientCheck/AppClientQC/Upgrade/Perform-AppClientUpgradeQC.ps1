
#region Configuration variables

try
{
    $ScriptRoot = $PSScriptRoot
    if(!$ScriptRoot) { $ScriptRoot = $MyInvocation.InvocationName }
    $QCModulePath = "{0}\Module" -f ([Regex]::Match($ScriptRoot, ".*\\QC", "IgnoreCase")).Value
}
catch
{
    throw "QC module not found!"
}

Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName AppClientQCConfigurations.psd1 -BindingVariable Configurations
$InputParams = $Configurations.InputParams
$SiteServerName = $Configurations.SiteServers[$InputParams.SiteCode]
#endregion

#region Main Module

## Import QC Module
#Get-Module -Name QCModule | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module "$QCModulePath\QCModule.psd1"

## Explicitly import pester
Import-Module Pester

## Start to run test in name will be run
$QCStartTime = [DateTime]::Now
$TestResults = Invoke-Pester -Script @{Path="$ScriptRoot\QCCheck.AppClientUpgrade.ps1";Parameters=@{Configurations=$Configurations}} -PassThru -ErrorAction SilentlyContinue 
$QCEndTime = [DateTime]::Now
$QCTitle = "App and OSD Client QC result for Client Machines" -f $InputParams["UpgradeDateTime"]

## Export report to Html file
Export-QCReport -QCTitle $QCTitle -TestResults $TestResults -OutputPath $ScriptRoot -QCStart $QCStartTime -QCEnd $QCEndTime

#endregion