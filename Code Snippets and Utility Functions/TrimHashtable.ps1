function TrimHashTable{
    <#
    .SYNOPSIS
        Removes empty string or null value keys from a hashtable
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [object]$Hashtable
    )

    $CleanHashtable = @{}
    $Keys = $Hashtable.Keys
    foreach ($Key in $Keys){
        if(($Hashtable.$Key -ne "") -and ($null -ne $Hashtable.$Key)){
            $CleanHashtable.Add($Key,$Hashtable.$Key)
        }
    }
    return $CleanHashtable
}