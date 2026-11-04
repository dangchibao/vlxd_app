$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sampleAssets = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../assets/sample-products'))
$jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -EQ 'image/jpeg'
foreach ($sampleName in @('gach', 'da', 'cat')) {
    $sourceImage = [Drawing.Image]::FromFile((Join-Path $sampleAssets "$sampleName-original.png"))
    try {
        $bitmap = New-Object Drawing.Bitmap 420,420
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($sourceImage, 0, 0, 420, 420)
        } finally { $graphics.Dispose() }
        try {
            $parameters = New-Object Drawing.Imaging.EncoderParameters 1
            $parameters.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality),([long]55)
            try { $bitmap.Save((Join-Path $sampleAssets "$sampleName.jpg"), $jpegCodec, $parameters) }
            finally { $parameters.Dispose() }
        } finally { $bitmap.Dispose() }
    } finally { $sourceImage.Dispose() }
    $resultImage = Get-Item -LiteralPath (Join-Path $sampleAssets "$sampleName.jpg")
    if ($resultImage.Length -gt 40000) { throw "$sampleName image exceeds 40KB" }
    Write-Output "$sampleName.jpg: $($resultImage.Length) bytes"
}
