<#
.SYNOPSIS
  Get all Of PnPSignedDrivers
.DESCRIPTION
  Generate a CustomInventory for PnpDrivers Which can use in SCCM Hardware Inventory
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
    CustomInventory_PnpDrivers :: Root\Cimv2
        "DeviceID" : Get the device ID (Driver Name)
        "DeviceClass" : Get the Drive Class (NET, MEDIA, PRINT, ...)
        "DeviceName" : Name of the device associate to the driver
        "DriverDate" : Version date of the driver
        "DriverProviderName"
        "DriverVersion" : Version 
        "HardwareID" 
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  26/02/2023
  Purpose/Change: Initial script development

.LINK
    Author : Letalys (https://github.com/Letalys)
#>

Function Invoke-CCMHardwareInventory{
    Begin{
      Write-Output "Trying to perform CCM hardware inventory..."
    }
    Process{
      Try{
        $GetSMSClient = Get-CimInstance -Class "SMS_Client" -Namespace 'root\ccm' -ErrorAction SilentlyContinue
        if($null -ne $GetSMSClient){
            Write-Output "CCM Agent found, performing hardware inventory."

	        $SMSClient = [wmiclass] "\\$($env:COMPUTERNAME)\root\ccm:SMS_Client"
	        $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
        }else{
            Write-Warning "CCM Agent not found, will not perform hardware inventory."
        }
      }Catch{
        Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
        Break
      }
    }
    End{
      If($?){
        Write-Output "Completed Successfully."
      }
    }
}
Function New-WMIClass{
    [CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName,
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][Object]$ClassTemplate
	)
    
    Begin{}
    Process{
        #Check existing WMI Class
        if($null -ne (Get-WmiObject $ClassName -ErrorAction SilentlyContinue)){Write-Output "Deleting class $ClassName" ; Remove-WmiObject $ClassName}
        Write-Output "Create New WMI Class :  $ClassName"

        $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null);
	    $newClass["__CLASS"] = $ClassName;
        $newClass.Qualifiers.Add("Static", $true)

        $newClass.Properties.Add("Key", [System.Management.CimType]::String, $false)
        $newClass.Properties["Key"].Qualifiers.Add("Key", $true)

        $TemplateProperties = $ClassTemplate | Get-Member -MemberType NoteProperty

        foreach($prop in $TemplateProperties){
            Write-Output "`t Add Class Property : $($Prop.Name)"
            $newClass.Properties.Add("$($Prop.Name)", [System.Management.CimType]::String, $false)
        }
            
        $newClass.Put() | Out-Null
    }
    End{}
}
Function Add-WMIInstances {
    [CmdletBinding()]
	param
	(
        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName,
        [ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][System.Collections.Arraylist]$ObjectArrayList
	)
    Begin{}
    Process{
        foreach($o in $ObjectArrayList){
            $GUID = [GUID]::NewGuid()
            if($null -ne $o.Key){$Key = $o.key}else{$Key = $GUID}
            $CurrentInstance = Set-WmiInstance -Namespace "root\cimv2" -class $ClassName -argument @{Key = $Key} 

            foreach($prop in ($o| Get-Member -MemberType NoteProperty | Where-Object {$_.Name -ne "key"})){
                $CurrentInstance.($prop.Name) = $o.($prop.Name)
                $CurrentInstance.Put() | Out-Null
            }
            Write-Output "Added Instance to $ClassName for : " $o
        }
    }
    End{}
}

#region Custom Class Definition
$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DeviceID" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DeviceClass" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DeviceName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DriverDate" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DriverProviderName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DriverVersion" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "HardwareID" -Value $null

New-WMIClass -ClassName "CustomInventory_PnpDrivers" -ClassTemplate $TemplateObject
#endregion Custom Class Definition

Try{
    #region Custom Code
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$PnPDriversArray =@()

    <#
    Put your code for generating one or several Instance Object, you need to respect template object Property
    You can Add Key Property value if you want customize it, else a GUID is generated for the instance key
    EXAMPLE :  
    #>

    $Drivers = Get-CimInstance win32_pnpsigneddriver -Property DeviceClass, DeviceName,DriverDate,DriverProviderName,DriverVersion,HardwareID,DeviceID

    ForEach($Driver in $Drivers){
      $ObjDriverInstance = New-Object PSObject
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "Key" -Value $Driver.DeviceID
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "DeviceID" -Value $Driver.DeviceID
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "DeviceClass" -Value $Driver.DeviceClass
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "DeviceName" -Value $Driver.DeviceName
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "DriverDate" -Value $Driver.DriverDate
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "DriverProviderName" -Value $Driver.DriverProviderName
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "DriverVersion" -Value $Driver.DriverVersion
      $ObjDriverInstance | Add-Member -MemberType NoteProperty -Name "HardwareID" -Value $Driver.HardwareID

      $PnPDriversArray.Add($ObjDriverInstance) | Out-Null
    }
   
    #Convert all object in Array to WMI Instance
    Add-WMIInstances -ClassName "CustomInventory_PnpDrivers" -ObjectArrayList $PnPDriversArray
    #endregion Custom Code

    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory
    return 0 #Script Process With Success (return 0 for SCCM)
}catch{
    Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
    Return -1 #Script Failed  (return -1 for SCCM)
}