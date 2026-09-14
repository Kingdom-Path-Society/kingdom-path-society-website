param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

Write-Host "Installing PDF editor dependencies..." -ForegroundColor Cyan
npm install pdf-lib pdfjs-dist
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

function WriteFile {
  param([string]$Path,[string]$Content)
  $full = Join-Path $ProjectRoot $Path
  New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
  [IO.File]::WriteAllText($full,$Content,[Text.UTF8Encoding]::new($false))
  Write-Host "Updated $Path" -ForegroundColor Green
}

$editor = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { PDFDocument, degrees } from "pdf-lib";
import {
  ArrowDown,
  ArrowUp,
  Download,
  FilePlus2,
  RotateCw,
  Scissors,
  Trash2
} from "lucide-react";
import { ToolShell, downloadPdf } from "@/components/pdf/Shared";

type PageItem = {
  id: string;
  sourceFileIndex: number;
  sourcePageIndex: number;
  rotation: number;
  preview?: string;
};

type SourceFile = {
  name: string;
  bytes: ArrayBuffer;
};

async function renderPagePreview(bytes: ArrayBuffer, pageNumber: number, rotation: number) {
  const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
  const loadingTask = pdfjs.getDocument({ data: bytes.slice(0) });
  const pdf = await loadingTask.promise;
  const page = await pdf.getPage(pageNumber + 1);
  const viewport = page.getViewport({ scale: 0.55, rotation });
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");
  if (!context) return "";
  canvas.width = viewport.width;
  canvas.height = viewport.height;
  await page.render({ canvasContext: context, viewport }).promise;
  return canvas.toDataURL("image/jpeg", 0.82);
}

export default function PdfEditorPage() {
  const [sources, setSources] = useState<SourceFile[]>([]);
  const [pages, setPages] = useState<PageItem[]>([]);
  const [busy, setBusy] = useState(false);

  async function addFiles(fileList: FileList | null) {
    if (!fileList?.length) return;
    setBusy(true);

    try {
      const newSources = [...sources];
      const newPages = [...pages];

      for (const file of Array.from(fileList)) {
        const bytes = await file.arrayBuffer();
        const doc = await PDFDocument.load(bytes);
        const sourceFileIndex = newSources.length;

        newSources.push({ name: file.name, bytes });

        for (let pageIndex = 0; pageIndex < doc.getPageCount(); pageIndex += 1) {
          const id = `${Date.now()}-${Math.random()}-${sourceFileIndex}-${pageIndex}`;
          const preview = await renderPagePreview(bytes, pageIndex, 0);
          newPages.push({
            id,
            sourceFileIndex,
            sourcePageIndex: pageIndex,
            rotation: 0,
            preview
          });
        }
      }

      setSources(newSources);
      setPages(newPages);
    } finally {
      setBusy(false);
    }
  }

  function move(index: number, direction: -1 | 1) {
    const target = index + direction;
    if (target < 0 || target >= pages.length) return;
    const copy = [...pages];
    [copy[index], copy[target]] = [copy[target], copy[index]];
    setPages(copy);
  }

  async function rotate(index: number) {
    const item = pages[index];
    const rotation = (item.rotation + 90) % 360;
    const preview = await renderPagePreview(
      sources[item.sourceFileIndex].bytes,
      item.sourcePageIndex,
      rotation
    );

    setPages((current) =>
      current.map((page, i) =>
        i === index ? { ...page, rotation, preview } : page
      )
    );
  }

  function remove(index: number) {
    setPages((current) => current.filter((_, i) => i !== index));
  }

  async function downloadCurrent(filename = "edited-document.pdf") {
    if (!pages.length) return;
    setBusy(true);

    try {
      const output = await PDFDocument.create();
      const loaded = await Promise.all(
        sources.map((source) => PDFDocument.load(source.bytes.slice(0)))
      );

      for (const item of pages) {
        const source = loaded[item.sourceFileIndex];
        const [copied] = await output.copyPages(source, [item.sourcePageIndex]);
        copied.setRotation(degrees((copied.getRotation().angle + item.rotation) % 360));
        output.addPage(copied);
      }

      downloadPdf(await output.save(), filename);
    } finally {
      setBusy(false);
    }
  }

  async function downloadSelected(index: number) {
    const item = pages[index];
    const source = await PDFDocument.load(
      sources[item.sourceFileIndex].bytes.slice(0)
    );
    const output = await PDFDocument.create();
    const [copied] = await output.copyPages(source, [item.sourcePageIndex]);
    copied.setRotation(degrees((copied.getRotation().angle + item.rotation) % 360));
    output.addPage(copied);
    downloadPdf(await output.save(), `page-${index + 1}.pdf`);
  }

  const total = pages.length;

  return (
    <ToolShell
      title="Visual PDF Editor"
      description="Open PDFs, see every page, add more PDFs, reorder, rotate, delete, extract pages, merge everything, and download the final document."
    >
      <label className="flex cursor-pointer items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 px-5 py-8 font-black text-navy-950 transition hover:border-gold-400">
        <FilePlus2 className="size-5" />
        {total ? "Add More PDF Files" : "Choose PDF Files"}
        <input
          type="file"
          accept="application/pdf"
          multiple
          className="hidden"
          onChange={(event) => addFiles(event.target.files)}
        />
      </label>

      {busy ? (
        <p className="mt-4 font-bold text-slate-600">Processing PDF pages...</p>
      ) : null}

      {pages.length ? (
        <>
          <div className="mt-6 flex flex-wrap items-center justify-between gap-3 rounded-lg bg-slate-100 p-4">
            <p className="font-black text-navy-950">
              {pages.length} page{pages.length === 1 ? "" : "s"} in final document
            </p>

            <button
              type="button"
              onClick={() => downloadCurrent()}
              className="inline-flex items-center gap-2 rounded-lg bg-navy-950 px-5 py-3 font-black text-white"
            >
              <Download className="size-4" />
              Download Final PDF
            </button>
          </div>

          <div className="mt-6 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {pages.map((item, index) => (
              <article
                key={item.id}
                className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"
              >
                <div className="flex min-h-64 items-center justify-center bg-slate-100 p-3">
                  {item.preview ? (
                    <img
                      src={item.preview}
                      alt={`Page ${index + 1}`}
                      className="max-h-72 max-w-full rounded shadow"
                    />
                  ) : (
                    <span>Page {index + 1}</span>
                  )}
                </div>

                <div className="p-4">
                  <div className="flex items-center justify-between gap-2">
                    <div>
                      <p className="font-black text-navy-950">Page {index + 1}</p>
                      <p className="text-xs text-slate-500">
                        {sources[item.sourceFileIndex]?.name}
                      </p>
                    </div>
                    <span className="rounded bg-slate-100 px-2 py-1 text-xs font-bold">
                      {item.rotation} deg
                    </span>
                  </div>

                  <div className="mt-4 grid grid-cols-3 gap-2">
                    <button
                      type="button"
                      onClick={() => move(index, -1)}
                      disabled={index === 0}
                      className="grid min-h-10 place-items-center rounded border disabled:opacity-30"
                      title="Move earlier"
                    >
                      <ArrowUp className="size-4" />
                    </button>

                    <button
                      type="button"
                      onClick={() => move(index, 1)}
                      disabled={index === pages.length - 1}
                      className="grid min-h-10 place-items-center rounded border disabled:opacity-30"
                      title="Move later"
                    >
                      <ArrowDown className="size-4" />
                    </button>

                    <button
                      type="button"
                      onClick={() => rotate(index)}
                      className="grid min-h-10 place-items-center rounded border"
                      title="Rotate"
                    >
                      <RotateCw className="size-4" />
                    </button>

                    <button
                      type="button"
                      onClick={() => downloadSelected(index)}
                      className="grid min-h-10 place-items-center rounded border"
                      title="Extract this page"
                    >
                      <Scissors className="size-4" />
                    </button>

                    <button
                      type="button"
                      onClick={() => remove(index)}
                      className="col-span-2 inline-flex min-h-10 items-center justify-center gap-2 rounded border border-red-200 text-red-700"
                    >
                      <Trash2 className="size-4" />
                      Delete Page
                    </button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </>
      ) : null}
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\editor\page.tsx" $editor

$compress = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { ToolShell } from "@/components/pdf/Shared";

async function renderPageToJpeg(
  bytes: ArrayBuffer,
  pageNumber: number,
  scale: number,
  quality: number
) {
  const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
  const pdf = await pdfjs.getDocument({ data: bytes.slice(0) }).promise;
  const page = await pdf.getPage(pageNumber + 1);
  const viewport = page.getViewport({ scale });

  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("Canvas is unavailable");

  canvas.width = Math.max(1, Math.floor(viewport.width));
  canvas.height = Math.max(1, Math.floor(viewport.height));

  await page.render({ canvasContext: context, viewport }).promise;

  const blob = await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (value) => (value ? resolve(value) : reject(new Error("Image conversion failed"))),
      "image/jpeg",
      quality
    );
  });

  return {
    bytes: await blob.arrayBuffer(),
    width: canvas.width,
    height: canvas.height
  };
}

function download(bytes: Uint8Array, filename: string) {
  const blob = new Blob([bytes as BlobPart], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

const modes = {
  light: { label: "Light", scale: 1.35, quality: 0.82 },
  medium: { label: "Medium", scale: 1.05, quality: 0.62 },
  maximum: { label: "Maximum", scale: 0.82, quality: 0.42 }
} as const;

type Mode = keyof typeof modes;

export default function CompressPdfPage() {
  const [file, setFile] = useState<File | null>(null);
  const [mode, setMode] = useState<Mode>("medium");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState("");

  async function run() {
    if (!file) return;
    setBusy(true);
    setResult("");

    try {
      const input = await file.arrayBuffer();
      const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
      const source = await pdfjs.getDocument({ data: input.slice(0) }).promise;

      const output = await PDFDocument.create();
      const setting = modes[mode];

      for (let pageIndex = 0; pageIndex < source.numPages; pageIndex += 1) {
        const rendered = await renderPageToJpeg(
          input,
          pageIndex,
          setting.scale,
          setting.quality
        );

        const image = await output.embedJpg(rendered.bytes);
        const page = output.addPage([rendered.width, rendered.height]);

        page.drawImage(image, {
          x: 0,
          y: 0,
          width: rendered.width,
          height: rendered.height
        });
      }

      const bytes = await output.save({ useObjectStreams: true });

      const before = file.size;
      const after = bytes.length;
      const reduction = before > 0 ? Math.max(0, (1 - after / before) * 100) : 0;

      setResult(
        `Original ${(before / 1048576).toFixed(2)} MB -> ${(after / 1048576).toFixed(2)} MB (${reduction.toFixed(1)}% smaller)`
      );

      download(bytes, `compressed-${mode}.pdf`);
    } catch (error) {
      console.error(error);
      alert("Compression failed for this PDF.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ToolShell
      title="Compress PDF"
      description="Choose the compression strength. Maximum compression makes image-heavy PDFs much smaller, but image quality will be reduced."
    >
      <input
        type="file"
        accept="application/pdf"
        onChange={(event) => setFile(event.target.files?.[0] || null)}
        className="block w-full rounded-lg border border-slate-300 p-3"
      />

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
            <span className="mt-1 block text-xs text-slate-600">
              {key === "light"
                ? "Better quality"
                : key === "medium"
                ? "Balanced"
                : "Smallest file"}
            </span>
          </button>
        ))}
      </div>

      <button
        type="button"
        onClick={run}
        disabled={!file || busy}
        className="mt-5 w-full rounded-lg bg-navy-950 p-4 font-black text-white disabled:opacity-50"
      >
        {busy ? "Compressing pages..." : `Compress - ${modes[mode].label}`}
      </button>

      {result ? (
        <div className="mt-5 rounded-lg bg-green-50 p-4 font-bold text-green-800">
          {result}
        </div>
      ) : null}

      <p className="mt-4 text-sm leading-6 text-slate-500">
        Maximum mode converts pages to compressed images. This is strong compression,
        but searchable/selectable text becomes part of the page image.
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
  Stamp
} from "lucide-react";
import { PageHeader } from "@/components/PageHeader";

const tools = [
  ["Visual PDF Editor", Combine, "/pdf-tools/editor", "Merge, add, delete, reorder, rotate, split and extract"],
  ["Compress", Minimize2, "/pdf-tools/compress", "Light, medium and maximum compression"],
  ["Annotate", Pencil, "/pdf-tools/annotate", "Add a note"],
  ["PDF <-> Word", FileText, "/pdf-tools/pdf-word", "Needs conversion API"],
  ["PDF <-> Image", Image, "/pdf-tools/pdf-image", "Images to PDF"],
  ["Translate", Languages, "/pdf-tools/translate", "Needs API setup"],
  ["PDF OCR", ScanText, "/pdf-tools/ocr", "Needs OCR setup"],
  ["Sign", Signature, "/pdf-tools/sign", "Add signature image"],
  ["PDF Converter", RefreshCcw, "/pdf-tools/converter", "Conversion center"],
  ["Crop", Crop, "/pdf-tools/crop", "Crop all pages"],
  ["Protect", ShieldCheck, "/pdf-tools/protect", "Needs encryption API"],
  ["Chat with PDF", MessageSquareText, "/pdf-tools/chat", "Needs AI API"],
  ["Number Pages", ListOrdered, "/pdf-tools/number-pages", "Add page numbering"],
  ["Watermark", Stamp, "/pdf-tools/watermark", "Add watermark"],
  ["AI PDF Assistant", Bot, "/pdf-tools/ai-assistant", "Needs AI API"]
] as const;

export default function PdfToolsPage() {
  return (
    <>
      <PageHeader
        eyebrow="Document Center"
        title="PDF Tools"
        description="Edit, merge, compress, sign, convert, and organize PDF documents."
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
                  <Icon className="size-5" />
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

$redirect = @'
import { redirect } from "next/navigation";

export default function Page() {
  redirect("/pdf-tools/editor");
}
'@

WriteFile "app\pdf-tools\merge\page.tsx" $redirect
WriteFile "app\pdf-tools\split\page.tsx" $redirect
WriteFile "app\pdf-tools\delete-pages\page.tsx" $redirect
WriteFile "app\pdf-tools\extract-pages\page.tsx" $redirect
WriteFile "app\pdf-tools\rotate\page.tsx" $redirect

Write-Host "Running production build check..." -ForegroundColor Cyan
npm run build

if ($LASTEXITCODE -ne 0) {
  Write-Host "Build failed. Send the error to ChatGPT." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "SUCCESS: Visual PDF Editor and real compression installed." -ForegroundColor Green
Write-Host "Run: npm run dev -- -p 3001" -ForegroundColor Yellow
