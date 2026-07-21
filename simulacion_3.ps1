Add-Type @"
using System;
using System.Runtime.InteropServices;

public class CursorControl {
    [DllImport("user32.dll")]
    public static extern bool ShowCursor(bool bShow);
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class InputControl {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Cargar librerías de WPF y Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Ruta de las imágenes
$imagePaths = @(
    "https://raw.githubusercontent.com/JoseHerrera00/ps-sim-imagenes/main/2_image2.png",
    "https://raw.githubusercontent.com/JoseHerrera00/ps-sim-imagenes/main/1_Image4.png"
)
$image4Path = "https://raw.githubusercontent.com/JoseHerrera00/ps-sim-imagenes/main/2_image2.png"

# Verificar si todas las imágenes existen
$imagePaths += $image4Path
$imagePaths = $imagePaths | Where-Object {
    try {
        $request = [System.Net.WebRequest]::Create($_)
        $request.Method = "HEAD"
        $response = $request.GetResponse()
        $response.Close()
        $true
    } catch {
        Write-Host "La imagen '$_' no existe o no se puede alcanzar. Será omitida." -ForegroundColor Yellow
        $false
    }
}

if ($imagePaths.Count -eq 0) {
    Write-Host "No se encontró ninguna imagen válida. Finalizando proceso." -ForegroundColor Red
    exit
}

# Función para cargar una imagen de manera robusta
function Load-Image {
    param (
        [string]$imagePath
    )

    try {
        $webClient = New-Object System.Net.WebClient
        $imageBytes = $webClient.DownloadData($imagePath)

        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()

        $ms = New-Object System.IO.MemoryStream
        $ms.Write($imageBytes, 0, $imageBytes.Length)
        $ms.Seek(0, 'Begin') | Out-Null

        $bitmap.StreamSource = $ms
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    }
    catch {
        Write-Host "Error al cargar la imagen: $imagePath. Detalles: $_" -ForegroundColor Red
        return $null
    }
}

# Función para crear una ventana con una imagen
function Create-ImageWindow {
    param (
        [string]$imagePath,
        [string]$title,
        [System.Drawing.Rectangle]$monitorBounds
    )

    try {
        $window = New-Object System.Windows.Window
        $window.Title = $title
        $window.WindowStartupLocation = "Manual"
        $window.Topmost = $true
        $window.ResizeMode = "NoResize"
        $window.WindowStyle = "None"
        $window.ShowInTaskbar = $false
        $window.Left = $monitorBounds.Left
        $window.Top = $monitorBounds.Top
        $window.Width = $monitorBounds.Width
        $window.Height = $monitorBounds.Height

        $imageControl = New-Object System.Windows.Controls.Image
        $imageControl.Stretch = "UniformTofill"

        $imageSource = Load-Image -imagePath $imagePath
        if ($imageSource -ne $null) {
            $imageControl.Source = $imageSource
        } else {
            Write-Host "No se pudo cargar la imagen: $imagePath." -ForegroundColor Yellow
        }

        $window.Content = $imageControl
        $window.Show()

        return $window
    }
    catch {
        Write-Host "Error al crear la ventana para la imagen: $imagePath. Detalles: $_" -ForegroundColor Red
        return $null
    }
}

function Show-ImagesSequentially {
    param (
        [System.Drawing.Rectangle]$monitorPrincipal
    )

    $imageDisplayTimes = @(
        60,
        60
    )

    # --- INICIO DE AUDIO ---

    $audioPath = "C:\Temp\Popupvideo.mp3"
    if (Test-Path $audioPath) {
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open([Uri]::new("file:///" + $audioPath.Replace('\', '/')))
        $player.Play()

        # Detener el audio después de 58 segundos
        $timer = New-Object System.Timers.Timer
        $timer.Interval = 58000
        $timer.AutoReset = $false
        $timer.add_Elapsed({
            $player.Stop()
            $player.Close()
            $timer.Stop()
            $timer.Dispose()
        })
        $timer.Start()
    } else {
        Write-Host "No se encontró el archivo de audio en: $audioPath" -ForegroundColor Yellow
    }

    # --- FIN DE AUDIO ---

    $windows = @()
    $currentWindow = $null

    for ($i = 0; $i -lt $imagePaths.Count - 1; $i++) {
        $imagePath = $imagePaths[$i]

        $newWindow = Create-ImageWindow -imagePath $imagePath -title "Imagen Principal" -monitorBounds $monitorPrincipal
        if ($newWindow) {
            if ($currentWindow -ne $null) {
                $currentWindow.Dispatcher.Invoke([Action]{ $currentWindow.Close() })
            }
            $currentWindow = $newWindow
        }

        Start-Sleep -Seconds $imageDisplayTimes[$i]
    }

    if ($currentWindow -ne $null) {
        $currentWindow.Dispatcher.Invoke([Action]{ $currentWindow.Close() })
    }
}

# Función para mostrar la imagen en el monitor secundario
function Show-ImageOnSecondaryMonitor {
    param (
        [System.Drawing.Rectangle]$monitorSecundario
    )

    $window = Create-ImageWindow -imagePath $image4Path -title "Imagen Secundaria" -monitorBounds $monitorSecundario
    return $window
}

# Función principal
function Run-Process {
    $secondaryWindow = $null
    try {
        [CursorControl]::ShowCursor($false)  # Ocultar cursor
        [InputControl]::BlockInput($true)  # Bloquear teclado y mouse

        # Obtener monitores
        $monitorPrincipal = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $monitorSecundario = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -Not $_.Primary } | Select-Object -First 1

        if ($monitorSecundario -eq $null) {
            Write-Host "No se detectó un monitor secundario. Continuando con imágenes principales." -ForegroundColor Yellow
        } else {
            $secondaryWindow = Show-ImageOnSecondaryMonitor -monitorSecundario $monitorSecundario.Bounds
        }

        Show-ImagesSequentially -monitorPrincipal $monitorPrincipal
    }
    catch {
        Write-Host "Ocurrió un error: $_" -ForegroundColor Red
        Write-Host "Detalles del error: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if ($secondaryWindow -ne $null) {
            $secondaryWindow.Dispatcher.Invoke([Action]{ $secondaryWindow.Close() })
        }
        [InputControl]::BlockInput($false)  # Restaurar input
        [CursorControl]::ShowCursor($true)  # Restaurar cursor
    }
}

# Ejecutar el proceso
Run-Process
