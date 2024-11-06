function Install-MDNetConDatabase {
<#
.SYNOPSIS
    Deploys or configures a SQL Server instance and associated database to be used for MDNetCon data collection and analysis.

.DESCRIPTION
    This function can be used to perform the following activities:

        * Download the offline installer for SQL Server Advanced (requires internet access from server)
        * Perform silent installation of a SQL Express Advanced instance using an offline installer (either downloaded directly, or using an already available file)
        * Configure and prepare a SQL Server instance for use with MDNetCon, which includes:
            - Creating the MDNetCon database
            - Creating NetConData table
            - Configuring record submission access controls (either for a specifically created SQL service account, or by granting machine accounts direct access)
            - Configuring the SQL Server instance to allow for remote connections over TCP/IP
            - Configuring the SQL Server for administrative control

    In the event that an existing SQL Server instance is already installed on the target machine when using either the Download or LocalFile options, a new 'MDNetCon' instance will be deployed.

    Note: Additional configuration may be required to support specific encryption requirements, if any, however the data collected by MDNetCon is specifically intended to be non-sensitive and non-PII.

.PARAMETER InstallType
    Use this parameter to determine how the SQL Server components will be deployed. The following options are available:

        * Download (Default): This option will download the SQL Server Express Advanced installer directly from the Microsoft website. This option requires internet access from the server.
        * LocalFile: This option will use a locally available installer file to perform the installation, which also requires specifying a value for the InstallerPath parameter.
        * UseExisting: This option will use an existing SQL Server instance that is already installed on the target machine. The TargetServer parameter can be used to specify a remote server.

.PARAMETER TargetServer
    If the UseExisting option is selected for InstallType, use this parameter to specify the name of the server where the existing SQL Server instance is installed. The user running the command must have
    sufficient permissions to connect to the specified server and perform the necessary configuration tasks.

.PARAMETER InstallerPath
    If internet access is not available from the server, or if you wish to use a specific set of installation media, use this parameter to specify the full path to the installer. This parameter is only
    required when using the LocalFile option for InstallType.

.PARAMETER LisenceKey
    Use this parameter to specify a value for license key if you will be using a locally provided installer that requires one.

    Note: The Download option leverages the SQL Server Express Advanced Edition installer downloaded directly from the Microsoft website, which does not require a license key.

.PARAMETER DataFilesPath
    Use this parameter to specify the full local folder path to be used as custom default location for the storage of all SQL data files.

    If a value is not provided then, by default, this function will attempt to create a directory named 'SQL Server' on a secondary drive, if one is available. In most environments, this will result in a new
    directory of 'D:\SQL Server\Data'. If no secondary data drive is present, the default installation folder location will be used instead.

.PARAMETER LogFilesPath
    Use this parameter to specify the full local folder path to be used as custom default location for the storage of all SQL log files.

    If a value is not provided then, by default, this function will attempt to create a directory named 'SQL Server' on a secondary drive, if one is available. In most environments, this will result in a new
    directory of 'D:\SQL Server\Logs'. If no secondary data drive is present, the default installation folder location will be used instead.

.PARAMETER ClientAccount
    Use this parameter to provide a credential object containing the desired username and password to be used by client systems for submitting data to the MDNetCon database. These values will need to be
    retained and supplied to the Deploy-MDNetConMonitor function when configuring client systems for data submission, which will result in the values being encoded into a script block used to submit data
    entries to the database. Because these values will need to be distributed to client systems, the supplied account details will be used to generate a local SQL Server login with only the minimum required
    permissions to insert data into the database.

    Note: This option should only be used for client systems that are not capable of using their own machine account contexts to submit data to the database. Target client systems that reside in the same
    domain as the SQL Server instance, or within any other trusted domain, should leverage the ADClientGroup parameter instead.

.PARAMETER ADClientGroup
    By default, unless a value has been supplied for the ClientAccount parameter, the built-in 'Domain Computers' group for the domain the SQL Server is a member of will be automatically added with the
    required permissions to insert data into the MDNetCon database. Alternatively, you may use this parameter to override the default behavior by supplying one, or more, Active Directory groups to be used
    instead.

.PARAMETER ADAdminGroup
    Use this parameter to specify the name of an Active Directory group that will be granted administrative access to the MDNetCon database. This group will be granted the necessary permissions to
    perform administrative tasks on the database engine instance. If no value is provided, the built-in 'Domain Admins' group for the domain the SQL Server is a member of will be automatically added, along
    with the user account that is running the function.

.NOTES
    Cmdlet Version: <1.0>
    Created by: <Author>

    Revision History:
        <Date>, <Author>, <Description>
        <Date>, <Author>, <Description>

.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.

.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines

#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Download', 'LocalFile', 'UseExisting')]
        [string]$InstallType = 'Download',

        [Parameter(ParameterSetName = 'ClientAccount')]
        [Management.Automation.PSCredential]$ClientAccount,

        [Parameter(ParameterSetName = 'ClientGroup')]
        [string[]]$ADClientGroup,

        [Parameter()]
        [string]$ADAdminGroup

    )

    DynamicParam {
        if($InstallType -eq 'UseExisting') {
            $DynamicParameters = @(
                [PSCustomObject]@{
                    Name = 'TargetServer'
                    ParameterType = [string]
                    Mandatory = $true
                    Position = 0
                }
            )
        }
        else {
            $DynamicParameters = @(
                [PSCustomObject]@{
                    Name = 'LicenseKey'
                    ParameterType = [string]
                    Mandatory = $false
                },
                [PSCustomObject]@{
                    Name = 'DataFilesPath'
                    ParameterType = [string]
                    Mandatory = $false
                },
                [PSCustomObject]@{
                    Name = 'LogFilesPath'
                    ParameterType = [string]
                    Mandatory = $false
                }
            )

            if($InstallType -eq 'LocalFile') {
                $DynamicParameters += @(
                    [PSCustomObject]@{
                        Name = 'InstallerPath'
                        ParameterType = [string]
                        Mandatory = $true
                        ValidateScript = {Test-Path $_}
                    }
                )
            }
        }

        $DynamicParameters | New-DynamicParameter
    }

    begin {
        #TODO: Write the function to align with the capabilities outlined in the comment-based help
    }

    process {

    }

    end {

    }
}