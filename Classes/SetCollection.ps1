# class to hold SetCollections
class SetCollection
{
	[System.String]$Name
	[System.String]$ID
	[System.String]$ObjectType
	[System.Collections.ArrayList]$MemberUuids = @{}

    SetCollection([System.String]$n, [System.String]$i, [System.String]$o)
    {
		$this.Name = $n
		$this.ID = $i
        $this.ObjectType = $o
    }

	addMembers([PSCustomObject[]]$s)
	{
		$this.MemberUuids.AddRange(@($s)) | Out-Null
	}

	removeMembers([PSCustomObject[]]$s)
	{
		$this.MemberUuids.RemoveRange(@($s)) | Out-Null
	}
}# class SetCollection