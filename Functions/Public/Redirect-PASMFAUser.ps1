###########
#region ### global:Redirect-PASMFAUser # CMDLETDESCRIPTION : Redirects MFA authentication from one user to another or clears it :
###########
function global:Redirect-PASMFAUser
{
    <#
    .SYNOPSIS
    Redirects MFA authentication from one user to another. Or it clears MFA redirection on a user.

    .DESCRIPTION
	Enables redirection of MFA authentication from one user to another. Typically this is so that
	MFA authentication from a privileged account can be redirect to a user's standard account. For
	example, redirecting the account 'bsmith-adm' MFA attempts to account 'bsmith'. This helps
	consolidates MFA tokens to fewer accounts.

	This cmdlet can also be used to clear MFA redirection.

	This cmdlet requires Sysadmin level privileges on the connected PAS tenant.

    .PARAMETER User
	The user account to set redirection on. For example, 'bsmith-adm'.

	.PARAMETER RedirectMFAToUser
	The user account to redirect MFA authentication to. For example, 'bsmith'.

	.PARAMETER ClearMFARedirect
	Clears MFA redirection.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function returns True if successful, False if it was not successful.

    .EXAMPLE
    C:\PS> Redirect-PASMFAUser -User "bsmith-adm@domain.com" -RedirectMFAToUser "bsmith@domain.com"
	Redirects "bsmith-adm@domain.com" MFA authentication to "bsmith@domain.com" account.

	.EXAMPLE
    C:\PS> Redirect-PASMFAUser -User "bsmith-adm@domain.com" -ClearMFARedirect
	Clears MFA redirection on account "bsmith-adm@domain.com".
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Sets to determine the owner", ParameterSetName = "Redirect")]
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Sets to determine the owner", ParameterSetName = "ClearRedirect")]
		[System.String]$User,

		[Parameter(Mandatory = $true, Position = 1, HelpMessage = "The PAS Sets to determine the owner", ParameterSetName = "Redirect")]
		[System.String]$RedirectMFAToUser,

		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The PAS Sets to determine the owner", ParameterSetName = "ClearRedirect")]
		[Switch]$ClearMFARedirect
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# first get the UUID of the target user
	Try
	{
		$UserUUID = Get-PASObjectUuid -Type User -Name $User

		if ($UserUUID -eq $false)
		{
			Write-Host ("User [{0}] not found." -f $User)
			return $false
		}
	}# Try
	Catch
	{
		# if an error occurred Getting the UUID, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error during getting the UUID of the target user.")
		$e.AddExceptionData($_)
		$e.AddData("User",$User)
		$e.AddData("UserUUID",$UserUUID)
		$e.AddData("RedirectMFAToUser",$RedirectMFAToUser)
		return $e
	}# Catch
	
	if ($ClearMFARedirect.IsPresent)
	{
		$RedirectedUUID = $null
	}
	else
	{
		# first get the UUID of the user to redirect MFA to
		Try
		{
			$RedirectedUUID = Get-PASObjectUuid -Type User -Name $RedirectMFAToUser

			if ($RedirectedUUID -eq $false)
			{
				Write-Host ("Redirected User [{0}] not found." -f $RedirectMFAToUser)
				return $false
			}
		}# Try
		Catch
		{
			# if an error occurred Getting the UUID, create a new PASException and return that with the relevant data
			$e = New-Object PASPCMException -ArgumentList ("Error during getting the UUID of the redirected user.")
			$e.AddExceptionData($_)
			$e.AddData("User",$User)
			$e.AddData("UserUUID",$UserUUID)
			$e.AddData("RedirectedUUID",$RedirectedUUID)
			$e.AddData("RedirectMFAToUser",$RedirectMFAToUser)
			return $e
		}# Catch
	}# else
	
	# attempt the redirect
	Try
	{
		Invoke-PASAPI -APICall UserMgmt/ChangeUserAttributes -Body (@{ID=$UserUUID;CmaRedirectedUserUuid=$RedirectedUUID} | ConvertTo-Json)

		return $true
	}# Try
	Catch
	{
		# if an error occurred Getting the UUID, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error during setting the MFA Redirect.")
		$e.AddExceptionData($_)
		$e.AddData("User",$User)
		$e.AddData("UserUUID",$UserUUID)
		$e.AddData("RedirectedUUID",$RedirectedUUID)
		$e.AddData("RedirectAttempt",$RedirectAttempt)
		$e.AddData("RedirectMFAToUser",$RedirectMFAToUser)
		return $e
	}# Catch
	Finally
	{
		# nulling values to free memory
		$User = $null
		$UserUUID = $null
		$RedirectedUUID = $null
		$RedirectAttempt = $null
		$RedirectMFAToUser = $null
	}# Finally

	# if we get here, the attempt failed
	return $false
}# function global:Redirect-PASMFAUser
#endregion
###########