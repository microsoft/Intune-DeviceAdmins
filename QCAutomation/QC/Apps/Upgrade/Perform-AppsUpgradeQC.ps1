
#region Configuration variables
Add-Type -AssemblyName presentationframework

function New-FieldSetting {
    param
    (
        [int]$FieldOrder,
        [string]$FieldName,
        [string]$DisplayName,
        [string]$Description,
        [ValidateSet('Text','DateTime','Array','ArrayList')]
        [string]$DataType,
        [string]$DefaultValue,
        [bool]$IsVisible,
        [int]$DisplayWidth,
        [int]$FieldWidth,
        [string[]]$FieldMetaData,
        [string]$FieldValidationPattern,
        [bool]$Mandatory        
    )
    return New-Object PSObject -Property ([Ordered]@{FieldOrder = $FieldOrder; FieldName = $FieldName; DisplayName = $DisplayName; DefaultValue = $DefaultValue; Description = $Description; DataType = $DataType; IsVisible = $IsVisible; FieldMetaData = $FieldMetaData; DisplayWidth = $DisplayWidth; FieldWidth = $FieldWidth; Mandatory = $Mandatory; FieldValidationPattern = $FieldValidationPattern; Value = $null})
}

function Prepare-XamlForm {
    param
    (
        $WindowTitle,
        $WindowHeight,
        $WindowWidth,
        $FieldSettings
    )
    $xamlWindow = "<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'  xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='$WindowTitle' Height='$WindowHeight' Width='$WindowWidth'><Grid>"
    $FieldSettings = $FieldSettings | ? {$_.IsVisible -eq $true} | Sort FieldOrder
    $CurrentMargins = @{Left = 5; Top = 10;}
    $BufferMargins = @{Left = 10; Top = 40;}
    $TabIndex = 0
    foreach($FieldSetting in $FieldSettings)
    {
        $CurrentMargins.Left = 5
        $TabIndex += 1
        $LabelWidth = 180
        $LabelName = "lbl{0}" -f $FieldSetting.FieldName
        $DescLabelName = "lblDesc{0}" -f $FieldSetting.FieldName
        $ControlName = "ctl{0}" -f $FieldSetting.FieldName
        $xamlWindow += "<Label x:Name='{0}' Content='{1}' HorizontalAlignment = 'Left' Margin='{2},{3},0,0' VerticalAlignment = 'Top' Width ='{4}' />" -f $LabelName, $FieldSetting.DisplayName, $CurrentMargins.Left, $CurrentMargins.Top, $LabelWidth
        ## Change left of current margin
        $CurrentMargins.Left += $LabelWidth + $BufferMargins.Left
        switch ($FieldSetting.DataType)
        {
            "Text"
            {
                $xamlWindow += "<TextBox x:Name='{0}' HorizontalAlignment = 'Left' Margin='{1},{2},0,0' VerticalAlignment = 'Top' Width = '{3}' TabIndex = '{4}'>{5}</TextBox>" -f $ControlName, $CurrentMargins.Left, $CurrentMargins.Top, $FieldSetting.FieldWidth, $TabIndex, $FieldSetting.DefaultValue
            }
            "DateTime"
            {
                $xamlWindow += "<DatePicker x:Name='{0}' HorizontalAlignment = 'Left' Margin='{1},{2},0,0' VerticalAlignment = 'Top' Width = '{3}' TabIndex = '{4}'>{5}</DatePicker>" -f $ControlName, $CurrentMargins.Left, $CurrentMargins.Top, $FieldSetting.FieldWidth, $TabIndex, $FieldSetting.DefaultValue
            }
            "Array"
            {
                $xamlWindow += "<ComboBox x:Name='{0}' HorizontalAlignment = 'Left' Margin='{1},{2},0,0' VerticalAlignment = 'Top' Width = '{3}' TabIndex = '{4}'>" -f $ControlName, $CurrentMargins.Left, $CurrentMargins.Top, $FieldSetting.FieldWidth, $TabIndex
                foreach($FieldMetaData in $FieldSetting.FieldMetaData)
                {
                    if($FieldMetaData -eq $FieldSetting.DefaultValue)
                    {
                        $xamlWindow += "<ComboBoxItem IsSelected='True'>{0}</ComboBoxItem>" -f $FieldMetaData
                    }
                    else
                    {
                        $xamlWindow += "<ComboBoxItem>{0}</ComboBoxItem>" -f $FieldMetaData
                    }
                }
                $xamlWindow += "</ComboBox>"
            }
            "ArrayList"
            {
                $xamlWindow += "<ListBox x:Name='{0}' HorizontalAlignment = 'Left' Margin='{1},{2},0,0' VerticalAlignment = 'Top' Width = '{3}' Height = '75' TabIndex = '{4}' SelectionMode='Multiple'>" -f $ControlName, $CurrentMargins.Left, $CurrentMargins.Top, $FieldSetting.FieldWidth, $TabIndex
                foreach($FieldMetaData in $FieldSetting.FieldMetaData)
                {
                    if($FieldMetaData -eq $FieldSetting.DefaultValue)
                    {
                        $xamlWindow += "<ListBoxItem IsSelected='True'>{0}</ListBoxItem>" -f $FieldMetaData
                    }
                    else
                    {
                        $xamlWindow += "<ListBoxItem>{0}</ListBoxItem>" -f $FieldMetaData
                    }
                }
                $xamlWindow += "</ListBox>"
            }
        }

        ## Change left of current margin for description
        $DescriptionWidth = 450
        $CurrentMargins.Left += $FieldSetting.DisplayWidth + $BufferMargins.Left
        $xamlWindow += "<TextBlock TextWrapping='WrapWithOverflow' x:Name='{0}' HorizontalAlignment = 'Left' Margin='{2},{3},0,0' VerticalAlignment = 'Top' Width='$DescriptionWidth'>{1}</TextBlock>" -f $DescLabelName, $FieldSetting.Description, $CurrentMargins.Left, $CurrentMargins.Top
        $CurrentMargins.Left += $DescriptionWidth + $BufferMargins.Left
        
        ## Submit and Cancel buttons
        if($Fieldsetting.FieldOrder -eq 1)
        {
            $xamlWindow += "<Button x:Name='btnSubmit' Content='Start QC' HorizontalAlignment='Left' Margin='{0},{1},0,0' VerticalAlignment='Top' Width='75' IsDefault='True' TabIndex='{2}' FontWeight='Bold' Foreground='White' Background='LightGreen'/>" -f $CurrentMargins.Left, $CurrentMargins.Top, ($Fieldsettings.Count-1)
        }
        if($Fieldsetting.FieldOrder -eq 2)
        {
            $xamlWindow += "<Button x:Name='btnCancel' Content='Exit' HorizontalAlignment='Left' Margin='{0},{1},0,0' VerticalAlignment='Top' Width='75' IsDefault='True' TabIndex='{2}' FontWeight='Bold' Foreground='White' Background='Red'/>" -f $CurrentMargins.Left, $CurrentMargins.Top, $Fieldsettings.Count
        }

        ## Chagne top of current margin
        if($FieldSetting.DataType -eq "ArrayList")
        {
            $CurrentMargins.Top += $BufferMargins.Top + 50
        }
        else
        {
            $CurrentMargins.Top += $BufferMargins.Top
        }        
    }

    ## Submit and cancel buttons    
    $xamlWindow += "</Grid></Window>"
    return $xamlWindow
}

function Get-XamlFormInputs {
    param
    (
        $WindowTitle,
        $WindowHeight,
        $WindowWidth,
        $FieldSettings
    )
    $xamlWindow = [xml](Prepare-XamlForm -WindowTitle $WindowTitle -FieldSettings $FieldSettings -WindowHeight $WindowHeight -WindowWidth $WindowWidth)
    $reader = (New-Object System.Xml.XmlNodeReader $xamlWindow)
    $Window = [Windows.Markup.XamlReader]::Load($reader)
    $btnCancel = $Window.FindName("btnCancel")
    $btnCancel.Add_Click({
        $Window.Close()
        Exit
    })
    $btnSubnit = $Window.FindName("btnSubmit")
    $btnSubnit.Add_Click({
        $FieldsValidated = $false
        foreach($FieldSetting in $FieldSettings)
        {
            $controlName = "ctl{0}" -f $FieldSetting.FieldName
            $control = $Window.FindName($controlName)
            $controlValue = $null
            $controlPrefix = "select"
            switch ($FieldSetting.DataType)
            {
                "Text"
                {
                    $controlValue = $control.Text
                    $controlPrefix = "enter"
                }
                "DateTime"
                {
                    $controlValue = $control.Text
                }
                "Array"
                {
                    $controlValue = $control.SelectedValue
                }
                "ArrayList"
                {
                    $controlValue = @()
                    foreach($selectedItem in $control.SelectedItems)
                    {
                        $controlValue += $selectedItem.Content
                    }
                }
            }
            if(($FieldSetting.Mandatory) -and ([string]::IsNullOrEmpty($controlValue) -eq $true))
            {
                $message = "Please {0} {1}" -f $controlPrefix, $FieldSetting.DisplayName
                [System.Windows.MessageBox]::Show($message,"Validation error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Exclamation)
                $FieldsValidated = $false
                $control.focus()
                break;
            }
            if([string]::IsNullOrEmpty($FieldSetting.FieldValidationPattern) -eq $false)
            {
                if($controlValue -notmatch $FieldSetting.FieldValidationPattern)
                {
                    $message = "Please specify value of {1} in correct format" -f $controlPrefix, $FieldSetting.DisplayName
                    [System.Windows.MessageBox]::Show($message,"Validation error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Exclamation)
                    $FieldsValidated = $false
                    break;
                }
            }
            $FieldSetting.Value = $controlValue
            $FieldsValidated = $true
        }
        if($FieldsValidated -eq $true)
        {
            $Window.Close()            
        }
    })
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $Window.WindowStyle = [System.Windows.WindowStyle]::None
    $Window.Showdialog() | Out-Null
}
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

## Import QC Module
Get-Module -Name QCModule | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module "$QCModulePath\QCModule.psd1"

## Explicitly import pester
Import-Module Pester
$BaseDirectory = "$PSScriptRoot\Config\Prod"
Import-LocalizedData -BaseDirectory $BaseDirectory -FileName AppsQCConfigurations.psd1 -BindingVariable Configurations
$QCEnvironment = $Configurations.QCEnvironment
$CentralSiteDetails = $Configurations.CentralSiteDetails[$QCEnvironment]
$AppsParams = $Configurations.AppsParams
$ComputerName1 = $AppsParams.ComputerName1
$ComputerName2 = $AppsParams.ComputerName2
$SourcePath = $AppsParams.SourcePath
$AppSourcePath = $AppsParams.AppSourcePath
$AppxAppSourcePath = $AppsParams.AppxAppSourcePath
$SupersedSource = $AppsParams.SupersedSource
$SupersedAppSource = $AppsParams.SupersedAppSource
$DeployCollectionName = $AppsParams.DeployCollectionName
$SiteCode = $CentralSiteDetails.SiteCode
$SiteServer = $CentralSiteDetails.SiteServer



#endregion
#Import SCCM Module
$ModuleName = (get-item $env:SMS_ADMIN_UI_PATH).parent.FullName + "\ConfigurationManager.psd1"
Import-Module $ModuleName 

#Get SiteCode
CD $SiteCode":"

#region Main Module

$LimitingCollectionName = "{0} QC Limiting Collection" -f $QCEnvironment
$FieldSettings = @()
$FieldSettings += New-FieldSetting -FieldOrder 1 -FieldName "QCTitle" -DisplayName "QC Title" -Description "Please enter appropriate QC title. (e.g. 1812_Apps_PreUpgrade or 1812_Apps_PostUpgrade)" -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true
$FieldSettings += New-FieldSetting -FieldOrder 2 -FieldName "UpgradeScheduledDate" -DisplayName "Upgrade scheduled Date" -Description "Please select the date when upgrade is scheduled. If this date is in past, this will be a Post-QC otherwise this will be a Pre-QC" -DataType DateTime -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true
$FieldSettings += New-FieldSetting -FieldOrder 3 -FieldName "UpgradeScheduledTime" -DisplayName "Upgrade scheduled Time" -Description "Please select the time when upgrade is scheduled. Please enter the value in 24 hours time format i.e. HH:MM" -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -FieldValidationPattern "([01]?[0-9]|2[0-3]):[0-5][0-9]"
$FieldSettings += New-FieldSetting -FieldOrder 4 -FieldName "ExpectedUpgradeName" -DisplayName "Expected Upgrade Name" -Description "Please enter the appropriate SCCM console client upgrade name at this time. Please note that the current specified version is for illustration purpose only." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue "Configuration Manager 1810"
$FieldSettings += New-FieldSetting -FieldOrder 6 -FieldName "ComputerName1" -DisplayName "Test client machine name1" -Description "Please enter valid client computer name to create device collection." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $ComputerName1
$FieldSettings += New-FieldSetting -FieldOrder 7 -FieldName "ComputerName2" -DisplayName "Test client machine name2" -Description "Please enter second valid client computer name to create device collection." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $ComputerName2
$FieldSettings += New-FieldSetting -FieldOrder 8 -FieldName "LimitingCollectionName" -DisplayName "Limiting collection name" -Description "Please enter valid existing colleciton name to create test collections under." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $LimitingCollectionName
$FieldSettings += New-FieldSetting -FieldOrder 9 -FieldName "SourcePath" -DisplayName "SourcePath" -Description "Please enter valid Source Path to create Package." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $SourcePath
$FieldSettings += New-FieldSetting -FieldOrder 10 -FieldName "AppSourcePath" -DisplayName "AppSourcePath" -Description "Please enter valid existing Source Path to create Application." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $AppSourcePath
$FieldSettings += New-FieldSetting -FieldOrder 11 -FieldName "AppxAppSourcePath" -DisplayName "AppxAppSourcePath" -Description "Please enter valid Source Path to create Modren Application." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $AppxAppSourcePath
$FieldSettings += New-FieldSetting -FieldOrder 12 -FieldName "SupersedSource" -DisplayName "SupersedSource" -Description "Please enter valid Source Path to create Superseded Application." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $SupersedSource
$FieldSettings += New-FieldSetting -FieldOrder 13 -FieldName "SupersedAppSource" -DisplayName "SupersedAppSource" -Description "Please enter valid Source Path to create Supdersedence Application." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $SupersedAppSource
$FieldSettings += New-FieldSetting -FieldOrder 14 -FieldName "DeployCollectionName" -DisplayName "DeployCollectionName" -Description "Please enter valid existing deploy colleciton name to deploy application." -DataType Text -IsVisible $true -DisplayWidth 200 -FieldWidth 200 -Mandatory $true -DefaultValue $DeployCollectionName


$WindowTitle = "Apps upgrade QC inputs"
Get-XamlFormInputs -WindowTitle $WindowTitle -FieldSettings $FieldSettings -WindowHeight 700 -WindowWidth 1000
$ArrInputParams = @()
$UpgradeScheduledDate = ($FieldSettings | ? {$_.FieldName -eq "UpgradeScheduledDate"}).Value
$UpgradeScheduledTime = ($FieldSettings | ? {$_.FieldName -eq "UpgradeScheduledTime"}).Value
$UpgradeDateTime = [DateTime]("{0} {1}:00" -f $UpgradeScheduledDate, $UpgradeScheduledTime)


    $InputParams = New-Object PSObject
    $InputParams | Add-Member -MemberType NoteProperty -Name "SiteCode" -Value $SiteCode -Force
    $InputParams | Add-Member -MemberType NoteProperty -Name "QCEnvironment" -Value $QCEnvironment -Force
    $InputParams | Add-Member -MemberType NoteProperty -Name "UpgradeDateTime" -Value $UpgradeDateTime -Force
    
    foreach($FieldSetting in $FieldSettings)
    {
        
            $InputParams | Add-Member -MemberType NoteProperty -Name $FieldSetting.FieldName -Value $FieldSetting.Value -Force
        
    }
    $ArrInputParams += $InputParams


## Start to run test in name will be run

$QCStartTime = [DateTime]::Now
$TestResults = Invoke-Pester -Script @{Path="$ScriptRoot\QCCheck.AppsUpgrade.ps1";Parameters=@{InputParams = $InputParams; AllSiteArtifacts = $AllSites; Configurations = $Configurations}} -PassThru -ErrorAction SilentlyContinue
$QCEndTime = [DateTime]::Now
$Title = $InputParams.QCTitle
$QCTitle = "Apps QC result for site: {0} [{1}] UpgradeDate: {2}" -f $InputParams["SiteCode"], $SiteServer, $InputParams["UpgradeDateTime"]
$QCType = @{$true="Post-Upgrade";$false="Pre-upgrade"}[$UpgradeDateTime -lt [DateTime]::Now]
## Export report to Html file
$QCOutputCSV = Export-QCReport -QCTitle $QCTitle -TestResults $TestResults -OutputPath $ScriptRoot -QCStart $QCStartTime -QCEnd $QCEndTime

#endregion