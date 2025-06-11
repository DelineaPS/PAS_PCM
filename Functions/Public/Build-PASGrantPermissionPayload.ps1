###########
#region ### global:Build-PASGrantPermissionPayload # CMDLETDESCRIPTION : Builds the jsonbody payload to update permissions on a PAS object :
###########
function global:Build-PASGrantPermissionPayload
{
    <#
    .SYNOPSIS
    Builds the jsonbody payload to update permissions on a PAS object.

    .DESCRIPTION
	This cmdlet will prepare a special JSON body payload to update the permissions of principals on a PAS Object.

    This cmdlet should be used after New-PASImportPermission

    .PARAMETER PASImportPermissions
	The specially prepared imported PAS permission objects to process.

    .PARAMETER TargetUuid
    The Uuid of the PAS Object to update.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a JSON body payload.

    .EXAMPLE
    C:\PS> $jsonbody = Build-PASGrantPermissionPayload -PASImportPermissions $PASImportPermissions -TargetUuid "ffffffff-ffff-ffff-ffff-ffffffffffff"
    Prepares the JSON body payload for the specially prepared PermissionRowAces.

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The specially prepared PermissionRowAces.")]
		[PSObject]$PASImportPermissions,

        [Parameter(Mandatory = $true, HelpMessage = "The Uuid of the PAS Object to target.")]
        [System.String]$TargetUuid
    )

	$ReturnedPayload = $null

    # initial build of json body
    $jsonbody        = @{}
    $jsonbody.ID     = $TargetUuid
    $jsonbody.RowKey = $TargetUuid
    $jsonbody.PVID   = $TargetUuid

    # arraylist for the grants
    $GrantsToReturn = New-Object System.Collections.ArrayList

    $GrantsToReturn.AddRange(@($PASImportPermissions)) | Out-Null

    $jsonbody.Grants = $GrantsToReturn

    return $jsonbody | ConvertTo-Json -Compress
}# function global:Build-PASGrantPermissionPayload
#endregion
###########