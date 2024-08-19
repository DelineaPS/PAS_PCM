###########
#region ### global:Build-PASSetMetricsReport # CMDLETDESCRIPTION : Builds a PAS Set Metrics Report for Set review :
###########
function global:Build-PASSetMetricsReport
{
    <#
    .SYNOPSIS
    Builds a PAS Set Metrics Report for Set review.

    .DESCRIPTION
	This cmdlet takes Set Report Cards and compiles it into a high-level overview data object for Set Review with
	an environment. The intent with this cmdlet is to provide a means for environments to review all of their
	Account Sets and decide which Sets to keep, ignore, or collapse as part of a PAS vaulting to Secret Server
	Cloud vaulting migration. 

    .PARAMETER SetReportCards
	The PAS Set Report Cards to provide to build the custom data object.

    .PARAMETER RemoveThese
	Removes the specified principals from the Principals column in the resulting object. This would be used
	to remove principals that have global access and would appear on every account. This simply removes those
	principals from being listed in the Princials property.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a custom PSObject object.

    .EXAMPLE
    C:\PS> Build-PASSetMetricsReport -SetReportCards $SetReportCards
	Builds the PAS Set Metrics Report for the provided Set Reports Cards in $SetReportCards.

    .EXAMPLE
    C:\PS> Build-PASSetMetricsReport -SetReportCards $SetReportCards -RemoveThese "System Administrator","cloudadmin@domain"
	Builds the PAS Set Metrics Report for the provided Set Reports Cards in $SetReportCards. In addition,
	any sets where the Principals "System Administrator" or "cloudadmin@domain" are listed as having permissions,
	those Principals will not be listed in the resulting Principals property of the returned Metrics Report object.
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param
    (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Set Report Cards to evaluate.")]
		[PSObject[]]$SetReportCards,

		[Parameter(Mandatory = $false, HelpMessage = "Remove these principals from the Principals property on the returned object.")]
		[System.String[]]$RemoveThese
    )

	# ArrayList for the returned object
	$MetricsReport = New-Object System.Collections.ArrayList

	# for each ReportCard provided to us
	foreach ($ReportCard in $SetReportCards)
	{
		# if RemoveThese was used
		if ($PSBoundParameters.ContainsKey('RemoveThese'))
		{
			# get the principals for this Set Report Card, but remove those that appear in RemoveThese
			$principals = ($ReportCard.MemberPermissions.PrincipalName | Select-Object -Unique | Where-Object {$RemoveThese -notcontains $_}) -join ","
		}
		else #otherwise
		{
			# get the principals for this Set Report Card
			$principals = ($ReportCard.MemberPermissions.PrincipalName | Select-Object -Unique) -join ","
		}

		# get conflicting sets
		$conflictingsets = ($ReportCard.Conflicts.InSets | Select-Object -Unique) -join ","

		# if there are no conflicting sets
		if ([System.String]::IsNullOrEmpty($conflictingsets))
		{
			# set it to "NONE"
			$conflictingsets = "NONE"
		}

		# creating the return object
		$obj = New-Object PSObject

		# adding the properties
		$obj | Add-Member -MemberType NoteProperty -Name SetName         -Value $ReportCard.SetName
		$obj | Add-member -MemberType NoteProperty -Name Action          -Value $null
		$obj | Add-Member -MemberType NoteProperty -Name Notes           -Value $null
		$obj | Add-Member -MemberType NoteProperty -Name TargetFolder    -Value $null
		$obj | Add-Member -MemberType NoteProperty -Name TotalAccounts   -Value $ReportCard.Members.Count
		$obj | Add-Member -MemberType NoteProperty -Name TotalParents    -Value ($ReportCard.Members.SourceName | Select-Object -Unique).Count
		$obj | Add-Member -MemberType NoteProperty -Name TotalManaged    -Value ($ReportCard.Members | Where-Object -Property isManaged -eq $true).Count
		$obj | Add-Member -MemberType NoteProperty -Name TotalUnmanaged  -Value ($ReportCard.Members | Where-Object -Property isManaged -eq $false).Count
		$obj | Add-Member -MemberType NoteProperty -Name Users           -Value (($ReportCard.Members.Username | Select-Object -Unique) -join ",")
		$obj | Add-Member -MemberType NoteProperty -Name OKParents       -Value ($ReportCard.Members | Where-Object -Property SourceHealthStatus -eq OK).Count
		$obj | Add-Member -MemberType NoteProperty -Name OKAccounts      -Value ($ReportCard.Members | Where-Object -Property Healthy -eq OK).Count
		$obj | Add-Member -MemberType NoteProperty -Name NotOKParents    -Value ($ReportCard.Members | Where-Object -Property SourceHealthStatus -ne OK).Count
		$obj | Add-Member -MemberType NoteProperty -Name NotOKAccounts   -Value ($ReportCard.Members | Where-Object -Property Healthy -ne OK).Count
		$obj | Add-Member -MemberType NoteProperty -Name ActivityCount   -Value ($ReportCard.Members.AccountActivity).Count
		$obj | Add-Member -MemberType NoteProperty -Name Principals      -Value $principals
		$obj | Add-Member -MemberType NoteProperty -Name ConflictingSets -Value $conflictingsets

		# adding it to our ArrayList
		$MetricsReport.Add($obj) | Out-Null
	}# foreach ($ReportCard in $SetReportCards)

	# returning the Metrics Report object
	return $MetricsReport
}# function global:Build-PASSetMetricsReport