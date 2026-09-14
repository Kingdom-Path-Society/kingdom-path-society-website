param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

function WriteFile {
  param([string]$Path,[string]$Content)
  $full = Join-Path $ProjectRoot $Path
  New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
  [System.IO.File]::WriteAllText($full,$Content,[System.Text.UTF8Encoding]::new($false))
  Write-Host "Updated $Path" -ForegroundColor Green
}

Write-Host "Installing PDF dependencies..." -ForegroundColor Cyan
npm install pdf-lib pdfjs-dist
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Copy the PDF.js worker into public so it works consistently in Next.js/Vercel.
$workerCandidates = @(
  (Join-Path $ProjectRoot "node_modules\pdfjs-dist\legacy\build\pdf.worker.min.mjs"),
  (Join-Path $ProjectRoot "node_modules\pdfjs-dist\build\pdf.worker.min.mjs"),
  (Join-Path $ProjectRoot "node_modules\pdfjs-dist\legacy\build\pdf.worker.mjs"),
  (Join-Path $ProjectRoot "node_modules\pdfjs-dist\build\pdf.worker.mjs")
)
$worker = $workerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $worker) {
  throw "Could not find the pdfjs-dist worker file."
}
Copy-Item $worker (Join-Path $ProjectRoot "public\pdf.worker.min.mjs") -Force
Write-Host "Installed public\pdf.worker.min.mjs" -ForegroundColor Green

$pdfjsClient = @'
export async function loadPdfJs() {
  const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
  pdfjs.GlobalWorkerOptions.workerSrc = "/pdf.worker.min.mjs";
  return pdfjs;
}
'@
WriteFile "lib\pdfjsClient.ts" $pdfjsClient

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
        <p className="mt-4 max-w-4xl text-lg leading-8 text-slate-700">{description}</p>
        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          {children}
        </div>
      </div>
    </main>
  );
}
'@
WriteFile "components\pdf\Shared.tsx" $shared

$workspace = @'
"use client";

import { useState } from "react";
import { PDFDocument, degrees } from "pdf-lib";
import {
  ArrowLeft,
  ArrowRight,
  Download,
  FilePlus2,
  Files,
  RotateCw,
  Scissors,
  Trash2,
  X
} from "lucide-react";
import { downloadPdf } from "@/components/pdf/Shared";
import { loadPdfJs } from "@/lib/pdfjsClient";

type SourceFile = {
  id: string;
  name: string;
  bytes: ArrayBuffer;
  pageCount: number;
};

type PageItem = {
  id: string;
  sourceId: string;
  sourcePageIndex: number;
  rotation: number;
  preview: string;
};

async function makePreview(
  bytes: ArrayBuffer,
  pageIndex: number,
  rotation: number
) {
  const pdfjs = await loadPdfJs();
  const pdf = await pdfjs.getDocument({ data: bytes.slice(0) }).promise;
  const page = await pdf.getPage(pageIndex + 1);
  const viewport = page.getViewport({ scale: 0.62, rotation });

  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("Canvas unavailable");

  canvas.width = Math.max(1, Math.floor(viewport.width));
  canvas.height = Math.max(1, Math.floor(viewport.height));

  await page.render({
    canvas,
    canvasContext: context,
    viewport
  }).promise;

  return canvas.toDataURL("image/jpeg", 0.82);
}

export function PdfWorkspace({
  title,
  description
}: {
  title: string;
  description: string;
}) {
  const [sources, setSources] = useState<SourceFile[]>([]);
  const [pages, setPages] = useState<PageItem[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  async function addFiles(fileList: FileList | null) {
    if (!fileList?.length) return;

    setBusy(true);
    setMessage("Opening PDF pages...");

    try {
      const sourceAdditions: SourceFile[] = [];
      const pageAdditions: PageItem[] = [];

      for (const file of Array.from(fileList)) {
        const bytes = await file.arrayBuffer();
        const doc = await PDFDocument.load(bytes);
        const sourceId = `${Date.now()}-${Math.random()}-${file.name}`;

        sourceAdditions.push({
          id: sourceId,
          name: file.name,
          bytes,
          pageCount: doc.getPageCount()
        });

        for (let pageIndex = 0; pageIndex < doc.getPageCount(); pageIndex += 1) {
          const preview = await makePreview(bytes, pageIndex, 0);
          pageAdditions.push({
            id: `${sourceId}-${pageIndex}-${Math.random()}`,
            sourceId,
            sourcePageIndex: pageIndex,
            rotation: 0,
            preview
          });
        }
      }

      setSources((current) => [...current, ...sourceAdditions]);
      setPages((current) => [...current, ...pageAdditions]);
      setMessage("");
    } catch (error) {
      console.error(error);
      setMessage("");
      alert("One of the PDF files could not be opened.");
    } finally {
      setBusy(false);
    }
  }

  function sourceFor(page: PageItem) {
    return sources.find((source) => source.id === page.sourceId);
  }

  function removeSource(sourceId: string) {
    setSources((current) => current.filter((source) => source.id !== sourceId));
    setPages((current) => current.filter((page) => page.sourceId !== sourceId));
  }

  function removePage(pageId: string) {
    setPages((current) => current.filter((page) => page.id !== pageId));
  }

  function movePage(index: number, direction: -1 | 1) {
    const target = index + direction;
    if (target < 0 || target >= pages.length) return;

    setPages((current) => {
      const copy = [...current];
      [copy[index], copy[target]] = [copy[target], copy[index]];
      return copy;
    });
  }

  async function rotatePage(index: number) {
    const item = pages[index];
    const source = sourceFor(item);
    if (!source) return;

    const rotation = (item.rotation + 90) % 360;
    const preview = await makePreview(
      source.bytes,
      item.sourcePageIndex,
      rotation
    );

    setPages((current) =>
      current.map((page, i) =>
        i === index ? { ...page, rotation, preview } : page
      )
    );
  }

  async function extractPage(index: number) {
    const item = pages[index];
    const source = sourceFor(item);
    if (!source) return;

    const sourceDoc = await PDFDocument.load(source.bytes.slice(0));
    const output = await PDFDocument.create();
    const [copied] = await output.copyPages(sourceDoc, [item.sourcePageIndex]);
    copied.setRotation(
      degrees((copied.getRotation().angle + item.rotation) % 360)
    );
    output.addPage(copied);
    downloadPdf(await output.save(), `page-${index + 1}.pdf`);
  }

  async function downloadFinal() {
    if (!pages.length) return;

    setBusy(true);
    setMessage("Creating final PDF...");

    try {
      const output = await PDFDocument.create();
      const loaded = new Map<string, PDFDocument>();

      for (const source of sources) {
        loaded.set(source.id, await PDFDocument.load(source.bytes.slice(0)));
      }

      for (const item of pages) {
        const sourceDoc = loaded.get(item.sourceId);
        if (!sourceDoc) continue;

        const [copied] = await output.copyPages(sourceDoc, [item.sourcePageIndex]);
        copied.setRotation(
          degrees((copied.getRotation().angle + item.rotation) % 360)
        );
        output.addPage(copied);
      }

      downloadPdf(await output.save(), "merged-edited-document.pdf");
      setMessage("");
    } catch (error) {
      console.error(error);
      setMessage("");
      alert("The final PDF could not be created.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="min-h-screen bg-slate-50 py-12">
      <div className="container-page max-w-7xl">
        <p className="eyebrow">PDF Tools</p>
        <h1 className="mt-3 text-4xl font-black text-navy-950">{title}</h1>
        <p className="mt-4 max-w-4xl text-lg leading-8 text-slate-700">
          {description}
        </p>

        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <label className="flex cursor-pointer items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 px-5 py-8 font-black text-navy-950 transition hover:border-gold-400">
            <FilePlus2 className="size-5" />
            {sources.length ? "Add More PDF Files" : "Choose PDF Files"}
            <input
              type="file"
              accept="application/pdf"
              multiple
              className="hidden"
              onChange={(event) => addFiles(event.target.files)}
            />
          </label>

          {message ? (
            <div className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">
              {message}
            </div>
          ) : null}

          {sources.length ? (
            <section className="mt-6">
              <div className="mb-3 flex items-center gap-2">
                <Files className="size-5 text-navy-950" />
                <h2 className="text-lg font-black text-navy-950">
                  PDF Documents ({sources.length})
                </h2>
              </div>

              <div className="grid gap-3 md:grid-cols-2">
                {sources.map((source) => (
                  <div
                    key={source.id}
                    className="flex items-center justify-between gap-4 rounded-lg border border-slate-200 bg-slate-50 p-4"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-black text-navy-950">
                        {source.name}
                      </p>
                      <p className="mt-1 text-xs font-semibold text-slate-500">
                        {source.pageCount} page{source.pageCount === 1 ? "" : "s"}
                      </p>
                    </div>

                    <button
                      type="button"
                      onClick={() => removeSource(source.id)}
                      className="inline-flex shrink-0 items-center gap-1 rounded border border-red-200 px-3 py-2 text-xs font-black text-red-700"
                    >
                      <X className="size-4" />
                      Remove PDF
                    </button>
                  </div>
                ))}
              </div>
            </section>
          ) : null}

          {pages.length ? (
            <>
              <div className="mt-6 flex flex-wrap items-center justify-between gap-3 rounded-lg bg-navy-50 p-4">
                <p className="font-black text-navy-950">
                  Final document: {pages.length} page{pages.length === 1 ? "" : "s"}
                </p>

                <button
                  type="button"
                  onClick={downloadFinal}
                  disabled={busy}
                  className="inline-flex items-center gap-2 rounded-lg bg-navy-950 px-5 py-3 font-black text-white disabled:opacity-50"
                >
                  <Download className="size-4" />
                  Merge & Download Final PDF
                </button>
              </div>

              <div className="mt-6 grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {pages.map((item, index) => {
                  const source = sourceFor(item);

                  return (
                    <article
                      key={item.id}
                      className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"
                    >
                      <div className="flex min-h-64 items-center justify-center bg-slate-100 p-3">
                        <img
                          src={item.preview}
                          alt={`Page ${index + 1}`}
                          className="max-h-72 max-w-full rounded shadow"
                        />
                      </div>

                      <div className="p-4">
                        <p className="font-black text-navy-950">
                          Final Page {index + 1}
                        </p>
                        <p className="mt-1 truncate text-xs font-semibold text-slate-500">
                          {source?.name} - original page {item.sourcePageIndex + 1}
                        </p>

                        <div className="mt-4 grid grid-cols-4 gap-2">
                          <button
                            type="button"
                            title="Move left"
                            onClick={() => movePage(index, -1)}
                            disabled={index === 0}
                            className="grid min-h-10 place-items-center rounded border disabled:opacity-30"
                          >
                            <ArrowLeft className="size-4" />
                          </button>

                          <button
                            type="button"
                            title="Move right"
                            onClick={() => movePage(index, 1)}
                            disabled={index === pages.length - 1}
                            className="grid min-h-10 place-items-center rounded border disabled:opacity-30"
                          >
                            <ArrowRight className="size-4" />
                          </button>

                          <button
                            type="button"
                            title="Rotate page"
                            onClick={() => rotatePage(index)}
                            className="grid min-h-10 place-items-center rounded border"
                          >
                            <RotateCw className="size-4" />
                          </button>

                          <button
                            type="button"
                            title="Extract page"
                            onClick={() => extractPage(index)}
                            className="grid min-h-10 place-items-center rounded border"
                          >
                            <Scissors className="size-4" />
                          </button>
                        </div>

                        <button
                          type="button"
                          onClick={() => removePage(item.id)}
                          className="mt-2 inline-flex w-full items-center justify-center gap-2 rounded border border-red-200 px-3 py-2 font-black text-red-700"
                        >
                          <Trash2 className="size-4" />
                          Delete This Page
                        </button>
                      </div>
                    </article>
                  );
                })}
              </div>
            </>
          ) : null}
        </div>
      </div>
    </main>
  );
}
'@
WriteFile "components\pdf\PdfWorkspace.tsx" $workspace

$merge = @'
import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Merge PDF"
      description="Open all PDF documents visually. Add more PDFs, remove a whole PDF, delete pages, reorder pages, rotate pages, extract pages, then merge and download the final document."
    />
  );
}
'@
WriteFile "app\pdf-tools\merge\page.tsx" $merge

$editor = @'
import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Visual PDF Editor"
      description="Open PDFs visually and organize the complete document before downloading."
    />
  );
}
'@
WriteFile "app\pdf-tools\editor\page.tsx" $editor

$split = @'
import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Split / Extract PDF"
      description="Open the PDF visually, remove pages you do not want, extract individual pages, reorder pages, and download the result."
    />
  );
}
'@
WriteFile "app\pdf-tools\split\page.tsx" $split
WriteFile "app\pdf-tools\extract-pages\page.tsx" $split

$delete = @'
import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Delete PDF Pages"
      description="Open the PDF visually, delete any page, add another PDF if needed, reorder the remaining pages, and download the final document."
    />
  );
}
'@
WriteFile "app\pdf-tools\delete-pages\page.tsx" $delete

$rotate = @'
import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Rotate PDF Pages"
      description="Open every page visually, rotate individual pages, reorder or delete pages, add PDFs, and download the result."
    />
  );
}
'@
WriteFile "app\pdf-tools\rotate\page.tsx" $rotate

$compress = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { ToolShell } from "@/components/pdf/Shared";
import { loadPdfJs } from "@/lib/pdfjsClient";

type Mode = "light" | "medium" | "maximum";

const modes: Record<
  Mode,
  { label: string; scale: number; quality: number; description: string }
> = {
  light: {
    label: "Light",
    scale: 1.0,
    quality: 0.72,
    description: "Better visual quality"
  },
  medium: {
    label: "Medium",
    scale: 0.78,
    quality: 0.5,
    description: "Balanced compression"
  },
  maximum: {
    label: "Maximum",
    scale: 0.58,
    quality: 0.3,
    description: "Smallest file"
  }
};

function download(bytes: Uint8Array, filename: string) {
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

export default function CompressPdfPage() {
  const [file, setFile] = useState<File | null>(null);
  const [mode, setMode] = useState<Mode>("medium");
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState("");
  const [result, setResult] = useState("");

  async function compress() {
    if (!file) return;

    setBusy(true);
    setResult("");

    try {
      const input = await file.arrayBuffer();
      const pdfjs = await loadPdfJs();
      const source = await pdfjs.getDocument({ data: input.slice(0) }).promise;
      const output = await PDFDocument.create();
      const setting = modes[mode];

      for (let pageIndex = 0; pageIndex < source.numPages; pageIndex += 1) {
        setProgress(`Compressing page ${pageIndex + 1} of ${source.numPages}...`);

        const sourcePage = await source.getPage(pageIndex + 1);
        const baseViewport = sourcePage.getViewport({ scale: 1 });
        const renderViewport = sourcePage.getViewport({ scale: setting.scale });

        const canvas = document.createElement("canvas");
        const context = canvas.getContext("2d");
        if (!context) throw new Error("Canvas unavailable");

        canvas.width = Math.max(1, Math.floor(renderViewport.width));
        canvas.height = Math.max(1, Math.floor(renderViewport.height));

        await sourcePage.render({
          canvas,
          canvasContext: context,
          viewport: renderViewport
        }).promise;

        const imageBlob = await new Promise<Blob>((resolve, reject) => {
          canvas.toBlob(
            (blob) => (blob ? resolve(blob) : reject(new Error("JPEG conversion failed"))),
            "image/jpeg",
            setting.quality
          );
        });

        const image = await output.embedJpg(await imageBlob.arrayBuffer());
        const page = output.addPage([baseViewport.width, baseViewport.height]);

        page.drawImage(image, {
          x: 0,
          y: 0,
          width: baseViewport.width,
          height: baseViewport.height
        });
      }

      setProgress("Finalizing compressed PDF...");
      const bytes = await output.save({ useObjectStreams: true });

      const before = file.size;
      const after = bytes.length;
      const percent = before > 0 ? (1 - after / before) * 100 : 0;

      if (after >= before) {
        setResult(
          `This PDF is already efficiently compressed. Generated size ${(after / 1048576).toFixed(2)} MB versus original ${(before / 1048576).toFixed(2)} MB. Try Maximum for a smaller result.`
        );
      } else {
        setResult(
          `Original ${(before / 1048576).toFixed(2)} MB -> ${(after / 1048576).toFixed(2)} MB (${percent.toFixed(1)}% smaller)`
        );
      }

      download(bytes, `compressed-${mode}.pdf`);
      setProgress("");
    } catch (error) {
      console.error(error);
      setProgress("");
      alert("Compression could not complete for this PDF.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ToolShell
      title="Compress PDF"
      description="Compress image-heavy and scanned PDFs. Maximum gives the smallest file and lowers image quality the most."
    >
      <input
        type="file"
        accept="application/pdf"
        onChange={(event) => setFile(event.target.files?.[0] || null)}
        className="block w-full rounded-lg border border-slate-300 p-3"
      />

      {file ? (
        <div className="mt-4 rounded-lg bg-slate-50 p-4">
          <p className="font-black text-navy-950">{file.name}</p>
          <p className="mt-1 text-sm font-semibold text-slate-600">
            Original size: {(file.size / 1048576).toFixed(2)} MB
          </p>
        </div>
      ) : null}

      <div className="mt-5 grid gap-3 sm:grid-cols-3">
        {(Object.keys(modes) as Mode[]).map((key) => (
          <button
            key={key}
            type="button"
            onClick={() => setMode(key)}
            className={`rounded-lg border p-4 text-left ${
              mode === key
                ? "border-gold-500 bg-gold-50"
                : "border-slate-200 bg-white"
            }`}
          >
            <span className="block font-black text-navy-950">
              {modes[key].label}
            </span>
            <span className="mt-1 block text-xs font-semibold text-slate-600">
              {modes[key].description}
            </span>
          </button>
        ))}
      </div>

      <button
        type="button"
        onClick={compress}
        disabled={!file || busy}
        className="mt-5 w-full rounded-lg bg-navy-950 p-4 font-black text-white disabled:opacity-50"
      >
        {busy ? "Compressing..." : `Compress - ${modes[mode].label}`}
      </button>

      {progress ? (
        <p className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">
          {progress}
        </p>
      ) : null}

      {result ? (
        <div className="mt-4 rounded-lg border border-green-200 bg-green-50 p-4 font-bold text-green-800">
          {result}
        </div>
      ) : null}

      <p className="mt-4 text-sm leading-6 text-amber-800">
        Strong compression rasterizes each page. The document remains visually readable,
        but selectable/searchable text becomes part of the page image.
      </p>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\compress\page.tsx" $compress

$hub = @'
import Link from "next/link";
import {
  Bot,
  Combine,
  Crop,
  FileMinus2,
  FileOutput,
  FileText,
  Files,
  Image,
  Languages,
  ListOrdered,
  MessageSquareText,
  Minimize2,
  Pencil,
  RefreshCcw,
  RotateCw,
  ScanText,
  Scissors,
  ShieldCheck,
  Signature,
  Stamp,
  Trash2
} from "lucide-react";
import { PageHeader } from "@/components/PageHeader";

const tools = [
  ["Merge", Combine, "/pdf-tools/merge", "See all PDFs and pages, add, delete, reorder, rotate and merge"],
  ["Visual PDF Editor", Files, "/pdf-tools/editor", "Complete visual page workspace"],
  ["Compress", Minimize2, "/pdf-tools/compress", "Light, medium and maximum compression"],
  ["Split", Scissors, "/pdf-tools/split", "Open pages visually and create the PDF you need"],
  ["Delete Pages", Trash2, "/pdf-tools/delete-pages", "Delete pages visually"],
  ["Extract Pages", FileOutput, "/pdf-tools/extract-pages", "Extract individual pages"],
  ["Rotate", RotateCw, "/pdf-tools/rotate", "Rotate individual pages visually"],
  ["Annotate", Pencil, "/pdf-tools/annotate", "Add a note"],
  ["Crop", Crop, "/pdf-tools/crop", "Crop all pages"],
  ["Sign", Signature, "/pdf-tools/sign", "Add signature image"],
  ["Number Pages", ListOrdered, "/pdf-tools/number-pages", "Add page numbering"],
  ["Watermark", Stamp, "/pdf-tools/watermark", "Add watermark"],
  ["PDF <-> Image", Image, "/pdf-tools/pdf-image", "Images to PDF"],
  ["PDF Converter", RefreshCcw, "/pdf-tools/converter", "Conversion center"],
  ["PDF <-> Word", FileText, "/pdf-tools/pdf-word", "Needs conversion API"],
  ["Translate", Languages, "/pdf-tools/translate", "Needs API setup"],
  ["PDF OCR", ScanText, "/pdf-tools/ocr", "Needs OCR setup"],
  ["Protect", ShieldCheck, "/pdf-tools/protect", "Needs encryption API"],
  ["Chat with PDF", MessageSquareText, "/pdf-tools/chat", "Needs AI API"],
  ["AI PDF Assistant", Bot, "/pdf-tools/ai-assistant", "Needs AI API"]
] as const;

export default function PdfToolsPage() {
  return (
    <>
      <PageHeader
        eyebrow="Document Center"
        title="PDF Tools"
        description="Merge, visually edit, compress, sign, convert, and organize PDF documents."
      />
      <section className="section-y bg-slate-50">
        <div className="container-page">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {tools.map(([name, Icon, href, status]) => (
              <Link
                key={name}
                href={href}
                className="group flex min-h-28 items-center gap-4 rounded-lg border border-slate-200 bg-white px-5 py-4 shadow-sm transition hover:-translate-y-0.5 hover:border-gold-400 hover:shadow-md"
              >
                <span className="grid size-11 shrink-0 place-items-center rounded-md bg-navy-950 text-white">
                  <Icon className="size-5" aria-hidden="true" />
                </span>
                <div>
                  <h2 className="font-black text-navy-950">{name}</h2>
                  <p className="mt-1 text-xs font-semibold leading-5 text-slate-500">
                    {status}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
'@
WriteFile "app\pdf-tools\page.tsx" $hub

Write-Host "Running production build check..." -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) {
  Write-Host "BUILD FAILED. Nothing was pushed. Send the error to ChatGPT." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "SUCCESS: PDF workspace upgrade installed and production build passed." -ForegroundColor Green
Write-Host "You can rest. No GitHub push was performed automatically." -ForegroundColor Yellow
Write-Host "Tomorrow/test later: npm run dev -- -p 3001" -ForegroundColor Yellow
