<#
.SYNOPSIS
  Create inventory for all object in local Administrator
.DESCRIPTION
  This script is for detroy unwanted or useless WMI Class.
  Be carrefeull when you do This, Destroy System class can made several damage to your system.
.NOTES
  Version:        1.0
  Author:         Letalys
  Creation Date:  27/10/2023
  Purpose/Change: Initial
.LINK
    Author : Letalys (https://github.com/Letalys)
.LINK
    Thanks : https://github.com/Robert-LTH | https://github.com/Robert-LTH/Powershell/blob/master/Remove-CimClass.ps1
#>

$VerbosePreference = 'SilentlyContinue'

Function Remove-WMIInstance{
    [CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()][Parameter(Mandatory=$true)][string]$ClassName
	)
    
    $PathString = "\\{0}\{1}:{2}" -f ".","root\cimv2",$ClassName
    $MgmtPath = [System.Management.ManagementPath]::new($PathString)

    Write-Verbose "Deleting class $Classname ..."

    if ($MgmtPath.IsClass) {
        try{
            $MgmtClass = [System.Management.ManagementClass]::new($MgmtPath)
            $MgmtClass.Get() 
            $MgmtClass.Delete()
        }catch{
            Write-Verbose "$Classname Error : $($_)"
        }

    }
    else {
        Write-Verbose "ManagementPath does not point to a class!"
    }

}

Try{
    $ClassNameList = @(
        "ClassName1",
        "ClassName2"
    )

    foreach($ClassName in $ClassNameList){
        Remove-WMIInstance -ClassName $ClassName
    }
     return 0
}catch{
    Write-Host "An error occurred : "
    Write-Host "$($_.InvocationInfo.ScriptLineNumber) : $($_)"

    Write-Verbose $_
    Write-Verbose "Return -1 for general error"
    return -1
}
