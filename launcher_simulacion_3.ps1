# El script de contenido puede haber llegado ya al equipo vía CrowdStrike RTR
# (put file); si no está, se descarga desde el repositorio público como respaldo.
$rutaContenido = "C:\Temp\simulacion_3.ps1"
if (-not (Test-Path $rutaContenido)) {
    Write-Host "El script de contenido no está en el equipo, descargando desde el repositorio..."
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JoseHerrera00/ps-sim-imagenes/main/simulacion_3.ps1" -OutFile $rutaContenido -UseBasicParsing
}

# Definir la hora a la que se debe ejecutar la tarea
$horaEjecucion = Get-Date -Year 2026 -Month 7 -Day 18 -Hour 16 -Minute 40 -Second 0

# Crear la acción para ejecutar el script con PowerShell
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Normal -File "C:\Temp\simulacion_3.ps1"'

# Crear el trigger para que se ejecute solo una vez en la fecha y hora especificadas
$Trigger = New-ScheduledTaskTrigger -Once -At $horaEjecucion

# Obtener el usuario actual para ejecutar la tarea con ese usuario
$usuario = (Get-WmiObject -Class Win32_ComputerSystem).UserName

# Registrar o reemplazar la tarea programada con privilegios elevados
Register-ScheduledTask -TaskName "InteractiveTask" -Action $Action -Trigger $Trigger -RunLevel Highest -User $usuario -Force
