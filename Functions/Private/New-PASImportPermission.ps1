###########
#region ### global:New-PASImportPermission # CMDLETDESCRIPTION : Builds a new PASImportPermission from existing PermissionRowAces :
###########
function global:New-PASImportPermission
{
    <#
    .SYNOPSIS
    Builds a new PASImportPermission from existing PermissionRowAces.

    .DESCRIPTION
    This cmdlet will build a PASImportPermission class object based on provided PermissionRowAces from existing PAS PCM objects.

    The intent with this cmdlet is to help build a json body payload for recreating or setting permissions for principals in a 
    PAS tenant.

    This cmdlet will most likely be used with Build-PASGrantPermissionPayload to build the custom json body needed to update
    PermissionRowAces in PAS.

    .PARAMETER PermissionRowAces
	The existing PermissionRowAces to import.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs an ArrayList of PASImportPermissions objects.

    .EXAMPLE
    C:\PS> $imports = New-PASImportPermission -PermissionRowAces $myrootAccount.PermissionRowAces
    For each PermissionRowAces found in $myrootAccount, build one PASImportPermission object.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The PermissionRowAces data to process.")]
		[PSObject[]]$PermissionRowAces
    )

    # arraylist for the imports
    $ImportsToReturn = New-Object System.Collections.ArrayList

    foreach ($permissionrow in $PermissionRowAces)
    {
        $obj = New-Object PASImportPermission -ArgumentList $permissionrow

        $ImportsToReturn.Add($obj) | Out-Null
    }

    return $ImportsToReturn
}# function global:New-PASImportPermission
#endregion
###########