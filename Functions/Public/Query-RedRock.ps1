###########
#region ### global:Query-RedRock # CMDLETDESCRIPTION : Make a SQL RedRock query to the tenant :
###########
function global:Query-RedRock
{
    <#
    .SYNOPSIS
    This function makes a direct SQL query to the SQL tables of the connected PAS tenant.

    .DESCRIPTION
    This function makes a direct SQL query to the SQL tables of the connected PAS PAS tenant. Most SELECT SQL queries statements will work to query data.

    .PARAMETER SQLQuery
    The SQL Query to run. Most SELECT queries will work, as well as most JOIN, CASE, WHERE, AS, COUNT, etc statements.

    .INPUTS
    None. You can't redirect or pipe input to this function.

    .OUTPUTS
    This function outputs a PSCustomObject with the requested data.

    .EXAMPLE
    C:\PS> Query-RedRock -SQLQuery "SELECT * FROM Sets"
    This query will return all rows and all property fields from the Sets table.

    .EXAMPLE
    C:\PS> Query-RedRock -SQLQuery "SELECT COUNT(*) FROM Servers"
    This query will return a count of all the rows in the Servers table.

    .EXAMPLE
    C:\PS> Query-RedRock -SQLQuery "SELECT Name,User AS AccountName FROM VaultAccount LIMIT 10"
    This query will return the Name property and the User property (renamed AS AccountName) from the VaultAccount table and limiting those results to 10 rows.
    #>
    param
    (
		[Parameter(Position = 0, Mandatory = $true, HelpMessage = "The SQL query to execute.")]
		[System.String]$SQLQuery
    )

    # verifying an active PAS connection
    Verify-PASConnection

    # Set Arguments
	$Arguments = @{}
	$Arguments.SortBy	 	= ""
	$Arguments.Direction 	= "False"
	$Arguments.Caching		= 0
	$Arguments.FilterQuery	= "null"

    # Build the JsonQuery string
	$JsonQuery = @{}
	$JsonQuery.Script 	= $SQLQuery
	$JsonQuery.Args 	= $Arguments

    # make the call, using whatever SQL statement was provided
    $RedRockResponse = Invoke-PASAPI -APICall RedRock/query -Body ($JsonQuery | ConvertTo-Json)
    
    # return the rows that were queried
    return $RedRockResponse.Results.Row
}# function global:Query-RedRock
#endregion
###########