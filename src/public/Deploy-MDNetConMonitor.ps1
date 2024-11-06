function Deploy-MDNetConMonitor {
    <#
        .SYNOPSIS
            This cmdlet will deploy a new network connection monitor to one or more computers.

        .DESCRIPTION
            This cmdlet configures either an ephemeral or persistent network connection monitor on one or more computers. The monitor will watch for the creation of new remote network connections and collect related process information.
            The process details will then be filtered to exclude processes based on a supplied list of process names. By default, the monitor excludes core system processes and common applications.

        #TODO: Update help content

        .LINK
            https://github.com/merddyin/NetConMonitor

        .EXAMPLE
            TBD

        .NOTES
            Author: Topher Whitfield
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByComputer')]
    param(
        # By individual computer objects
        [Parameter(ParameterSetName = 'ByComputer', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName,

        [Parameter(ParameterSetName = 'ByComputer')]
        [Management.Automation.PSCredential]$Credential,

        #TODO: Add support options to create subscriptions without a WinRM or remote session capability
        #TODO: Add error handling to test for network accessibility of target, both general ping and WinRM, with fallback to no-session option when WinRM is not available
        #TODO: Add try/catch blocks for session creation and script block deployment

        [Parameter(ParameterSetName = 'BySession', ValueFromPipeline)]
        [Management.Infrastructure.PSSession[]]$Session,

        [Parameter()]
        [ValidateSet('EventLog', 'File', "SQLDB")]
        [string]$OutputType = 'EventLog',

        [Parameter()]
        [ValidateSet('Default', 'CommonProtocol', 'Custom')]
        [string]$CollectionType = 'Default',

        [Parameter()]
        [string[]]$ExcludeProcNames,

        [Parameter()]
        [string[]]$ExcludeProcPaths
    )
    DynamicParam {
        # Additional parameters for Output Type
        switch ($OutputType) {
            # Database output additional parameters
            'SQLDB' {
                $OutDP = @(
                    [PSCustomObject]@{
                        Name = 'DBServer'
                        Type = [String]
                        Mandatory = $true
                        HelpMessage = 'The server and instance hosting the database.'
                    },
                    [PSCustomObject]@{
                        Name = 'DBPort'
                        Type = [Int32]
                        Mandatory = $false
                        HelpMessage = 'The port to use when connecting to the database - defaults to 1433.'
                    },
                    [PSCustomObject]@{
                        Name = 'InstanceName'
                        Type = [String]
                        Mandatory = $false
                        HelpMessage = 'The name of the database instance to use if not the default.'
                    }
                    [PSCustomObject]@{
                        Name = 'DBCredential'
                        Type = [Management.Automation.PSCredential]
                        Mandatory = $false
                        HelpMessage = 'The credentials client systems will use to submit new entries if the default machine context cannot be leveraged.'
                    }
                )
            }

            # File output additional parameters
            'File' {
                $OutDP = @(
                    [PSCustomObject]@{
                        Name = 'LogPath'
                        Type = [String]
                        Mandatory = $true
                        ValidateScript = { Test-Path -Path $_ -PathType Container }
                        HelpMessage = 'The full path to the location the log file should be created - no filename.'
                    },
                    [PSCustomObject]@{
                        Name = 'LogSize'
                        Type = [Int32]
                        HelpMessage = 'The maximum size of the log file in MB - defaults to 100.'
                    },
                    [PSCustomObject]@{
                        Name = 'LogCount'
                        Type = [Int32]
                        HelpMessage = 'The number of days to retain log files - defaults to 10 (total size 1GB if available).'
                    }
                )
            }

            # Event log output additional parameters - Default output type
            'EventLog' {
                $OutDP = @(
                    [PSCustomObject]@{
                        Name = 'SourceName'
                        Type = [String]
                        Mandatory = $false
                        HelpMessage = 'The name of the custom event entry source - defaults to "NetConMonitor".'
                    }
                )
            }
        }

        # Additional parameters for Collection Type
        switch ($CollectionType) {
            # Protocol collection additional parameters
            'CommonProtocol' {
                $ColDP = @(
                    [PSCustomObject]@{
                        Name = 'Protocol'
                        Type = [String]
                        Mandatory = $true
                        ValidateSet = @('FTP', 'SMB', 'RDP', 'WinRM', 'LDAP', 'HTTPS')
                        HelpMessage = 'The specific protocol to monitor for connections - Use Custom for multiple.'
                    }
                )
            }

            # Custom collection additional parameters
            'Custom' {
                $ColDP = @(
                    [PSCustomObject]@{
                        Name = 'RemotePort'
                        Type = [String[]]
                        Mandatory = $true
                        HelpMessage = 'One or more remote ports for which connections should be captured.'
                    },
                    [PSCustomObject]@{
                        Name = 'RemoteIP'
                        Type = [String[]]
                        Mandatory = $false
                        HelpMessage = 'One or more remote IP addresses for which connections should be captured.'
                    }
                )
            }
        }

        # Add the dynamic parameter sets together, then pass to the cmdlet
        $DynamicParameters = @($OutDP, $ColDP)
        $DynamicParameters | New-DynamicParameter
    }

    begin {
        if ($script:ThisModuleLoaded -eq $true) {
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }
        $FunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose "----------$($FunctionName)----------"
        Write-Verbose "$(Get-TimeStamp):`tBegin."

        #region Common Scriptblock Arguments
        $sbSplat = @{
            OutputType = $OutputType
            procNameFilter = "$(Join-String $ExcludeProcNames -Separator '|')"
            procPathFilter = @($prociPathFilter)
        }

        #region WQLFilter Construction
        ## Base string prefix
        $wqlFilter = 'SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA "MSFT_NetTCPConnction" AND TargetInstance.OwningProcessID != 0 AND TargetInstance.RemotePort != 0 AND TargetInstance.RemoteAddress IS NOT "127.0.0.1" AND TargetInstance.RemoteAddress IS NOT "::"'

        ## Augment based on CollectionType
        switch ($CollectionType) {
            'CommonProtocol' {
                # Add filter for specified common protocol value
                switch ($Protocol) {
                    'FTP' {
                        $wqlFilter += ' AND (TargetInstance.RemotePort = 21 OR TargetInstance.RemotePort = 22)'
                    }

                    'SMB' {
                        $wqlFilter += ' AND (TargetInstance.RemotePort = 445)'
                    }

                    'RDP' {
                        $wqlFilter += ' AND (TargetInstance.RemotePort = 3389)'
                    }

                    'WinRM' {
                        $wqlFilter += ' AND (TargetInstance.RemotePort = 5985 OR TargetInstance.RemotePort = 5986)'
                    }

                    'LDAP' {
                        $wqlFilter += ' AND (TargetInstance.RemotePort = 389 OR TargetInstance.RemotePort = 636 OR TargetInstance.RemotePort = 3268 OR TargetInstance.RemotePort = 3269)'
                    }

                    'HTTPS' {
                        $wqlFilter += ' AND (TargetInstance.RemotePort = 443)'
                    }
                }
            }

            'Custom' {
                # Add filter for specified custom remote port value(s)
                $wqlFilter += ' AND ('
                $RemotePort | ForEach-Object {
                    $wqlFilter += "TargetInstance.RemotePort = $_ OR "
                }

                # Add filter for specified custom remote IP address value(s), if present
                if($RemoteIP){
                    $wqlFilter += ') AND ('
                    $RemoteIP | ForEach-Object {
                        $wqlFilter += "TargetInstance.RemoteAddress = '$_' OR "
                    }
                }

                # Close out the filter designations
                $wqlFilter = $wqlFilter.Substring(0, $wqlFilter.Length - 4) + ')' # Remove the trailing OR
            }
        }

        ## Append WQL filter suffix and add to argument splat
        $wqlFilter += ' GROUP WITHIN 600 BY TargetInstance.OwningProcess'

        Write-Verbose "$(Get-TimeStamp):`t`tConstructed WQL Filter: [$wqlFilter]"

        $sbSplat.WQLQuery = $wqlFilter
        #endregion WQLFilter Construction

        #endregion Common Scriptblock Arguments

        #region Variable Scriptblock Arguments
        switch ($OutputType) {
            'SQLDB' {
                # Account for custom instance name
                if($InstanceName){
                    $DBServerString = "Server=$DBServer\$DBInstanceName"
                }else {
                    $DBServerString = "Server=$DBServer"
                }

                # Account for custom port
                if($DBPort){
                    $DBServerString += ",$DBPort"
                }

                if($DBCredential){
                    Write-Warning "NOTE: Use of DB credentials requires storage of the associated values in the resulting script block sent to target systems. While the block itself will be encoded, these values could still be subject to interception. Use with caution."
                    $dbConString = "$DBServerString;Trusted_Connection=False;Database=MDNetCon;User Id=`"$($DBCredential.UserName)`";Password=`"$($DBCredential.GetNetworkCredential().Password)`""
                } else {
                    $dbConString = "$DBServerString;Trusted_Connection=True;Database=MDNetCon"
                }

                $sbSplat.DBConString = $dbConString
            }

            'File' {
                if(-not $LogSize){
                    $LogSize = 100
                }

                if(-not $LogRetention){
                    $LogCount = 10
                }

                $sbSplat.LogPath = $LogPath
                $sbSplat.LogSize = $LogSize
                $sbSplat.LogCount = $LogCount
            }

            'EventLog' {
                if(-not $SourceName){
                    $SourceName = 'NetConMonitor'
                }

                $sbSplat.SourceName = $SourceName
            }
        }

        #endregion Variable Scriptblock Arguments

        # Construct the script block to be executed on the remote computer
        $scriptBlock = Format-ScriptBlock @sbSplat
    }

    process {
        Write-Verbose "$(Get-TimeStamp):`tProcessing."
        if($PSCmdlet.ParameterSetName -eq 'ByComputer'){
            foreach($computer in $ComputerName){
                Write-Verbose "$(Get-TimeStamp):`t`tCreating session for computer [$computer]"
                $SessParams = @{
                    ComputerName = $ComputerName
                }
                if($Credential){
                    $SessParams.Credential = $Credential
                }
                $Session = New-CimSession @SessParams
            }
        }

        foreach($Sess in $Session){
            Write-Verbose "$(Get-TimeStamp):`t`tDeploying NetConMonitor to session [$Sess]"

        }

    }

    end {
        Write-Verbose "$($FunctionName): End."
    }
}
