###########
#region ### global:Search-PASDirectory # Searches existing directories for principals or roles and returns the Name and ID by like searches
###########
function global:Search-PASDirectory
{
    <#
    .SYNOPSIS
    This function will retrieve the UUID of the specified principal from all reachable tenant directories.

    .DESCRIPTION
    This function will retrieve the UUID of the specified principal from all reachable tenant directories. The searches made
    by principal is a like search, so any matching query will be returned. For example, searching for -Role "System" will
    return any Role with "System" in the name.

    .PARAMETER User
    Search for a user by their User Principal Name. For example, "person@domain.com"

    .PARAMETER Group
    Search for a group by their Group and domain. For example, "WidgetAdmins@domain.com"

    .PARAMETER Role
    Search for a role by the Role name. For example, "System"

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PSCustomObject with the Name of the principal and the UUID.

    .EXAMPLE
    C:\PS> Search-PASDirectory -User "person@domain.com"
    Searches all reachable tenant directories (AD, Federated, etc.) to find a person@domain.com and if successful, return the 
    tenant's UUID for this user.

    .EXAMPLE
    C:\PS> Search-PASDirectory -Group "WidgetAdmins@domain.com"
    Searches all reachable tenant directories (AD, Federated, etc.) to find the group WidgetAdmins@domain.com and if successful,
    return the tenant's UUID for this group.
    #>
    param
    (
		[Parameter(Mandatory = $true, HelpMessage = "Specify the User to find from DirectoryServices.",ParameterSetName = "User")]
		[System.Object]$User,

		[Parameter(Mandatory = $true, HelpMessage = "Specify the Group to find from DirectoryServices.",ParameterSetName = "Group")]
		[System.Object]$Group,

		[Parameter(Mandatory = $true, HelpMessage = "Specify the Role to find from DirectoryServices.",ParameterSetName = "Role")]
		[System.Object]$Role
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # building the query from parameter set
    Switch ($PSCmdlet.ParameterSetName)
    {
        "User"  { $query = ("SELECT InternalName AS ID,SystemName AS Name FROM DSUsers WHERE SystemName LIKE '%{0}%'" -f $User); break }
        "Role"  { $query = ("SELECT ID,Name FROM Role WHERE Name LIKE '%{0}%'" -f ($Role -replace "'","''")); break }
        "Group" { $query = ("SELECT InternalName AS ID,SystemName AS Name FROM DSGroups WHERE SystemName LIKE '%{0}%'" -f $Group); break }
    }

    Write-Verbose ("SQLQuery: [{0}]" -f $query)

    # make the query
    $sqlquery = Query-RedRock -SqlQuery $query

    # new ArrayList to hold multiple entries
    $principals = New-Object System.Collections.ArrayList

    # if the query isn't null
    if ($sqlquery -ne $null)
    {
        # for each secret in the query
        foreach ($principal in $sqlquery)
        {
            # Counter for the principal objects
            $p++; Write-Progress -Activity "Processing Principals into Objects" -Status ("{0} out of {1} Complete" -f $p,$sqlquery.Count) -PercentComplete ($p/($sqlquery | Measure-Object | Select-Object -ExpandProperty Count)*100)
            
            # creating the PASPrincipal object
			$obj = New-Object PASPrincipal -ArgumentList ($principal.Name, $principal.ID)

            $principals.Add($obj) | Out-Null
        }# foreach ($principal in $sqlquery)
    }# if ($sqlquery -ne $null)

    return $principals
}# function global:Search-PASDirectory
#endregion
###########