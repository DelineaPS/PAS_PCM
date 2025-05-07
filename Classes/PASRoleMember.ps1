# class to hold PAS Role Members
[NoRunspaceAffinity()]
class PASRoleMember
{
    [System.String]$Name
    [System.String]$Guid
    [System.String]$Type
    [System.String]$DirectoryService

    # empty constructor
    PASRoleMember () {}

	# primary constructor
    PASRoleMember([System.String]$n, [System.String]$g, [System.String]$t)
    {
        $this.Name                 = $n
        $this.Guid                 = $g
        $this.Type                 = $t

        $this.getDirectoryService()
    }

    # getting what directory this member is associated with
    getDirectoryService()
    {
        $directory = "unknown"

        Switch ($this.Type)
        {
            "User"
            {
                $directory = Query-RedRock -SQLQuery ("SELECT SourceDsLocalized AS DirectoryService From User WHERE ID = '{0}'" -f $this.Guid) | Select-Object -ExpandProperty DirectoryService
            }
            "Group"
            {
                $directory = Query-RedRock -SQLQuery ("SELECT ServiceInstanceLocalized AS DirectoryService From DSGroups WHERE InternalName = '{0}'" -f $this.Guid) | Select-Object -ExpandProperty DirectoryService
            }
            "Role"
            {
                $directory = "Centrify Directory"
            }   

            default {}
        }# Switch ($this.Type)
        
        $this.DirectoryService = $directory
    }
}# class PASRoleMember