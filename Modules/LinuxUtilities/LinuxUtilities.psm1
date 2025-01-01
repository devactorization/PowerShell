#Requires -Version 7.0
#Requires -PSEdition Core

Function Get-Service {
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [String]$Name,
        [Parameter(Position = 1, ValueFromPipeline = $false)]
        [switch]$System
    )
    # Stop Function if Not Linux
    If (-Not $IsLinux) {
      Write-Error "This function should only be run on Linux systems"
      Break
    }

    try{
        if($System){
            $services = & systemctl list-units --type=service --no-legend --all --no-pager
        }
        else{
            $services = & systemctl --user list-units --type=service --no-legend --all --no-pager
        }
    }
    catch{
        Write-Error "Failed to list service"
    }

    $services = $services | ForEach-Object {
        $service = $_ -Split '\s+'

        [PSCustomObject]@{
        "Name"        = ($service[1] -Split "\.service")[0]
        "Unit"        = $service[1]
        "State"       = $service[2]
        "Active"      = (($service[3] -EQ 'active') ? $true : $false)
        "Status"      = $service[4]
        }
    }
    if($Name){
        $service = $services | Where-Object{$_.Name -eq $Name}
        Write-Output $service
    }
    else{
        Write-Output $services
    }
    
}
  

function Restart-Service {
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [String]$Name,
        [Parameter(Position = 1, ValueFromPipeline = $false)]
        [switch]$System
    )

    if($System){
        Foreach($Service in $Name){
            try{
                & systemctl restart $Service
            }
            catch{
                Write-Error "Failed to restart $Service"
            }
        }
    }
    else{
        Foreach($Service in $Name){
            try{
                & systemctl --user restart $Service
            }
            catch{
                Write-Error "Failed to restart $Service"
            }
        }
    }
}

function Start-Service {
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [String]$Name,
        [Parameter(Position = 1, ValueFromPipeline = $false)]
        [switch]$System
    )

    if($System){
        Foreach($Service in $Name){
            try{
                & systemctl start $Service
            }
            catch{
                Write-Error "Failed to start $Service"
            }
        }
    }
    else{
        Foreach($Service in $Name){
            try{
                & systemctl --user start $Service
            }
            catch{
                Write-Error "Failed to start $Service"
            }
        }
    }
}

function Stop-Service {
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [String]$Name,
        [Parameter(Position = 1, ValueFromPipeline = $false)]
        [switch]$System
    )

    if($System){
        Foreach($Service in $Name){
            try{
                & systemctl stop $Service
            }
            catch{
                Write-Error "Failed to stop $Service"
            }
        }
    }
    else{
        Foreach($Service in $Name){
            try{
                & systemctl --user stop $Service
            }
            catch{
                Write-Error "Failed to stop $Service"
            }
        }
    }

}

Function Get-QuadletUnit {
    param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [String]$Name
    )
  
    if($Name){
        $UnitFiles = Get-ChildItem -Path "$Home/.config/containers/systemd/$Name.container"
    }
    else{
        $UnitFiles = Get-ChildItem -Path "$Home/.config/containers/systemd/"
    }
  
    foreach ($File in $UnitFiles){
        $Text = Get-Content $File.FullName
  
        $Hashtable = @{}
        $Text | ForEach-Object{
            if($_ -like '*=*'){
            $Key = ($_ -split '=')[0]
            $Count = ($_ -split '=').count -1
            $Value = ($_ -split '=')[1..$Count] -join '='
    
            $Hashtable.Add($Key,$Value)
            }
        }
    
        [hashtable[]]$Units += @{
            "UnitFile" = $File.Name
            "UnitFilePath" = $File.FullName
            "ContainerName" = $Hashtable.ContainerName
            "Image" = $Hashtable.Image
            "PublishPort" = $Hashtable.PublishPort
        }
    }
  
    Write-Output $Units[0..-1]
}
  
  #Gets running containers
Function Get-PodmanContainer {
    param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [String]$Name,
        [Parameter(Position = 1, ValueFromPipeline = $True)]
        [string]$Id
    )

    $Containers = & podman ps --noheading

    Foreach ($Container in $Containers){
        $Split = $Container -split '\s{2,}'
        $Hashtable = @{
            "Id" = $Split[0]
            "Image" = $Split[1]
            "Created" = $Split[2]
            "Status" = $Split[3]
            "Ports" = $Split[4]
            "Names" = $Split[5]
        }

        [hashtable[]]$Array += $Hashtable
    }

    if($Name){
        $Match = $Array | Where-Object{$_.Name -eq $Name}
        if($Match){Write-Output $Match}
        else{Write-Host "No container found with name $Name"}
    }
    if($Id){
        $Match = $Array | Where-Object{$_.Id -eq $Id}
        if($Match){Write-Output $Match}
        else{Write-Host "No container found with Id $Id"}
    }
    else{
        Write-Output $Array
    }
}