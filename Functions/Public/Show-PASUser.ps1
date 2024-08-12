###########
#region ### global:Show-PASUser # CMDLETDESCRIPTION : Make a user display in the Users section :
###########
function global:Show-PASUser
{
    <#
    .SYNOPSIS
    Causes a user to display in the Users section of the connected PAS tenant.

    .DESCRIPTION
	This cmdlet causes a user to appear in the Users section of the connected PAS tenant. By default,
	not all users are displayed in the Users section of a PAS tenant. This is for performance reasons.
	But if there is a need to set information about a user, that user either needs to be invited via
	email, or log onto the tenant first.

	However in some situations, this may not be desirable. So this cmdlet will cause a user to display
	without sending them an invite or having them log in first.

    .PARAMETER Users
	The user accounts to appear in the Users section.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function returns True if successful, False if it was not successful.

    .EXAMPLE
    C:\PS> Show-PASUser -Users "bsmith@domain.com"
	Makes the users "bsmith@domain.com" appear in the Users section of the PAS tenant.

	.EXAMPLE
    C:\PS> Show-PASUser -Users "bsmith@domain.com","mjohnson@domain.com"
	Makes the users "bsmith@domain.com" and "mjohnson@domain.com" appear in the Users 
	section of the PAS tenant.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The users to appear in the Users section")]
		[System.String[]]$Users
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# get the ID and DisplayName of the provided users
	$UserData = Query-RedRock -SQLQuery ("SELECT InternalName AS ID,DisplayName FROM DsUsers WHERE SystemName IN ({0})" -f (($Users -replace '^(.*)$',"'`$1'") -join ","))

	# arraylist to set user information
	$Entities = New-Object System.Collections.ArrayList

	# for each user in the UserData, set fields
	# side note, I don't know why Name is required by this endpoint but it is
	foreach ($user in $UserData)
	{
		$obj = @{}
		$obj.Type = "User"
		$obj.Guid = $user.ID
		$obj.Name = $user.DisplayName
		$Entities.Add($obj) | Out-Null
	}# foreach ($user in $UserData)

	# preparing the json data
	$Json = @{}
	$Json.Entities    = $Entities
	$Json.EmailInvite = $false
	$Json.SmsInvite   = $false

	Try
	{
		# make the attempt
		Invoke-PASAPI -APICall UserMgmt/InviteUsers -Body ($Json | ConvertTo-Json -Compress)

		return $true
	}
	Catch
	{
		# if an error occurred during the call, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error showing PAS Users.")
		$e.AddExceptionData($_)
		$e.AddData("User",$User)
		$e.AddData("UserUUID",$UserUUID)
		$e.AddData("RedirectedUUID",$RedirectedUUID)
		$e.AddData("RedirectMFAToUser",$RedirectMFAToUser)
		return $e
	}

	# if we get here, the attempt failed
	return $false
}# function global:Show-PASUser
#endregion
###########