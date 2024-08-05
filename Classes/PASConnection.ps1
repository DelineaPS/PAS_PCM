# class to hold PASConnections
[NoRunspaceAffinity()]
class PASConnection
{
    [System.String]$PodFqdn
    [PSCustomObject]$PASConnection
    [System.Collections.Hashtable]$PASSessionInformation

    PASConnection($po,$pc,$s)
    {
        $this.PodFqdn               = $po
        $this.PASConnection         = $pc
        $this.PASSessionInformation = $s
    }
}# class PASConnection