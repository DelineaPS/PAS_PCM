###########
#region ### global:Remove-PASUser # CMDLETDESCRIPTION : Remove a PAS User from the Access -> Users section :
###########
function global:Remove-PASUser
{
    <#
    .SYNOPSIS
	Removes a user from the Users section. Will delete Centrify Directory Users (CDU).

    .DESCRIPTION
	This cmdlet will "delete" a user from the Access -> Users section of PAS. If the user is a 
	Centrify Directory User (CDU), this is a true user deletion, and the user must be recreated to be used
	again. If the user is an Active Directory/Federated User, the user is not deleted by the "PAS"
	version of them is deleted. That user will still be able to relog into PAS but any custom information
	set about this user that was PAS-specific will need to be recreated.

	This cmdlet is really only needed for recreating a PAS User's Unix Profile Information. At this
	time, there is no way to fully clear a PAS User's Unix Profile Information once it has been set.
	The only way to do this would be to "delete" the user and recreate/reshow them. There is no RestAPI
	endpoint that can clear a Unix Profile; only the Get and Set endpoints exist, and Set doesn't allow
	for all fields to be null.

	This cmdlet is only useful if you need to completely clear out a non-Centrify Directory User's 
	Unix Profile Information. For CDUs, it will completely delete the user object.

    .PARAMETER User
	The user account to remove from the PAS -> Access -> Users section.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function returns True if successful, False if it was not successful.

    .EXAMPLE
    C:\PS> Remove-PASUser -User "bsmith@domain.com"
	Removes the user "bsmith@domain.com" from the PAS -> Access -> Users section. If this
	was a Centrify Directory User, this deletes the user object.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The user to remove.")]
		[System.String[]]$User
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# get the ID and DisplayName of the provided users
	$UserUUIDs = Query-RedRock -SQLQuery ("SELECT InternalName AS ID FROM DsUsers WHERE SystemName IN ({0})" -f (($Users -replace '^(.*)$',"'`$1'") -join ",")) | Select-Object -ExpandProperty ID

	# preparing the json data
	$JsonData = @{}
	$JsonData.Users = $UserUUIDs

	Try
	{
		# make the attempt
		Invoke-PASAPI -APICall UserMgmt/RemoveUsers -Body ($JsonData | ConvertTo-Json -Compress)

		return $true
	}
	Catch
	{
		# if an error occurred during the call, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error removing PAS Users.")
		$e.AddExceptionData($_)
		$e.AddData("Users",$Users)
		$e.AddData("JsonData",$JsonData)
		return $e
	}

	# if we get here, the attempt failed
	return $false
}# function global:Remove-PASUser
#endregion
###########