###########
#region ### global:Get-PASObjectUuid # CMDLETDESCRIPTION : Gets the PAS Uuid for the specified object :
###########
function global:Get-PASObjectUuid
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The type of object to search.")]
		[ValidateSet("Secret","Set","User")]
        [System.String]$Type,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the object to search.")]
        [System.String]$Name
    )

    # variables for the table, id, and name attributes
    [System.String]$tablename  = ""
    [System.String]$idname     = ""
    [System.String]$columnname = ""

    # switch to change the sqlquery based on the type of object
    switch ($Type)
    {
        "Secret" { $tablename = "DataVault"; $idname = "ID";           $columnname = "SecretName"; break }
        "Set"    { $tablename = "Sets"     ; $idname = "ID";           $columnname = "Name"      ; break }
		"User"   { $tablename = "DSUsers"  ; $idname = "InternalName"; $columnname = "SystemName"; break }
    }

    # setting the SQL query string
    $sqlquery = ("SELECT {0}.{1} AS ID FROM {0} WHERE {0}.{2} = '{3}'" -f $tablename, $idname, $columnname, $Name)

    Write-Verbose ("SQLQuery: [{0}] " -f $sqlquery)

    # making the query
    $Uuid = Query-RedRock -SqlQuery $sqlquery | Select-Object -ExpandProperty ID

    # warning if multiple Uuids are returned
    if ($uuid.Count -gt 1)
    {
        Write-Warning ("Multiple Uuids returned!")
    }

    # return $false if no Uuids were found
    if ($uuid.Count -eq 0)
    {
        Write-Warning ("No Uuids found!")
        return $false
    }

    # returning just the Uuid
    return $Uuid
}# global:Get-PASObjectUuid
#endregion
###########