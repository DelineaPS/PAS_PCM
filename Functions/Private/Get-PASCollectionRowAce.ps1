###########
#region ### global:Get-PASCollectionRowAce # Gets RowAces for the specified platform Collection object
###########
function global:Get-PASCollectionRowAce
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The type of object to search.")]
        [System.String]$Type,

        [Parameter(Mandatory = $true, HelpMessage = "The name of the object to search.", ParameterSetName = "Name")]
        [System.String]$Name,

        [Parameter(Mandatory = $true, HelpMessage = "The Uuid of the object to search.",ParameterSetName = "Uuid")]
        [System.String]$Uuid
    )

    # if the Name parameter was used
    if ($PSBoundParameters.ContainsKey("Name"))
    {
        $collectiontype = ""
        Switch -Regex ($Type)
        {
            "Secret|DataVault" { $collectiontype = "Set"; break }
        }

        # getting the uuid of the object
        $uuid = Get-PASObjectUuid -Type $collectiontype -Name $Name
    }

    # setting the table variable
    [System.String]$table = ""

    Switch ($Type)
    {
        "Secret"    { $table = "DataVault"   ; break }
        "Set"       { $table = "Collections" ; break }
        default     { $table = $Type         ; break }
    }

    # preparing the JSONBody
    $JSONBody = @{ RowKey = $uuid ; Table = $table } | ConvertTo-Json

    # getting the RowAce information
    $CollectionAces = Invoke-PASAPI -APICall "Acl/GetCollectionAces" -Body $JSONBody

    # setting a new ArrayList for the return
    $CollectionAceObjects = New-Object System.Collections.ArrayList

    # for each rowace retrieved
    foreach ($collectionace in $CollectionAces)
    {
        # ignore any global root or tech support entries
        if ($collectionace.Type -eq "GlobalRoot" -or $rowace.PrincipalName -eq "Technical Support Access")
        {
            continue
        }

		# if the type is Super (from default global roles with read permissions)
        if ($collectionace.Type -eq "Super")
        {
            # set the Grant to 4 instead of "Read"
            [System.Int64]$collectionace.Grant = 4
        }

		# nulling out InheritedFrom
		[System.String]$InheritedFrom = $null

		# if this collectionace is inherited
		if ($collectionace.Inherited)
		{
			Switch ($collectionace.Type)
			{
				"GlobalTable" { $InheritedFrom = "Global Settings"; break }
				"Collection"  { $InheritedFrom = ("Set: {0}" -f $collectionace.CollectionName); break }
				"Super"       { $InheritedFrom = ("Admin Right: {0}" -f $collectionace.SuperName); break }
				default       { break }
			}
		}# if ($collectionace.Inherited)

        Try
        {
            # creating the PASpermission object
            $PASpermission = New-Object PASPermission -ArgumentList ($Type, $collectionace.Grant, $collectionace.GrantStr)

            # creating the PlatformRowAce object
            $obj = New-Object PermissionRowAce -ArgumentList ($collectionace.PrincipalType, $collectionace.Principal, `
				$collectionace.PrincipalName, $collectionace.Inherited, $InheritedFrom, $PASpermission)
        }# Try
        Catch
        {
            # setting our custom Exception object and stuff for further review
            $e = New-Object PASPCMException -ArgumentList ("A PASRowAce error has occurred. Check `$LastRowAceError for more information.")
			$e.AddExceptionData($_)
			$e.AddData("collectionace",$collectionace)
			$e.AddData("PASPermission",$PASpermission)
			$global:LastPASPCMError = $e
        }# Catch

        $CollectionAceObjects.Add($obj) | Out-Null
    }# foreach ($collectionace in $CollectionAces)

    # returning the RowAceObjects
    return $CollectionAceObjects
}# function global:Get-PASCollectionRowAce
#endregion
###########