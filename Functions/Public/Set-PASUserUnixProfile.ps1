###########
#region ### global:Set-PASUserUnixProfile # CMDLETDESCRIPTION : Set a PAS User's UNIX profile information  :
###########
function global:Set-PASUserUnixProfile
{
    <#
    .SYNOPSIS
    Set a PAS User's UNIX Profile Information.

    .DESCRIPTION
	This cmdlet will set a PAS User's UNIX Profile Information. The SetUnixProfile endpoint requires
	the following at a minimum:

	- User - The user to target
	- UnixName - What their login name should be
	- Uid - What their UID should be
	- UPN - the User Principal Name of the user

	Any other parameters that are omitted will leave the existing value in its place.

	Clearing a value simply requires you to specify $null in the optional parameter.

	You need to specify the required parameters of UnixName, Uid, and UPN every time you use this cmdlet. Even
	if you only intent to update one field like GECOS or HomeDirectory. This cmdlet does not get the existing
	values for the user. Use Get-PASUserUnixProfile to get the existing values.

	A future update to this cmdlet will change that behavior.

    .PARAMETER User
	The user account to set the Unix Profile Information.

	.PARAMETER UserName
	The UNIX username that this user will use when logging into Linux/UNIX systems. This parameter is required.

	.PARAMETER Uid
	The UID that this user will use when logging into Linux/UNIX systems. This parameter is required.

	.PARAMETER Gid
	The GID that this user will use when logging into Linux/UNIX systems.

	.PARAMETER UPN
	The UserPrincipalName that this user will use when logging into Linux/UNIX systems. This parameter is required.

	.PARAMETER HomeDirectory
	The Home Directory that this user will use when logging into Linux/UNIX systems.

	.PARAMETER Shell
	The Shell that this user will use when logging into Linux/UNIX systems.

	.PARAMETER GECOS
	The GECOS that this user will use when logging into Linux/UNIX systems.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function returns True if successful, False if it was not successful.

    .EXAMPLE
    C:\PS> Set-PASUserUnixProfile -User "bsmith@domain.com" -UnixName bsmith -Uid 15000 -UPN "bsmith@domain.com"
	Sets the values of UserName, UID, and UPN as UNIX Profile Information for the user bsmith@domain.com

	Although this is the minimum required by the UnixProfile/SetUnixProfile endpoint, this by itself is not a
	complete UNIX profile, and will most likely cause a user to fail to log in if the other fields are not
	completed.

	.EXAMPLE
	C:\PS> Set-PASUserUnixProfile -User "bsmith@domain.com" -UnixName bsmith -Uid 15000 -Gid 1000 -UPN "bsmith@domain.com" -HomeDirectory "/home/bsmith" -Shell "/bin/bash" -GECOS "Barry Smith"
	Sets the values listed in the cmdlet for the user bsmith@domain.com.

	.EXAMPLE
	C:\PS> Set-PASUserUnixProfile -User "bsmith@domain.com" -UnixName bsmith -Uid 15000 -UPN "bsmith@domain.com" -HomeDirectory "/home/bsmith2"
	Sets the values listed in the cmdlet for the user bsmith@domain.com. Only updating the HomeDirectory value since the parameter was specified.
	Any values listed in GID, Shell, and GECOS will remain the same value.

    .EXAMPLE
	C:\PS> Set-PASUserUnixProfile -User "bsmith@domain.com" -UnixName bsmith -Uid 15000 -UPN "bsmith@domain.com" -GECOS $null
	Sets the values listed in the cmdlet for the user bsmith@domain.com. Clears the value in the GECOS field. All other fields will
	remain the same value.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The users to Set UNIX Profile Information")]
		[System.String]$User,

		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Username to use when logging into Linux/UNIX systems.")]
		[System.String]$UserName,

		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Uid to use when logging into Linux/UNIX systems.")]
		[System.String]$Uid,

		[Parameter(Mandatory = $false, Position = 0, HelpMessage = "The Gid to use when logging into Linux/UNIX systems.")]
		[System.String]$Gid,

		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The UPN to use when logging into Linux/UNIX systems.")]
		[System.String]$UPN,

		[Parameter(Mandatory = $false, Position = 0, HelpMessage = "The HomeDirectory to use when logging into Linux/UNIX systems.")]
		[System.String]$HomeDirectory,

		[Parameter(Mandatory = $false, Position = 0, HelpMessage = "The Shell to use when logging into Linux/UNIX systems.")]
		[System.String]$Shell,

		[Parameter(Mandatory = $false, Position = 0, HelpMessage = "The GECOS to use when logging into Linux/UNIX systems.")]
		[System.String]$GECOS
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# try to find the user
	Try
	{
		if (-Not ($UserUUID = Query-RedRock -SQLQuery ("SELECT InternalName AS ID FROM DSUsers WHERE SystemName = '{0}'" -f $User) | Select-Object -ExpandProperty ID))
		{
			Write-Host ("User [{0}] not found." -f $User)
			return $false
		}
	}
	Catch
	{
		# if an error occurred when trying to find the user, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error finding PAS user.")
		$e.AddExceptionData($_)
		$e.AddData("User",$User)
		$e.AddData("UserUUID",$UserUUID)
		return $e
	}# Catch

	# preparing profile information, adding in optional parameters if they were used.
	$UnixProfile = @{}
	$UnixProfile.UnixName = $UserName
	$UnixProfile.Uid      = $Uid
	if ($PSBoundParameters.ContainsKey('Gid') -and $Gid -eq $null)                     { $UnixProfile.Gid = $null }
		elseif ($PSBoundParameters.ContainsKey('Gid'))                                 { $UnixProfile.Gid = $Gid }
	$UnixProfile.UPN      = $UPN
	if ($PSBoundParameters.ContainsKey('HomeDirectory') -and $HomeDirectory -eq $null) { $UnixProfile.Home = $null }
		elseif ($PSBoundParameters.ContainsKey('HomeDirectory'))                       { $UnixProfile.Home = $HomeDirectory }
	if ($PSBoundParameters.ContainsKey('Shell') -and $Shell -eq $null)                 { $UnixProfile.Shell = $null }
		elseif ($PSBoundParameters.ContainsKey('Shell'))                               { $UnixProfile.Shell = $Shell }
	if ($PSBoundParameters.ContainsKey('GECOS') -and $GECOS -eq $null)                 { $UnixProfile.Gecos = $null }
		elseif ($PSBoundParameters.ContainsKey('GECOS'))                               { $UnixProfile.Gecos = $GECOS }

	# preparing JSON body
	$JsonData = @{}
	$JsonData.UnixProfile = $UnixProfile
	$JsonData.ID          = $UserUUID

	Try
	{
		# attempt to set the profile
		Invoke-PASAPI -APICall UnixProfile/SetUserProfile -Body ($JsonData | ConvertTo-Json)

		return $true
	}
	Catch
	{
		# if an error occurred when trying to set the user profile, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error Setting User UNIX Profile information.")
		$e.AddExceptionData($_)
		$e.AddData("User",$User)
		$e.AddData("UserUUID",$UserUUID)
		$e.AddData("JsonData",$JsonData)
		return $e
	}

	# if we get here, it failed
	return $false
}# function global:Set-PASUserUnixProfile
#endregion
###########