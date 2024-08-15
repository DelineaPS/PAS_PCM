###########
#region ### global:Get-PASUserUnixProfile # CMDLETDESCRIPTION : Gets a PAS User's UNIX profile information :
###########
function global:Get-PASUserUnixProfile
{
    <#
    .SYNOPSIS
	Get the PAS-defined UNIX profile information for a PAS user.

    .DESCRIPTION
	This cmdlet will get the PAS-defined UNIX profile information for a specified user. The PAS-defined
	UNIX profile information refers to the UNIX profile that is specified under the UNIX Profile section
	when viewing that user in Access -> Users -> specific user. This does not refer to the UNIX Profile
	information that exists for the user on Linux/UNIX systems, or defined by Server Suite.

    .PARAMETER User
	The user to get the PAS-defined UNIX Profile information.
	
    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function returns a PASUserUnixProfile object if successful, or False 
	if it was not successful.

    .EXAMPLE
    C:\PS> Get-PASUserUnixProfile -Users "bsmith@domain.com"
	Gets the PAS-defined UNIX Profile information for the user bsmith@domain.com.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The user to get the PAS-defined UNIX Profile information.")]
		[System.String]$User
    )

    # verifying an active PAS connection
    Verify-PASConnection

	# get the ID and DisplayName of the provided users
	$ID = Query-RedRock -SQLQuery ("SELECT InternalName AS ID FROM DsUsers WHERE SystemName IN ({0})" -f (($User -replace '^(.*)$',"'`$1'") -join ",")) | Select-Object -ExpandProperty ID

	# preparing the json data
	$JsonData = @{}
	$JsonData.ID = $ID

	Try
	{
		# make the attempt
		$UnixData = Invoke-PASAPI -APICall UnixProfile/GetUserProfile -Body ($JsonData | ConvertTo-Json -Compress)

		$PASUnixProfile = New-Object PASUserUnixProfile -ArgumentList $UnixData

		return $PASUnixProfile
	}
	Catch
	{
		# if an error occurred during the call, create a new PASException and return that with the relevant data
		$e = New-Object PASPCMException -ArgumentList ("Error getting PAS UNIX Profile Information.")
		$e.AddExceptionData($_)
		$e.AddData("User",$User)
		$e.AddData("JsonData",$JsonData)
		$e.AddData("UnixData",$UnixData)
		$e.AddData("PASUnixProfile",$PASUnixProfile)
		return $e
	}

	# if we get here, the attempt failed
	return $false
}# function global:Get-PASUserUnixProfile
#endregion
###########