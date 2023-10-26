<#
.SYNOPSIS
  Get all Of PnPSignedDrivers on Windows 7
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
  Version:        2.0
  Author:         Letalys
  Creation Date:  26/10/2023
  Purpose/Change: Initial Script development
.LINK
    Author : Letalys (https://github.com/Letalys)
#>

$VerbosePreference = 'SilentlyContinue'

Function Invoke-CCMHardwareInventory{
    Begin{
     Write-Verbose "Trying to perform CCM hardware inventory..."
    }
    Process{
      Try{
        $GetSMSClient = Get-WmiObject -Class "SMS_Client" -Namespace 'root\ccm' -ErrorAction SilentlyContinue
        if($null -ne $GetSMSClient){
           Write-Verbose "CCM Agent found, performing hardware inventory."

	        $SMSClient = [wmiclass] "\\$($env:COMPUTERNAME)\root\ccm:SMS_Client"
	        $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") | Out-Null
        }else{
            Write-Verbose "CCM Agent not found, will not perform hardware inventory."
        }
      }Catch{
        Write-Verbose "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
        Break
      }
    }
    End{
      If($?){
       Write-Verbose "Completed Successfully."
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
        if($null -ne (Get-WmiObject $ClassName -ErrorAction SilentlyContinue)){Write-Verbose "Deleting class $ClassName" ; Remove-WmiObject $ClassName}
        Write-Verbose "Create New WMI Class :  $ClassName"

        $newClass = New-Object System.Management.ManagementClass("root\cimv2", [String]::Empty, $null);
	    $newClass["__CLASS"] = $ClassName;
        $newClass.Qualifiers.Add("Static", $true)

        $newClass.Properties.Add("Key", [System.Management.CimType]::String, $false)
        $newClass.Properties["Key"].Qualifiers.Add("Key", $true)

        $TemplateProperties = $ClassTemplate | Get-Member -MemberType NoteProperty

        foreach($prop in $TemplateProperties){
           Write-Verbose "`t Add Class Property : $($Prop.Name)"
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
            #Create GUID Key
            $GUID = [GUID]::NewGuid()

            if($null -ne $o.Key){$Key = $o.key}else{$Key = $GUID}

            $CurrentObjectPropertiesList = $o | Get-Member -MemberType NoteProperty

            $AddInstance = Set-WmiInstance -Class $ClassName -Arguments @{Key = $key} 

            Write-Verbose "Create Instance with key : $key"

            $GetCurrentAddInstance = Get-WmiObject -Class $ClassName | Where-Object {$_.key -eq $key}
            if($GetCurrentAddInstance -ne $null){
                Write-Verbose  $key 

                foreach($prop in $CurrentObjectPropertiesList){
                    Write-Verbose  "`t $($prop.Name) : $($o.($prop.name))"
                    $GetCurrentAddInstance.($($prop.Name)) = $($o.($prop.name))
                    $GetCurrentAddInstance.put() | Out-null
                  
                }
            }
        }
    }
    End{}
}
Function Test-WMIClass{
    [CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName
	)
    $ClassExist  = Get-WmiObject $ClassName -ErrorAction SilentlyContinue
    if($ClassExist  -ne $null){
        Write-Verbose "Return 0 for good execution"
        return 0
    }else{
        Write-Verbose "Return 1 when Class Not create properly"
        return 1
    }
}

#region Custom Class Definition
$CurrentClassName = "CustomInventory_PnpDrivers"

$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DeviceID" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DeviceClass" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DeviceName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DriverDate" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DriverProviderName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "DriverVersion" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "HardwareID" -Value $null
#endregion Custom Class Definition

Try{  
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    #region Custom Code
   
    $Drivers = Get-WmiObject -Class win32_pnpsigneddriver -Property DeviceClass, DeviceName,DriverDate,DriverProviderName,DriverVersion,HardwareID,DeviceID

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

      $InstancesObjectArray.Add($ObjDriverInstance) | Out-Null
    }
   

    #Convert all object in Array to WMI Instance
    New-WMIClass -ClassName $CurrentClassName -ClassTemplate $TemplateObject
    Add-WMIInstances -ClassName $CurrentClassName -ObjectArrayList $InstancesObjectArray
    
    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory

    #Test
    Return (Test-WMIClass -ClassName $CurrentClassName)
}catch{
    Write-Host "An error occurred : "
    Write-Host "$($_.InvocationInfo.ScriptLineNumber) : $($_)"

    Write-Verbose $_
    Write-Verbose "Return -1 for general error"
    return -1
}
