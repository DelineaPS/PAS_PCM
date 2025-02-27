
# class to hold Sets
[NoRunspaceAffinity()]
class PASSet
{
    [System.String]$SetType
    [System.String]$ObjectType
    [System.String]$Name
    [System.String]$ID
    [System.String]$Description
    [System.DateTime]$whenCreated
    [System.String]$ParentPath
	[System.String]$PotentialOwner                   # a guess as to who possibly owns this set
    [PSCustomObject[]]$PermissionRowAces             # permissions of the Set object itself
    [PSCustomObject[]]$MemberPermissionRowAces       # permissions of the members for this Set object
    [System.Collections.ArrayList]$MembersUuid = @{} # the Uuids of the members
    [System.Collections.ArrayList]$SetMembers  = @{} # the members of this set
	[System.Collections.ArrayList]$SetActivity = @{}
	hidden [System.String]$PASPCMObjectType

	# empty constructor
    PASSet() {}

	# method for reserialization
	resetObject ($pasobject)
	{
		# for each property passed in
		foreach ($property in $pasobject.PSObject.Properties) 
        {
			# loop into each property and readd it
            $this.("{0}" -f $property.Name) = $property.Value
        }
	}# resetObject ($pasobject)

	# primary constructor
    PASSet($set)
    {
		$this.PASPCMObjectType = "PASSet"
        $this.SetType = $set.CollectionType
        $this.ObjectType = $set.ObjectType
        $this.Name = $set.Name
        $this.ID = $set.ID
        $this.Description = $set.Description
        $this.ParentPath = $set.ParentPath

        if ($set.whenCreated -ne $null)
        {
            $this.whenCreated = $set.whenCreated
        }

        # getting the RowAces for this Set
        $this.PermissionRowAces = Get-PASRowAce -Type $this.SetType -Uuid $this.ID

        # if this isn't a Dynamic Set
        if ($this.SetType -ne "SqlDynamic")
        {
            # getting the RowAces for the member permissions
        $this.MemberPermissionRowAces = Get-PASCollectionRowAce -Type $this.ObjectType -Uuid $this.ID
        }
    }# PASSet($set)

    getMembers()
    {
        # nulling out both member fields
        $this.MembersUuid.Clear()
        $this.SetMembers.Clear()

        # getting members
        [PSObject]$m = $null

        # a little tinkering because Secret Folders ('Phantom') need a different endpoint to get members
        Switch ($this.SetType)
        {
            "Phantom" # if this SetType is a Secret Folder
            { 
                # get the members and reformat the data a bit so it matches Collection/GetMembers
                $m = Invoke-PASAPI -APICall ServerManage/GetSecretsAndFolders -Body (@{Parent=$this.ID} | ConvertTo-Json)
                $m = $m.Results.Entities
                $m | Add-Member -Type NoteProperty -Name Table -Value $m.Type
                break
            }# "Phantom" # if this SetType is a Secret Folder
            "ManualBucket" # if this SetType is a Manual Set
            {
                $m = Invoke-PASAPI -APICall Collection/GetMembers -Body (@{ID = $this.ID} | ConvertTo-Json)
            }
            default        { break }
        }# Switch ($this.SetType)

        # getting the set members
        if ($m -ne $null)
        {
            # for each item in the query
            foreach ($i in $m)
            {
                $obj = $null
                
                # getting the object based on the Uuid
                Switch ($i.Table)
                {
                    "DataVault"       {$obj = Query-RedRock -SQLQuery ("SELECT ID AS Uuid,SecretName AS Name FROM DataVault WHERE ID = '{0}'" -f $i.Key); break }
                    "DataVaultFolder" {$obj = Query-RedRock -SQLQuery ("SELECT ID AS Uuid,Name FROM Sets WHERE = ID = '{0}'" -f $i.Key); break }
                    "VaultAccount"    {$obj = Query-RedRock -SQLQuery ("SELECT ID AS Uuid,(Name || '\' || User) AS Name FROM VaultAccount WHERE ID = '{0}'" -f $i.Key); break }
                    "Server"          {$obj = Query-RedRock -SQLQuery ("SELECT ID AS Uuid,Name FROM Server WHERE ID = '{0}'" -f $i.Key); break }
                }

                # new SetMember
                $tmp = New-Object SetMember -ArgumentList ($obj.Name,$obj.Uuid)

                # adding the Uuids to the Members property
                $this.MembersUuid.Add(($i.Key)) | Out-Null

                # adding the SetMembers to the SetMembers property
                $this.SetMembers.Add(($tmp))    | Out-Null
            }# foreach ($i in $m)
        }# if ($m.Count -gt 0)
    }# getMembers()

    # helps determine who might own this set
    [PSObject] determineOwner()
    {
        # get all RowAces where the PrincipalType is User and has all permissions on this Set object
        $owner = $this.PermissionRowAces | Where-Object {$_.PrincipalType -eq "User" -and ($_.PASPermission.GrantInt -eq 253 -or $_.PASPermission.GrantInt -eq 65789)}

		$response = $null

        Switch ($owner.Count)
        {
            1       { $response = $owner.PrincipalName ; break }
            0       { $response = "No owners found"    ; break }
            default { $response = "Multiple potential owners found" ; break }
        }# Switch ($owner.Count)

		$this.PotentialOwner = $response
		
		return $response
    }# determineOwner()

    [PSCustomObject]getPASObjects()
    {
        $PASObjects = New-Object System.Collections.ArrayList

        [System.String]$command = $null

        Switch ($this.ObjectType)
        {
            "DataVault"    { $command = 'Get-PASSecret'; break }
            "Server"       { $command = 'Get-PASSystem'; break }
            "VaultAccount" { $command = 'Get-PASAccount'; break }
            default        { Write-Host "This set type not supported yet."; return $false ; break }
        }# Switch ($this.ObjectType)

		
		if ($this.ObjectType -eq "VaultAccount")
		{
			Invoke-Expression -Command ('[void]$PASObjects.AddRange(@(Get-PASAccount -Uuid {0}))' -f (($this.MembersUuid -replace '^(.*)$',"'`$1'") -join ","))
		}
		else
		{
			foreach ($id in $this.MembersUuid)
			{
			    Invoke-Expression -Command ('[void]$PASObjects.Add(({0} -Uuid {1}))' -f $command, $id)
			}
		}

        return $PASObjects
    }# [PSCustomObject]getPASObjects()

	getSetActivity()
	{
		$this.SetActivity.Clear()

		$activities = Query-RedRock -SQLQuery ("@/lib/server/get_activity_for_collection.js(id:'{0}')" -f $this.ID)
		
		if (($activities | Measure-Object | Select-Object -ExpandProperty Count) -gt 0)
		{
			$this.SetActivity.AddRange(@($activities)) | Out-Null
		}
	}# getSetActivity()

	[System.Collections.ArrayList] reviewPermissions()
	{
		$ReviewedPermissions = New-Object System.Collections.ArrayList

		# going through Set permissions first
		foreach ($rowace in $this.PermissionRowAces)
		{
			$ssperms = ConvertTo-SecretServerPermission -Type Set -Name $this.Name -RowAce $rowace

			$obj = New-Object PSCustomObject

			$obj | Add-Member -MemberType NoteProperty -Name OnObject -Value "Set"
			$obj | Add-Member -MemberType NoteProperty -Name ObjectType -Value $this.ObjectType
			$obj | Add-Member -MemberType NoteProperty -Name ObjectName -Value $this.Name
			$obj | Add-Member -MemberType NoteProperty -Name PrincipalType -Value $rowace.PrincipalType
			$obj | Add-Member -MemberType NoteProperty -Name PrincipalName -Value $rowace.PrincipalName
			$obj | Add-Member -MemberType NoteProperty -Name isInherited -Value $rowace.isInherited
			$obj | Add-Member -MemberType NoteProperty -Name InheritedFrom -Value $rowace.InheritedFrom
			$obj | Add-Member -MemberType NoteProperty -Name PASPermissions -Value $rowace.PASPermission.GrantString
			$obj | Add-Member -MemberType NoteProperty -Name SSPermissions -Value $ssperms.Permissions
			$obj | Add-Member -MemberType NoteProperty -Name SetID -Value $this.ID

			$ReviewedPermissions.Add($obj) | Out-Null
		}# foreach ($rowace in $this.PermissionRowAces)

		# then go through Member permissions next
		foreach ($memberrowace in $this.MemberPermissionRowAces)
		{
			$ssperms = ConvertTo-SecretServerPermission -Type SetMember -Name $this.Name -RowAce $memberrowace

			$obj = New-Object PSCustomObject

			$obj | Add-Member -MemberType NoteProperty -Name OnObject -Value "Member"
			$obj | Add-Member -MemberType NoteProperty -Name ObjectType -Value $this.ObjectType
			$obj | Add-Member -MemberType NoteProperty -Name ObjectName -Value $this.Name
			$obj | Add-Member -MemberType NoteProperty -Name PrincipalType -Value $memberrowace.PrincipalType
			$obj | Add-Member -MemberType NoteProperty -Name PrincipalName -Value $memberrowace.PrincipalName
			$obj | Add-Member -MemberType NoteProperty -Name isInherited -Value $memberrowace.isInherited
			$obj | Add-Member -MemberType NoteProperty -Name InheritedFrom -Value $memberrowace.InheritedFrom
			$obj | Add-Member -MemberType NoteProperty -Name PASPermissions -Value $memberrowace.PASPermission.GrantString
			$obj | Add-Member -MemberType NoteProperty -Name SSPermissions -Value $ssperms.Permissions
			$obj | Add-Member -MemberType NoteProperty -Name SetID -Value $this.ID

			$ReviewedPermissions.Add($obj) | Out-Null
		}# foreach ($memberrowace in $this.MemberPermissionRowAces)
		return $ReviewedPermissions
	}# [System.Collections.ArrayList] reviewPermissions()
}# class PASSet