# class to hold SetMembers
class SetMember
{
    [System.String]$Name
    [System.String]$Uuid
    [System.Collections.ArrayList]$Members = @{}

    SetMember([System.String]$n, [System.String]$u)
    {
        $this.Name = $n
        $this.Uuid = $u
    }

    addMembers([PSCustomObject[]]$m)
    {
        $this.Members.AddRange(@($m)) | Out-Null
    }

    removeMembers([PSCustomObject[]]$m)
    {
        $this.Members.RemoveRange(@($m)) | Out-Null
    }
}# class SetMember