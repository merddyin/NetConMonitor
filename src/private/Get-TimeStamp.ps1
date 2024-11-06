function Get-TimeStamp {
    [CmdletBinding()]
    [OutputType([System.DateTime])]
    param (
    )

    return "[{0:MM/dd/yyyy} {0:HH:mm:ss}]" -f (Get-Date)
}