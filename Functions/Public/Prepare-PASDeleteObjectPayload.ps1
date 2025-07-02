###########
#region ### global:Prepare-Prepare-PASDeleteObjectPayload # CMDLETDESCRIPTION : Prepares a delete objects payload for the PAS tenant :
###########
function global:Prepare-PASDeleteObjectPayload
{
    <#
    .SYNOPSIS
    Prepares a delete objects payload for the PAS tenant.

    .DESCRIPTION
    Prepares a delete objects payload for the PAS tenant. This cmdlet does not delete the provided PASObject
    objects, merely the payload to delete them.

    The reason for this design as opposed to a simple "Remove-PASObject" cmdlet is to avoid any accidential
    deletion of PASObject objects.

    Currently only PASAccount and PASSystem objects are supported for deletion.

    .PARAMETER PASObjects
    The PASObjects to prepare for deletion.

    .PARAMETER SaveToSecrets
    Save deleting PASObject information as a File Secret in the Bulk Delete Folder.

    .PARAMETER SecretName
    Sets the name for the File Secret for the saved deleted PASObject information. If not specified,
    will default to "PAS_PCM Bulk Delete - $username - $datetimestamp"

    .PARAMETER SkipIfHasAppsOrServices
    Skip systems with desktop apps or services.

    .PARAMETER SkipDeprovision
    If the provisioned user account cannot be deleted on the target system do not delete the service account from Privileged Access Service.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a JSON object for use as a payload in another Invoke-PASAPI cmdlet

    .EXAMPLE
    C:\PS> Prepare-Prepare-PASDeleteObjectPayload -PASObjects $oldobjects
    Prepares the objects in $oldobjects as a payload for subsiquent account deletion.

    .EXAMPLE
    C:\PS> Prepare-Prepare-PASDeleteObjectPayload -PASObjects $oldobjects -SaveToSecrets -SecretName "oldobjects"
    Prepares the objects in $oldobjects as a payload for subsiquent account deletion. Will 
    save the impending to be deleted objects as a File Secret in the Bulk Delete Folder. The name 
    of the File Secret will be "oldobjects"

    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
        [Parameter(Mandatory = $false, HelpMessage = "The PAS objects to delete.")]
        [PSObject[]]$PASObjects,

        [Parameter(Mandatory = $false, HelpMessage = "Option to save the deleted objects as a File Secret.")]
        [Switch]$SaveToSecrets,

        [Parameter(Mandatory = $false, HelpMessage = "The name of the saved File Secret.")]
        [System.String]$SecretName,

        [Parameter(Mandatory = $false, HelpMessage = "Skip systems with desktop apps or services.")]
        [Switch]$SkipIfHasAppsOrServices,

        [Parameter(Mandatory = $false, HelpMessage = "Skip service accounts if account cannot be deleted on target system.")]
        [Switch]$SkipDeprovision
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # creating an arraylist to store the ids
    $ObjectIds = New-Object System.Collections.ArrayList

    # adding all the ids to the arraylist
    $ObjectIds.AddRange(@($PASObjects.ID)) | Out-Null

    # building the json payload
    $payload = @{}

    # necessary bits
    $payload.Ids = @($ObjectIds)
    $payload.RunSync = $true
    $payload.SetQuery = ""
    $payload.SkipDeprovision         = ($SkipDeprovision.IsPresent) ? $false : $true
    $payload.SkipIfHasAppsOrServices = ($SkipIfHasAppsOrServices.IsPresent) ? $true : $false
    $payload.SaveToSecrets           = ($SaveToSecrets.IsPresent) ? $true : $false

    # if the -SecretName was blank, use the default value
    if ([System.String]::IsNullOrEmpty($SecretName))
    {
        $payload.SecretName = ("PAS_PCM Bulk Delete - {0} - {1}" -f $PASConnection.User, ((Get-Date) | Out-String).Trim())
    }
    else # otherwise
    {
        # use what was specified by -SecretName
        $payload.SecretName = $SecretName
    }

    Write-Host ("Objects to be deleted: [{0}]" -f $ObjectIds.Count)

    return $payload

    #Invoke-PASAPI -APICall ServerManage/DeleteAccounts
    #Invoke-PASAPI -APICall ServerManage/DeleteResources
}# function global:Prepare-Prepare-PASDeleteObjectPayload
#endregion
###########