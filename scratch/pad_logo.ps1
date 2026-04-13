Add-Type -AssemblyName System.Drawing
$originalPath = "assets/images/Logo.png"
$outputPath = "assets/images/LogoPadded.png"

$original = [System.Drawing.Image]::FromFile($originalPath)
$newSize = [int]($original.Width * 1.6)
$bmp = New-Object System.Drawing.Bitmap $newSize, $newSize
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)

$x = [int](($newSize - $original.Width) / 2)
$y = [int](($newSize - $original.Height) / 2)

$g.DrawImage($original, $x, $y, $original.Width, $original.Height)
$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()
$original.Dispose()
