Import-Module (Join-Path $MyModulePath 'plugins\nlog\PSNLog\0.2.5\PSNLog.psd1') -Force -Scope:Global
$LogParams = @{
    Name = 'NetConMonitor'
    FileName = (Join-Path $ENV:TEMP 'NetConMonitor.log')
    ArchiveFileName = (Join-Path $ENV:TEMP 'NetConMonitor.{#}.log')
    ArchiveNumbering = 'DateAndSequence'
    ArchiveEvery = 'Day'
    MaxArchiveFiles = 7
}
New-NLogFileTarget @LogParams
Enable-NLogLogging -target 'NetConMonitor' -minLevel 'Info'
