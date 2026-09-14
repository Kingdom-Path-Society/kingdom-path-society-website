param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$shared = @'
"use client";

export function downloadPdf(bytes: Uint8Array, filename: string) {
  const blob = new Blob([bytes as BlobPart], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function ToolShell({
  title,
  description,
  children
}: {
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <main className="min-h-screen bg-slate-50 py-12">
      <div className="container-page max-w-6xl">
        <p className="eyebrow">PDF Tools</p>
        <h1 className="mt-3 text-4xl font-black text-navy-950">{title}</h1>
        <p className="mt-4 max-w-4xl text-lg leading-8 text-slate-700">
          {description}
        </p>

        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          {children}
        </div>
      </div>
    </main>
  );
}

export function PdfPicker({
  file,
  setFile
}: {
  file: File | null;
  setFile: (file: File | null) => void;
}) {
  return (
    <label className="block cursor-pointer rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center transition hover:border-gold-400">
      <span className="font-black text-navy-950">
        {file ? file.name : "Choose PDF file"}
      </span>

      <input
        type="file"
        accept="application/pdf"
        className="hidden"
        onChange={(event) => setFile(event.target.files?.[0] || null)}
      />
    </label>
  );
}
'@

$full = Join-Path $ProjectRoot "components\pdf\Shared.tsx"
[System.IO.File]::WriteAllText(
  $full,
  $shared,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Restored PdfPicker." -ForegroundColor Green
Write-Host "Running production build..." -ForegroundColor Cyan

npm run build

if ($LASTEXITCODE -ne 0) {
  Write-Host "BUILD FAILED. Nothing was pushed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "SUCCESS: PdfPicker restored and production build passed." -ForegroundColor Green
Write-Host "Next: npm run dev -- -p 3001" -ForegroundColor Yellow
