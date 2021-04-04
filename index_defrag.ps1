﻿<#
.Synopsis
  Short description
.DESCRIPTION
  Long description
.EXAMPLE
  Example of how to use this workflow
.EXAMPLE
  Another example of how to use this workflow
.INPUTS
  Inputs to this workflow (if any)
.OUTPUTS
  Output from this workflow (if any)
.NOTES
  General notes
.FUNCTIONALITY
  The functionality that best describes this workflow
#>

[bool]$user_interactive = [Environment]::UserInteractive;
[int]$MaxThreads = 4;
[string]$Server = $env:COMPUTERNAME ;


#region <databases>
$Database = 'master';
$CommandText = 'SELECT name FROM sys.databases WHERE database_id > 4 AND name IN (''DBA'') ORDER BY name;';
$ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True; Application Name=index_defrag;";
[System.Data.DataSet]$ds_Databases = New-Object System.Data.DataSet;

# Get the list of databases.
try{
       $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
       $SqlCommand = $sqlConnection.CreateCommand();      
       $SqlConnection.Open();
       $SqlCommand.CommandText = $CommandText;      
       
       $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter;
       $SqlAdapter.SelectCommand = $SqlCommand;    
       $SqlAdapter.Fill($ds_Databases);              
   }
   catch {throw $_ };
#endregion



# Loop over the databases
foreach($Row in $ds_Databases.Tables[0].Rows)
{
    $Database = $Row.name;    

    #region <indexes_defrag_queue>
    # Populate the index_defrag_queue table with rows to be processed and return the count of rows.
    try{
       $ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True;Application Name=index_defrag;";
       $CommandText = 'EXEC dbo.sp_get_indexes_to_defrag @min_index_size_mb = 100;';  

       $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
       $SqlCommand = $sqlConnection.CreateCommand();
       $SqlConnection.Open();
       $SqlCommand.CommandText = $CommandText;
       # Get the number of rows to be used as the upper bound of the loop.
       $NumRows = $SqlCommand.ExecuteScalar();      
    }
    catch {throw $_ };
    #endregion
   


    [string]$CommandText = "SET NOCOUNT ON; EXEC sp_index_defrag @reorg_threshold = 20, @rebuild_threshold = 60, @online = 1, @maxdop = 16, @sort_in_tempdb = 0, @single_index = 1, @debug = 0";

    $ScriptBlock =
    {
        param(
           $CommandText = $CommandText,
           $ConnectionString  = $ConnectionString
       )
      $ConnectionString = $ConnectionString;
     
       # Process the index
       try{
           $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
           $SqlCommand = $sqlConnection.CreateCommand();
           $SqlCommand.CommandTimeout = 0;
           $SqlConnection.Open();
           $SqlCommand.CommandText = $CommandText;      
           $SqlCommand.ExecuteNonQuery();      
       }
       catch {throw $_ };
    }

    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads);
    $RunspacePool.Open();
    $Jobs = @();

    1..$NumRows | Foreach-Object {
       $PowerShell = [powershell]::Create();
       $PowerShell.RunspacePool = $RunspacePool;
       $PowerShell.AddScript($ScriptBlock).AddParameter("CommandText",$CommandText).AddParameter("ConnectionString",$ConnectionString)       

       $Jobs += $PowerShell.BeginInvoke();       
    }    
    while ($Jobs.IsCompleted -contains $false)
    {        
       Start-Sleep -Milliseconds 10;       
    };
    $RunspacePool.Close();
    $RunspacePool.Dispose();
}

