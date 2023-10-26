<#
.SYNOPSIS
  Inventory for Oracle Client installed by OUI
.DESCRIPTION
  This create an inventory to get all Oracle Information installed by OUI, not work for Instant Client
  because there is no information into the registry.
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
  <Example :
    CustomInventory_OracleClients :: Root\Cimv2
        "Oracle_HomeName" : Get The Oracle Home Name
        "Oracle_Home" : Get the Oracle Home Value
        "Oracle_Dll" Get the main Oracle DLL
        "Oracle_Version" : Get the main version
        "Oracle_Platform" : Oracle Client Plateform
  >
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  26/02/2023
  Purpose/Change: Initial script development

  .NOTES
  Version:        2.0
  Author:         Letalys
  Creation Date:  25/10/2023
  Purpose/Change: Update with new template

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
$CurrentClassName = "CustomInventory_OracleClients"

$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Oracle_HomeName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Oracle_Home" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Oracle_Dll" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Oracle_Version" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Oracle_Platform" -Value $null
#endregion Custom Class Definition

Try{
    #region Custom Code
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

   #region Oracle x86 Registry
   $OracleRegistryx86 = "HKLM:\SOFTWARE\WOW6432Node\ORACLE"
   if (test-path $OracleRegistryx86){
       $ORAHomeListx86 = Get-childItem -Path $OracleRegistryx86 | Foreach-Object {Get-itemproperty -path $_.PSPath | Select-Object ORACLE_HOME_NAME,ORACLE_HOME}

       Foreach($ORAHome in $ORAHomeListx86){
           if($null -ne $ORAHome.ORACLE_HOME -and (test-path $ORAHome.ORACLE_HOME)){
               $OraVersionx86 = Get-childItem -path $ORAHome.ORACLE_HOME -Recurse -Include "OraClient*.dll" |  Foreach-Object {$_.FullName, [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_).FileVersion} -ErrorAction SilentlyContinue
       
               $ObjOracleClient = New-Object Psobject
               $ObjOracleClient | Add-Member -Name "Oracle_HomeName" -membertype Noteproperty -Value $ORAHome.ORACLE_HOME_NAME
               $ObjOracleClient | Add-Member -Name "Oracle_Home" -membertype Noteproperty -Value  $ORAHome.ORACLE_HOME

               if ($null -ne $OraVersionx86){
                   $ObjOracleClient | Add-Member -Name "Oracle_Dll" -membertype Noteproperty -Value $OraVersionx86[0]
                   $ObjOracleClient | Add-Member -Name "Oracle_Version" -membertype Noteproperty -Value $OraVersionx86[1]
               }else{
                   $ObjOracleClient | Add-Member -Name "Oracle_Dll" -membertype Noteproperty -Value "Not Found"
                   $ObjOracleClient | Add-Member -Name "Oracle_Version" -membertype Noteproperty -Value "Not Found"
               }
               $ObjOracleClient | Add-Member -Name "Oracle_Platform" -membertype Noteproperty -Value "x86"
               $InstancesObjectArray.Add($ObjOracleClient) > $null
           }
       }
   }
   #endregion Oracle x86 Registry

   #region Oracle x64 Registry
   $OracleRegistryx64 = "HKLM:\SOFTWARE\ORACLE"

   if(test-path $OracleRegistryx64){
       $ORAHomeListx64 = Get-childItem -Path $OracleRegistryx64 | Foreach-Object {Get-itemproperty -path $_.PSPath | Select-Object ORACLE_HOME_NAME,ORACLE_HOME }

       Foreach($ORAHome in $ORAHomeListx64){
           if($null -ne $ORAHome.ORACLE_HOME -and (test-path $ORAHome.ORACLE_HOME)){
               $OraVersionx64 = Get-childItem -path $ORAHome.ORACLE_HOME -Recurse -Include "OraClient*.dll" |  Foreach-Object {$_.FullName, [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_).FileVersion} -ErrorAction SilentlyContinue

               $ObjOracleClient = New-Object Psobject
               $ObjOracleClient | Add-Member -Name "Oracle_HomeName" -membertype Noteproperty -Value $ORAHome.ORACLE_HOME_NAME
               $ObjOracleClient | Add-Member -Name "Oracle_Home" -membertype Noteproperty -Value  $ORAHome.ORACLE_HOME

               if ($null -ne $OraVersionx64){
                   $ObjOracleClient | Add-Member -Name "Oracle_Dll" -membertype Noteproperty -Value $OraVersionx64[0]
                   $ObjOracleClient | Add-Member -Name "Oracle_Version" -membertype Noteproperty -Value $OraVersionx64[1]
               }else{
                   $ObjOracleClient | Add-Member -Name "Oracle_Dll" -membertype Noteproperty -Value "Not Found"
                   $ObjOracleClient | Add-Member -Name "Oracle_Version" -membertype Noteproperty -Value "Not Found"
               }

               $ObjOracleClient | Add-Member -Name "Oracle_Platform" -membertype Noteproperty -Value "x64"

               $InstancesObjectArray.Add($ObjOracleClient) > $null
           }
       }
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
