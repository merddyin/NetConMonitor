function Format-ScriptBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('EventLog', 'File', 'SQLDB')]
        [string]$OutputType,

        [Parameter(Mandatory = $true)]
        [string]$wqlFilter,

        [Parameter()]
        [string]$procNameFilter,

        [Parameter()]
        [string()]$procPathFilter,

        [Parameter(ParameterSetName = 'DB')]
        [string]$dbConString,

        [Parameter(ParameterSetName = 'File')]
        [string]$LogPath,

        [Parameter(ParameterSetName = 'File')]
        [string]$LogSize,

        [Parameter(ParameterSetName = 'File')]
        [int]$LogCount,

        [Parameter(ParameterSetName = 'EventLog')]
        [string]$SourceName
    )

    <#
        Define the common elements of the script block that will be executed when an event is detected:

        - Initialize the $filters variable with the value of the $argFilters parameter
        - Retrieve the process information for the event
        - Initialize the $include variable to $true so that, unless filtered, the associated event and process details will be logged
        - Check the process name and path against the exclusion filters, and update the $include variable if a match is found
        - Provided the process is not excluded, create a custom object with the required properties and strong typing

        Note: The 'using' scope modifier is leveraged to access the values of variables defined outside of the script block at the time the script block is created
    #>
    $sbString = @'
    $custNameFilters = $using:procNameFilter
    $custPathFilters = $using:procPathFilter

    $NameFilters = "svchost|SearchHost|CcmExec|edpa|SystemSettings|OUTLOOK|OneDrive"

    if($custNameFilters){
        $NameFilters += "|$custNameFilters"
    }

    $PathFilters = @("C:\Windows\*", "*WindowsApps*")
    if($custPathFilters){
        $PathFilters += $custPathFilters
    }

    $Process = Get-Process -Id $Event.SourceEventArgs.NewEvent.TargetInstance.OwningProcess

    $include = $true

    if($Process.ProcessName -match $NameFilters){
        $include = $false
        break
    }

    foreach($filter in $PathFilters){
        if($Process.Path -like "$filter"){
            $include = $false
            break
        }
    }

    if($include){
        # Updating object properties also requires updating event template for event log
        $object = [PSCustomObject]@{
            ClientName = [string]$ENV:COMPUTERNAME
            ClientIP = [string]$Event.SourceEventArgs.NewEvent.TargetInstance.LocalAddress
            ProcessId = [int]$Process.Id
            ProcessName = [string]$Process.ProcessName
            ProcessPath = [string]$Process.Path
            ProcessProduct = [string]$Process.Product
            RemoteAddress = [string]$Event.SourceEventArgs.NewEvent.TargetInstance.RemoteAddress
            RemotePort = [int]$Event.SourceEventArgs.NewEvent.TargetInstance.RemotePort
        }

'@

    # Determine the remainder of the script block contents based on the selected output type

    switch ($OutputType) {
        'EventLog' {
            # Define a template to be used to format the event message in a consistent manner
            $eventTemplate = @"
    A new network connection was detected on the system with the following values:

        {0} :`t`t{1}
        {2} :`t`t{3}
        {4} :`t`t{5}
        {6} :`t`t{7}
        {8} :`t`t{9}
        {10} :`t`t{11}
        {12} :`t`t{13}
        {14} :`t`t{15}
"@
            <#
                Complete required setup and output elements:

                - Check if the event log source exists and create it if it does not
                - Format the event message using the template
                - Write the event log entry using the formatted message
            #>
            $sbString += @'
        $source = $using:SourceName
        $evtTemplate = $using:eventTemplate
        if(-not [System.Diagnostics.EventLog]::SourceExists('$source')){
            try{
                New-EventLog -LogName Application -Source $source
            }catch{
                Write-Error $_.Exception.Message -ErrorAction Stop
            }
        }

        $eventMessage = $evtTemplate -f $($object.psobject.Properties | ForEach-Object { $_.Name, $_.Value })
        Write-EventLog -LogName Application -Source MDNetConMonitor -EntryType Information -EventId 1000 -Message $eventMessage
'@
        }

        'File' {
            $sbString += @'
        $outfileName = "$($ENV:COMPUTERNAME)_MDNetConMonitor.csv"
        $outfilePath = $using:LogPath
        $outfileSize = $using:LogSize
        $outfileCount = $using:LogCount
        $outfileMaxSize = ($outFileSize * $outfileCount) * 2
        $outFullFilePath = Join-Path -Path $outfilePath -ChildPath $outfileName

        # Skip space check for network paths, otherwise verify space is at least twice the size of the estimated total
        if($outFullFilePath -notlike '\\*'){
            $fileRoot = Split-Path -Path $outfilePath -Qualifier
            $driveInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$fileRoot'"
            $freeSpace = $([Math]::Round($driveInfo.FreeSpace / 1MB, 0))

            if($freeSpace -le $outfileMaxSize){
                $message = "Insufficient drive space available for projected file size (must be 2x estimated). Free space: $freeSpace MB  -  Estimated space: $outfileMaxSize"
                $message | Out-File -FilePath $outFullFilePath -Force
                Write-Error -Message $message -ErrorAction Stop
            }
        }

        # Check for existing file and size and initiate rotation if required
        if(Test-Path $outFullFilePath){
            $outputFile = Get-ChildItem -Path $outFullFilePath
            $outputFileSize = $([Math]::Round(($outputFile).Length / 1MB, 0))
            $allOutputFiles = Get-ChildItem -Path $outfilePath | Where-Object { $_.Name -like "$($ENV:COMPUTERNAME)_MDNetConMonitor*.csv" } | Sort-Object -Property LastWriteTime -Descending
            if($outputFileSize -ge $outfileSize){
                switch($outfileCount){
                    {$outfileCount -eq 0} {
                        # Delete the current file if the count is 0
                        $outputFile.Delete()
                    }
                    {$outfileCount -gt 0} {
                        # If the count is greater than 0, check the current count
                        if($allOutputFiles.Count -ge $outfileCount){
                            # If current file count has reached the limit, delete the oldest file and roll the rest
                            $allOutputFiles[-1].Delete()
                            $lCount = $outfileCount - 1
                            for($l = $lCount; $l -gt 0; $l--){
                                $file = (Get-ChildItem -Path $filePath | Where-Object { $_.Name -like "$($ENV:COMPUTERNAME)_MDNetConMonitor*.csv" } | Sort-Object -Property LastWriteTime -Descending)[$l]
                                $newFile = "$filePath\$($ENV:COMPUTERNAME)_MDNetConMonitor_$l.csv"
                                $file.MoveTo($newFile)
                            }
                        }
                    }
                }
            }
        }

        $object | Export-Csv -Path $outFullFilePath -Append -NoTypeInformation
'@
        }

        'SQLDB' {
            $sbString += @'
        $sqlConnString = $using:dbConString
        $tableName = "NetConData"

        $sqlConn = New-Object -TypeName System.Data.SqlClient.SqlConnection
        $sqlConn.ConnectionString = $sqlConnString
        try{
            $sqlConn.Open()
        }catch{
            Write-Error $_.Exception.Message -ErrorAction Stop
        }

        $strColumns = New-Object -TypeName System.Text.StringBuilder
        $strValues = New-Object -TypeName System.Text.StringBuilder

        foreach($element in $object.psobject.Properties){
            $null = $strColumns.Append(", $element.Name")}

            if($null -eq $element.Value -or $element.Value -eq ""){
                $null = $strValues.Append(", NULL")
            }else{
                $null = $strValues.Append(", '$($element.Value)'")
            }
        }

        $insColumns = $strColumns.ToString().Remove(0, 2)
        $insValues = $strValues.ToString().Remove(0, 2)

        $query = "INSERT INTO dbo.$tableName ($insColumns) VALUES ($insValues)"
        $sqlCmd = $sqlConn.CreateCommand()
        $sqlCmd.CommandText = $query
        $sqlCmd.ExecuteNonQuery() | Out-Null
'@
        }
    }

    $sbString += '}'

    $sb = [scriptblock]::Create($sbString)

    return $sb
}