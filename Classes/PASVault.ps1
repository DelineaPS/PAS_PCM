# class for configured Vaults
[NoRunspaceAffinity()]
class PASVault
{
    [System.String]$VaultType
    [System.String]$VaultName
    [System.String]$ID
    [System.String]$Url
    [System.String]$Username
    [System.Int32]$SyncInterval
    [System.DateTime]$LastSync

    PASVault () {}

    PASVault($vault)
    {
        $this.VaultType = $vault.VaultType
        $this.VaultName = $vault.VaultName
        $this.ID = $vault.ID

        if ($vault.LastSync -ne $null)
        {
            $this.LastSync = $vault.LastSync
        }

        $this.SyncInterval = $vault.SyncInterval
        $this.Username = $vault.Username
        $this.Url = $vault.Url
    }# PASVault($vault)
}# class PASVault
