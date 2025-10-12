# Run as Administrator

Write-Host "=== Motherboard Info ==="
$board = Get-CimInstance Win32_BaseBoard
if (-not $board) { $board = Get-CimInstance Win32_ComputerSystemProduct }
$board | Select-Object Manufacturer, Product, SerialNumber | Format-Table | Out-Host

Write-Host "`n=== CPU Info ==="
Get-CimInstance Win32_Processor |
    Select-Object Name, NumberOfCores, NumberOfLogicalProcessors |
    Format-Table | Out-Host

Write-Host "`n=== GPU Info ==="

# Get NVIDIA GPUs via nvidia-smi if available
$nvidiaSMIPath = (Get-Command nvidia-smi -ErrorAction SilentlyContinue).Source
$gpuList = @()

if ($nvidiaSMIPath) {
    $nvidiaInfo = & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    $nvidiaGPUs = $nvidiaInfo | ForEach-Object {
        $parts = $_ -split ','
        [PSCustomObject]@{
            Name          = $parts[0].Trim()
            VRAM_GB       = [math]::Round(($parts[1].Trim() -replace " MiB","")/1024,2)
            DriverVersion = $parts[2].Trim()
            Type          = "Discrete NVIDIA"
        }
    }
    $gpuList += $nvidiaGPUs
}

# Get remaining GPUs via WMI (skip NVIDIA, or include if nvidia-smi not available)
$wmiGPUs = Get-CimInstance Win32_VideoController | ForEach-Object {
    $name = $_.Name
    if ($nvidiaSMIPath -and $name -like "*NVIDIA*") { return } # Skip NVIDIA if already captured
    [PSCustomObject]@{
        Name          = $_.Name
        VRAM_GB       = [math]::Round($_.AdapterRAM / 1GB, 2)
        DriverVersion = $_.DriverVersion
        Type          = "Other"
    }
}
$gpuList += $wmiGPUs

# Display all GPUs
$gpuList | Format-Table Name, Type, VRAM_GB, DriverVersion | Out-Host


Write-Host "`n=== RAM Info ==="
$memTypes = @{
    20="DDR";21="DDR2";22="DDR2 FB-DIMM";24="DDR3";26="DDR4";
    27="LPDDR";28="LPDDR2";29="LPDDR3";30="LPDDR4";34="DDR5"
}
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    $typeCode = if ($_.SMBIOSMemoryType) { $_.SMBIOSMemoryType } else { $_.MemoryType }
    $ramType = $memTypes[$typeCode]

    # Fallback: infer DDR type based on speed
    if (-not $ramType) {
        if ($_.Speed -ge 4000) { $ramType = "DDR5" }
        elseif ($_.Speed -ge 2133) { $ramType = "DDR4" }
        else { $ramType = "Unknown" }
    }

    [PSCustomObject]@{
        Manufacturer = $_.Manufacturer
        CapacityGB   = [math]::Round($_.Capacity / 1GB, 2)
        Type         = $ramType
        SpeedMHz     = $_.Speed
        BankLabel    = $_.BankLabel
    }
} | Format-Table | Out-Host

$totalRam = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
Write-Host "`nTotal RAM (GB): $totalRam"

Write-Host "`n=== Storage Info ==="
Get-CimInstance Win32_DiskDrive |
    Select-Object Model, MediaType, @{Name="Size(GB)";Expression={[math]::Round($_.Size/1GB,2)}} |
    Format-Table | Out-Host
