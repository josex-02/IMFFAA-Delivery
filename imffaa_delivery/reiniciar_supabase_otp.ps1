$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$config = Join-Path $root 'supabase/config.toml'
$template = Join-Path $root 'supabase/templates/confirmation.html'
if (-not (Test-Path $config)) { throw "No se encontró $config" }
if (-not (Test-Path $template)) { throw "No se encontró $template" }

$html = Get-Content $template -Raw
if ($html -match '\{\{\s*\.ConfirmationURL\s*\}\}') {
  throw 'La plantilla todavía contiene ConfirmationURL. Debe mostrar {{ .Token }} y no el enlace.'
}
if ($html -notmatch '\{\{\s*\.Token\s*\}\}') {
  throw 'La plantilla no contiene {{ .Token }}.'
}

Write-Host 'Plantilla OTP localizada. Se reiniciará Supabase local desde la carpeta del proyecto.' -ForegroundColor Green
npx supabase stop
npx supabase start
if ($LASTEXITCODE -ne 0) { throw 'Supabase no pudo iniciarse. Revisa la salida anterior y la instalación de Docker.' }
Write-Host 'Abre Mailpit en http://127.0.0.1:54324 y crea una cuenta de prueba.' -ForegroundColor Green
