param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$file = Join-Path $ProjectRoot "app\pdf-tools\pdf-word\page.tsx"

if (-not (Test-Path $file)) {
  throw "Could not find app\pdf-tools\pdf-word\page.tsx"
}

$text = Get-Content $file -Raw

$text = $text.Replace(
  'const document = new Document({',
  'const wordDocument = new Document({'
)

$text = $text.Replace(
  'const blob = await Packer.toBlob(document);',
  'const blob = await Packer.toBlob(wordDocument);'
)

$text = $text.Replace(
  'const link = document.createElement("a");',
  'const link = window.document.createElement("a");'
)

$text = $text.Replace(
  'document.body.appendChild(link);',
  'window.document.body.appendChild(link);'
)

[System.IO.File]::WriteAllText(
  $file,
  $text,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Fixed PDF to Word naming conflict." -ForegroundColor Green
Write-Host "Running production build..." -ForegroundColor Cyan

npm run build

if ($LASTEXITCODE -ne 0) {
  Write-Host "BUILD FAILED. Nothing was pushed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "Build passed." -ForegroundColor Green
Write-Host "Committing and pushing..." -ForegroundColor Cyan

git add app/pdf-tools/pdf-word/page.tsx

$changes = git status --porcelain
if ($changes) {
  git commit -m "Fix PDF to Word browser download"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

git push origin main

if ($LASTEXITCODE -ne 0) {
  Write-Host "Git push failed. Local fix is still safe." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "SUCCESS: PDF to Word fixed, build passed, and changes pushed to GitHub." -ForegroundColor Green
