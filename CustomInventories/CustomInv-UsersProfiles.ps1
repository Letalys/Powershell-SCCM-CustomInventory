<#
.SYNOPSIS
  Create Inventory for User session present in computer
.DESCRIPTION
  The create a custom inventory of all User session on the machine, connecting to Active Directory to retrieving User Information
.OUTPUTS
  Explaination of the new WMI Class and properties and the ClassPath
    CustomInventory_UsersProfiles :: Root\Cimv2
        "SSID" : Get the User SSID from the local registry
        "Profile" : Get the User Profile path from the local registry
        "Session" : Get the User session name from the local
        "UserFullName" : Get the User mail from ActiveDirectory
        "UserDescription" : Get the User Description from ActiveDirectory
        "UserMail" : Get the User mail from ActiveDirectory
  >
.NOTES
    You need to fill remote connexion Properties to get ActiveDirectory Module from another computer or server. (L152)
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
Function Open-RemotePSSessionForADModule{
    Param(
        [Parameter(Mandatory=$true)][String]$UserName,
        [Parameter(Mandatory=$true)][String]$UserPwd,
        [Parameter(Mandatory=$true)][String]$ComputerName
    )

    $secStringPassword = ConvertTo-SecureString $UserPwd -AsPlainText -Force
    $credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

    $S = New-PSSession -ComputerName $ComputerName -Credential $credObject
    Export-PSsession -Session $S -Module ActiveDirectory -OutputModule RemoteAD -Force -AllowClobber -ErrorAction SilentlyContinue

    Import-Module RemoteAD -Force -ErrorAction SilentlyContinue
    Set-Variable -Name "GlobCurrentPSSession" -Value $S -Scope Global -Force  -ErrorAction SilentlyContinue
}
Function Close-RemotePSSessionForADMOdule{
    Remove-PSSession -Session $GlobCurrentPSSession
}

#region Custom Class Definition
$TemplateObject = New-Object PSObject
$TemplateObject | Add-Member -MemberType NoteProperty -Name "SSID" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Profile" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "Session" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserFullName" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserDescription" -Value $null
$TemplateObject | Add-Member -MemberType NoteProperty -Name "UserMail" -Value $null

New-WMIClass -ClassName "CustomInventory_UsersProfiles" -ClassTemplate $TemplateObject
#endregion Custom Class Definition

Try{
    #region Custom Code
    #Define the ArrayList for your Instances Objects
    [System.Collections.Arraylist]$InstancesObjectArray =@()

    $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
    $ProfileList = Get-ChildItem -Path $RegistryKey

    #Open Remote Session to computer who have Module ActiveDirectory for Import if you d'ont want install the module on all your machine, 
    # may be you can use [ADSI] instead of ActiveDirectory Module 
    # but you need the CCM account have rights to connect
    Open-RemotePSSessionForADModule -UserName "-----------" -UserPwd "-------------" -ComputerName "----------"

    foreach($Profile in $ProfileList){
        $CurrentSID = $Profile.Name.Replace("HKEY_LOCAL_MACHINE\$RegistryKey",$null)
        $CurrentProfilePath = $Profile | Get-itemproperty | Select-Object ProfileImagePath

        if($CurrentProfilePath.ProfileImagePath -like "C:\Users\*"){
            $CurrentUserProfil = $($CurrentProfilePath.ProfileImagePath).replace("C:\Users\",$null)
            $CurrentUserSID = $CurrentSID

            Invoke-Command -Session $GlobCurrentPSSession -ScriptBlock {
                param($RemotePSSessionVar) $RemoteValue = $RemotePSSessionVar
            } -ArgumentList $CurrentUserProfil

            $ADquery = Invoke-Command -Session $GlobCurrentPSSession -ScriptBlock {
                Get-ADUSer -Filter {sAMAccountName -eq $RemoteValue} -Properties Description, DisplayName, mail, sAMAccountName 
                | Select-Object Description, DisplayName, mail,sAMAccountName }

            $CreateUserProfilObject = New-Object Psobject
            $CreateUserProfilObject | Add-Member -Name "Key" -membertype Noteproperty -Value $CurrentUserSID
            $CreateUserProfilObject | Add-Member -Name "SSID" -membertype Noteproperty -Value $CurrentUserSID
            $CreateUserProfilObject | Add-Member -Name "Profil" -membertype Noteproperty -Value $CurrentUserProfil
            $CreateUserProfilObject | Add-Member -Name "Session" -membertype Noteproperty -Value $ADquery.sAMAccountName
            $CreateUserProfilObject | Add-Member -Name "NomComplet" -membertype Noteproperty -Value  $ADquery.DisplayName
            $CreateUserProfilObject | Add-Member -Name "Description" -membertype Noteproperty -Value  $ADquery.Description
            $CreateUserProfilObject | Add-Member -Name "Contact" -membertype Noteproperty -Value  $ADquery.Mail

            #Add Your Object to The ArrayList
            $InstancesObjectArray.Add($CreateUserProfilObject) | Out-Null
        }
        
    }

    #Convert all object in Array to WMI Instance
    Add-WMIInstances -ClassName "CustomInventory_UsersProfiles" -ObjectArrayList $InstancesObjectArray
    #endregion Custom Code

    #Invoke Hardware Inventory
    Invoke-CCMHardwareInventory
    return 0 #Script Process With Success (return 0 for SCCM)
}catch{
    Write-error "$($_.InvocationInfo.ScriptLineNumber) : $($_)"
    Return -1 #Script Failed  (return -1 for SCCM)
}