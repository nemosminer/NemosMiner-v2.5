using module ..\Includes\Include.psm1

Try { 
    $Request = Get-Content ((Split-Path -Parent (Get-Item $script:MyInvocation.MyCommand.Path).Directory) + "\Brains\nlpool\nlpool.json") | ConvertFrom-Json
}
Catch { return }

If (-not $Request) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = "mine.nlpool.nl"
$PriceField = "Plus_Price"
# $PriceField = "actual_last24h"
# $PriceField = "estimate_current"
 
$PoolRegions = "US"

# Placed here for Perf (Disk reads)
$ConfName = If ($PoolsConfig.$Name) { $Name } Else { "default" }
$PoolConf = $PoolsConfig.$ConfName

$Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
    $PoolHost = $HostSuffix
    $PoolPort = $Request.$_.port
    $Algoritm_Norm = Get-Algorithm $Request.$_.name

    $Fee = [Decimal]($Request.$_.Fees / 100)
    $Divisor = 1000000 * [Double]$Request.$_.mbtc_mh_factor

    switch ($Algoritm_Norm) { 
        "equihash125" { $Divisor *= 2 } #temp fix
        "equihash144" { $Divisor *= 2 } #temp fix
        "equihash192" { $Divisor *= 2 } #temp fix
        "verushash" { $Divisor *= 4 } #temp fix
    }

    $Stat_Name = "$($Name)_$($Algorithm_Norm)_Profit"
    If ((Get-Stat -Name $Stat_Name) -eq $null) { $Stat = Set-Stat -Name $Stat_Name -Value ([Double]$Request.$_.$PriceField / $Divisor) }
    Else { $Stat = Set-Stat -Name $Stat_Name -Value ([Double]$Request.$_.$PriceField / $Divisor) }

    $PasswordCurrency = If ($PoolConf.PasswordCurrency) { $PoolConf.PasswordCurrency } Else { $PoolConf."Default".PasswordCurrency }
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") { $PoolConf.WorkerName } Else { "ID=$($PoolConf.WorkerName)" }

    $PoolRegions | ForEach-Object { 
        $Region = $_
        $Region_Norm = Get-Region $Region
        
        If ($PoolConf.Wallet) { 
            [PSCustomObject]@{ 
                Algorithm          = [String]$Algoritm_Norm
                Price              = [Double]$Stat.Live
                StablePrice        = [Double]$Stat.Week
                MarginOfError      = [Double]$Stat.Week_Fluctuation
                EstimateCorrection = [Double]$PoolConf.EstimateCorrection
                Protocol           = "stratum+tcp"
                Host               = [String]$PoolHost
                Port               = [UInt16]$PoolPort
                User               = $PoolConf.Wallet
                Pass               = "$($WorkerName),c=$($PasswordCurrency)"
                Region             = [String]$Region_Norm
                SSL                = [Bool]$false
                Fee                = $Fee
            }
        }
    }
}
