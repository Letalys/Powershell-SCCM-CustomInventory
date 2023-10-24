<#
.SYNOPSIS
  <Overview of WMI Class>
.DESCRIPTION
  <Brief description of script and generated WMi Class>
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
  <Example :
    Custom_WMIClassName :: Root\Cimv2
        [String]PropertyName1 : Description
        [String]PropertyName2 : Description
.NOTES
  Version:        1.0
  Author:         <Your Name>
  Creation Date:  <Creation Date>
  Purpose/Change: Initial script development
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
        $GetSMSClient = Get-CimInstance -Class "SMS_Client" -Namespace 'root\ccm' -ErrorAction SilentlyContinue
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
        $CurrentWMI = Get-CimInstance $ClassName -ErrorAction SilentlyContinue

	    if ($CurrentWMI -ne $null) {
		    $CurrentWMI | Remove-CimInstance

		    $CurrentWMI = Get-CimInstance $ClassName -ErrorAction SilentlyContinue
		    if ($CurrentWMI -eq $null) {
			    $Output += "OK"
		    } else {
			    $Output += "WMI Instance always exist"
			    exit 1
		    }
		    Write-Verbose $Output
	    }

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

            $AddInstance = New-CimInstance -ClassName $ClassName -Key $key -Property @{Key = $key}
            Write-Verbose "Create Instance with key : $key"

            foreach($prop in $CurrentObjectPropertiesList){
                    Set-CimInstance -CimInstance $AddInstance -Property @{$Prop.Name = "$($o.($Prop.Name))"}     
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
    $ClassExist = Get-CimInstance -ClassName $ClassName
    if($ClassExist -ne $null){
        Write-Verbose "Return 0 for good execution"
        return 0
    }else{
        Write-Verbose "Return 1 when Class Not create properly"
        return 1
    }
}

#region Custom Class Definition
$CurrentClassName = "CustomInventory_UsersProfiles"

$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "CustomProp1" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "CustomProp2" -Value $null
#endregion Custom Class Definition

Try{  
    #region Custom Code
    #Define the ArrayList for your Instances Objects

    [System.Collections.Arraylist]$InstancesObjectArray =@()
    
    <#
    Put your code for generating one or several Instance Object, you need to respect template object Property
    You can Add Key Property value if you want customize it, else a GUID is generated for the instance key
    EXAMPLE :  
    #>

    $MyObjectInstance = New-Object PSObject
    #$MyObjectInstance | Add-Member -MemberType NoteProperty -Name "Key" -Value "CustomKey"
    $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "CustomProp1" -Value "SetValue1"
    $MyObjectInstance | Add-Member -MemberType NoteProperty -Name "CustomProp2" -Value "SetValue2"
    
    #Add Your Object to The ArrayList
    $InstancesObjectArray.Add($MyObjectInstance) | Out-Null

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
