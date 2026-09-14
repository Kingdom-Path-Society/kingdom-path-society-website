param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

function WriteFile {
  param(
    [string]$Path,
    [string]$Content
  )
  $full = Join-Path $ProjectRoot $Path
  $dir = Split-Path $full -Parent
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  [System.IO.File]::WriteAllText($full, $Content, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Updated $Path" -ForegroundColor Green
}

Write-Host "Installing PDF dependency..." -ForegroundColor Cyan
npm install pdf-lib
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

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

export function parsePages(value: string, max: number) {
  const pages = new Set<number>();

  for (const item of value.split(",").map((v) => v.trim()).filter(Boolean)) {
    if (item.includes("-")) {
      const [startRaw, endRaw] = item.split("-");
      const start = Number(startRaw);
      const end = Number(endRaw);

      if (Number.isFinite(start) && Number.isFinite(end)) {
        for (let page = Math.min(start, end); page <= Math.max(start, end); page += 1) {
          if (page >= 1 && page <= max) pages.add(page - 1);
        }
      }
    } else {
      const page = Number(item);
      if (Number.isFinite(page) && page >= 1 && page <= max) pages.add(page - 1);
    }
  }

  return Array.from(pages).sort((a, b) => a - b);
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
      <div className="container-page max-w-4xl">
        <p className="eyebrow">PDF Tools</p>
        <h1 className="mt-3 text-4xl font-black text-navy-950">{title}</h1>
        <p className="mt-4 text-lg leading-8 text-slate-700">{description}</p>
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
WriteFile "components\pdf\Shared.tsx" $shared

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
  Stamp,
  Trash2
} from "lucide-react";
import { PageHeader } from "@/components/PageHeader";

const tools = [
  ["Merge", Combine, "/pdf-tools/merge", "Ready to use"],
  ["Compress", Minimize2, "/pdf-tools/compress", "Ready to use"],
  ["Annotate", Pencil, "/pdf-tools/annotate", "Ready to use"],
  ["Split", Scissors, "/pdf-tools/split", "Ready to use"],
  ["PDF <-> Word", FileText, "/pdf-tools/pdf-word", "Needs conversion API"],
  ["PDF <-> Image", Image, "/pdf-tools/pdf-image", "Ready to use"],
  ["Translate", Languages, "/pdf-tools/translate", "Needs API setup"],
  ["PDF OCR", ScanText, "/pdf-tools/ocr", "Needs OCR setup"],
  ["Sign", Signature, "/pdf-tools/sign", "Ready to use"],
  ["PDF Converter", RefreshCcw, "/pdf-tools/converter", "Ready to use"],
  ["Delete Pages", Trash2, "/pdf-tools/delete-pages", "Ready to use"],
  ["Rotate", RotateCw, "/pdf-tools/rotate", "Ready to use"],
  ["Crop", Crop, "/pdf-tools/crop", "Ready to use"],
  ["Extract Pages", Files, "/pdf-tools/extract-pages", "Ready to use"],
  ["Protect", ShieldCheck, "/pdf-tools/protect", "Needs encryption API"],
  ["Chat with PDF", MessageSquareText, "/pdf-tools/chat", "Needs AI API"],
  ["Number Pages", ListOrdered, "/pdf-tools/number-pages", "Ready to use"],
  ["Watermark", Stamp, "/pdf-tools/watermark", "Ready to use"],
  ["AI PDF Assistant", Bot, "/pdf-tools/ai-assistant", "Needs AI API"]
] as const;

export default function PdfToolsPage() {
  return (
    <>
      <PageHeader eyebrow="Document Center" title="PDF Tools" />
      <section className="section-y bg-slate-50">
        <div className="container-page">
          <p className="mb-8 max-w-3xl text-lg leading-8 text-slate-700">
            Merge, compress, split, rotate, sign, convert, and organize PDF documents.
          </p>

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {tools.map(([name, Icon, href, status]) => (
              <Link
                key={name}
                href={href}
                className="group flex min-h-24 items-center gap-4 rounded-lg border border-slate-200 bg-white px-5 py-4 shadow-sm transition hover:-translate-y-0.5 hover:border-gold-400 hover:shadow-md"
              >
                <span className="grid size-11 shrink-0 place-items-center rounded-md bg-navy-950 text-white">
                  <Icon className="size-5" aria-hidden="true" />
                </span>
                <div>
                  <h2 className="font-black text-navy-950">{name}</h2>
                  <p className="mt-1 text-xs font-semibold text-slate-500">{status}</p>
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

$merge = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [files, setFiles] = useState<File[]>([]);
  const [busy, setBusy] = useState(false);

  async function run() {
    if (files.length < 2) {
      alert("Choose at least 2 PDF files.");
      return;
    }

    setBusy(true);

    try {
      const output = await PDFDocument.create();

      for (const file of files) {
        const source = await PDFDocument.load(await file.arrayBuffer());
        const copied = await output.copyPages(source, source.getPageIndices());
        copied.forEach((page) => output.addPage(page));
      }

      downloadPdf(await output.save(), "merged-document.pdf");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ToolShell title="Merge PDF" description="Combine two or more PDF files into one document.">
      <input
        type="file"
        accept="application/pdf"
        multiple
        onChange={(event) => setFiles(Array.from(event.target.files || []))}
        className="block w-full rounded-lg border border-slate-300 p-3"
      />

      <div className="mt-4 space-y-2">
        {files.map((file, index) => (
          <div key={`${file.name}-${index}`} className="rounded border p-3">
            {index + 1}. {file.name}
          </div>
        ))}
      </div>

      <button
        type="button"
        onClick={run}
        disabled={busy || files.length < 2}
        className="mt-6 w-full rounded-lg bg-navy-950 px-5 py-4 font-black text-white disabled:opacity-50"
      >
        {busy ? "Merging..." : "Merge and Download"}
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\merge\page.tsx" $merge

$compress = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState("");

  async function run() {
    if (!file) return;

    const doc = await PDFDocument.load(await file.arrayBuffer(), {
      updateMetadata: false
    });

    const bytes = await doc.save({
      useObjectStreams: true,
      addDefaultPage: false
    });

    setResult(
      `Original ${(file.size / 1048576).toFixed(2)} MB -> ${(bytes.length / 1048576).toFixed(2)} MB`
    );

    downloadPdf(bytes, "compressed.pdf");
  }

  return (
    <ToolShell
      title="Compress PDF"
      description="Optimize the PDF structure. Very strong image compression needs a server-side compression engine."
    >
      <PdfPicker file={file} setFile={setFile} />
      <button
        type="button"
        onClick={run}
        className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white"
      >
        Compress and Download
      </button>
      {result ? <p className="mt-4 font-bold">{result}</p> : null}
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\compress\page.tsx" $compress

$split = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf, parsePages } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [pages, setPages] = useState("1");

  async function run() {
    if (!file) return;

    const source = await PDFDocument.load(await file.arrayBuffer());
    const indexes = parsePages(pages, source.getPageCount());

    if (!indexes.length) {
      alert("Enter pages like 1,3-5");
      return;
    }

    const output = await PDFDocument.create();
    const copied = await output.copyPages(source, indexes);
    copied.forEach((page) => output.addPage(page));
    downloadPdf(await output.save(), "split.pdf");
  }

  return (
    <ToolShell title="Split PDF" description="Create a new PDF from selected pages.">
      <PdfPicker file={file} setFile={setFile} />
      <input
        value={pages}
        onChange={(event) => setPages(event.target.value)}
        placeholder="1,3-5"
        className="mt-4 w-full rounded border p-3"
      />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Create PDF
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\split\page.tsx" $split

$extract = $split.Replace('title="Split PDF"', 'title="Extract Pages"').Replace(
  'description="Create a new PDF from selected pages."',
  'description="Extract selected pages into a new PDF."'
).Replace('"split.pdf"', '"extracted-pages.pdf"').Replace('Create PDF', 'Extract and Download')
WriteFile "app\pdf-tools\extract-pages\page.tsx" $extract

$deletePages = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf, parsePages } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [pages, setPages] = useState("");

  async function run() {
    if (!file) return;

    const source = await PDFDocument.load(await file.arrayBuffer());
    const remove = new Set(parsePages(pages, source.getPageCount()));
    const keep = source.getPageIndices().filter((index) => !remove.has(index));

    if (!keep.length) {
      alert("You cannot delete all pages.");
      return;
    }

    const output = await PDFDocument.create();
    const copied = await output.copyPages(source, keep);
    copied.forEach((page) => output.addPage(page));
    downloadPdf(await output.save(), "pages-deleted.pdf");
  }

  return (
    <ToolShell title="Delete Pages" description="Remove selected pages from a PDF.">
      <PdfPicker file={file} setFile={setFile} />
      <input
        value={pages}
        onChange={(event) => setPages(event.target.value)}
        placeholder="2,4-6"
        className="mt-4 w-full rounded border p-3"
      />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Delete Pages
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\delete-pages\page.tsx" $deletePages

$rotate = @'
"use client";

import { useState } from "react";
import { PDFDocument, degrees } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [angle, setAngle] = useState("90");

  async function run() {
    if (!file) return;

    const doc = await PDFDocument.load(await file.arrayBuffer());

    doc.getPages().forEach((page) => {
      page.setRotation(degrees((page.getRotation().angle + Number(angle)) % 360));
    });

    downloadPdf(await doc.save(), "rotated.pdf");
  }

  return (
    <ToolShell title="Rotate PDF" description="Rotate all pages in a PDF.">
      <PdfPicker file={file} setFile={setFile} />
      <select
        value={angle}
        onChange={(event) => setAngle(event.target.value)}
        className="mt-4 w-full rounded border p-3"
      >
        <option value="90">90 degrees</option>
        <option value="180">180 degrees</option>
        <option value="270">270 degrees</option>
      </select>
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Rotate and Download
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\rotate\page.tsx" $rotate

$watermark = @'
"use client";

import { useState } from "react";
import { PDFDocument, StandardFonts, degrees, rgb } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [text, setText] = useState("KINGDOM PATH SOCIETY");

  async function run() {
    if (!file) return;

    const doc = await PDFDocument.load(await file.arrayBuffer());
    const font = await doc.embedFont(StandardFonts.HelveticaBold);

    for (const page of doc.getPages()) {
      const { width, height } = page.getSize();
      page.drawText(text, {
        x: width * 0.12,
        y: height * 0.45,
        size: 32,
        font,
        color: rgb(0.65, 0.65, 0.65),
        rotate: degrees(35),
        opacity: 0.35
      });
    }

    downloadPdf(await doc.save(), "watermarked.pdf");
  }

  return (
    <ToolShell title="Watermark PDF" description="Add a text watermark to every page.">
      <PdfPicker file={file} setFile={setFile} />
      <input value={text} onChange={(event) => setText(event.target.value)} className="mt-4 w-full rounded border p-3" />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Add Watermark
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\watermark\page.tsx" $watermark

$numberPages = @'
"use client";

import { useState } from "react";
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);

  async function run() {
    if (!file) return;

    const doc = await PDFDocument.load(await file.arrayBuffer());
    const font = await doc.embedFont(StandardFonts.Helvetica);

    doc.getPages().forEach((page, index) => {
      const { width } = page.getSize();
      page.drawText(`${index + 1} / ${doc.getPageCount()}`, {
        x: width / 2 - 15,
        y: 18,
        size: 10,
        font,
        color: rgb(0.2, 0.2, 0.2)
      });
    });

    downloadPdf(await doc.save(), "numbered.pdf");
  }

  return (
    <ToolShell title="Number Pages" description="Add page numbers to every page.">
      <PdfPicker file={file} setFile={setFile} />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Number Pages
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\number-pages\page.tsx" $numberPages

$crop = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [margin, setMargin] = useState("18");

  async function run() {
    if (!file) return;

    const doc = await PDFDocument.load(await file.arrayBuffer());

    for (const page of doc.getPages()) {
      const { width, height } = page.getSize();
      const value = Math.max(0, Number(margin) || 0);
      const safe = Math.min(value, width / 4, height / 4);
      page.setCropBox(safe, safe, width - safe * 2, height - safe * 2);
    }

    downloadPdf(await doc.save(), "cropped.pdf");
  }

  return (
    <ToolShell title="Crop PDF" description="Crop the same margin from every page.">
      <PdfPicker file={file} setFile={setFile} />
      <input type="number" value={margin} onChange={(event) => setMargin(event.target.value)} className="mt-4 w-full rounded border p-3" />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Crop and Download
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\crop\page.tsx" $crop

$annotate = @'
"use client";

import { useState } from "react";
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [text, setText] = useState("Note");

  async function run() {
    if (!file) return;

    const doc = await PDFDocument.load(await file.arrayBuffer());
    const font = await doc.embedFont(StandardFonts.HelveticaBold);
    const page = doc.getPage(0);
    const { height } = page.getSize();

    page.drawRectangle({
      x: 36,
      y: height - 90,
      width: 280,
      height: 48,
      color: rgb(1, 1, 0.75)
    });

    page.drawText(text, {
      x: 48,
      y: height - 64,
      size: 14,
      font,
      color: rgb(0.1, 0.1, 0.1)
    });

    downloadPdf(await doc.save(), "annotated.pdf");
  }

  return (
    <ToolShell title="Annotate PDF" description="Add a simple note to the first page.">
      <PdfPicker file={file} setFile={setFile} />
      <input value={text} onChange={(event) => setText(event.target.value)} className="mt-4 w-full rounded border p-3" />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Add Note
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\annotate\page.tsx" $annotate

$sign = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { PdfPicker, ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [file, setFile] = useState<File | null>(null);
  const [signature, setSignature] = useState<File | null>(null);

  async function run() {
    if (!file || !signature) {
      alert("Choose a PDF and a PNG or JPG signature image.");
      return;
    }

    const doc = await PDFDocument.load(await file.arrayBuffer());
    const signatureBytes = await signature.arrayBuffer();

    const image = signature.type.includes("png")
      ? await doc.embedPng(signatureBytes)
      : await doc.embedJpg(signatureBytes);

    const page = doc.getPage(doc.getPageCount() - 1);
    const { width } = page.getSize();
    const scale = Math.min(160 / image.width, 70 / image.height, 1);

    page.drawImage(image, {
      x: width - 190,
      y: 45,
      width: image.width * scale,
      height: image.height * scale
    });

    downloadPdf(await doc.save(), "signed.pdf");
  }

  return (
    <ToolShell title="Sign PDF" description="Place a signature image on the last page.">
      <PdfPicker file={file} setFile={setFile} />
      <input
        type="file"
        accept="image/png,image/jpeg"
        onChange={(event) => setSignature(event.target.files?.[0] || null)}
        className="mt-4 block w-full rounded border p-3"
      />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Sign and Download
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\sign\page.tsx" $sign

$pdfImage = @'
"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { ToolShell, downloadPdf } from "@/components/pdf/Shared";

export default function Page() {
  const [files, setFiles] = useState<File[]>([]);

  async function run() {
    if (!files.length) return;

    const doc = await PDFDocument.create();

    for (const file of files) {
      const bytes = await file.arrayBuffer();
      const image = file.type.includes("png")
        ? await doc.embedPng(bytes)
        : await doc.embedJpg(bytes);

      const page = doc.addPage([image.width, image.height]);
      page.drawImage(image, {
        x: 0,
        y: 0,
        width: image.width,
        height: image.height
      });
    }

    downloadPdf(await doc.save(), "images-to-pdf.pdf");
  }

  return (
    <ToolShell title="PDF <-> Image" description="This version converts JPG and PNG images into a PDF.">
      <input
        type="file"
        multiple
        accept="image/png,image/jpeg"
        onChange={(event) => setFiles(Array.from(event.target.files || []))}
        className="block w-full rounded border p-3"
      />
      <button type="button" onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">
        Images to PDF
      </button>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\pdf-image\page.tsx" $pdfImage

$converter = @'
import Link from "next/link";
import { ToolShell } from "@/components/pdf/Shared";

export default function Page() {
  return (
    <ToolShell title="PDF Converter" description="Choose a conversion tool.">
      <div className="grid gap-4 sm:grid-cols-2">
        <Link className="rounded border p-5 font-black" href="/pdf-tools/pdf-image">
          Images to PDF
        </Link>
        <Link className="rounded border p-5 font-black" href="/pdf-tools/pdf-word">
          PDF to Word
        </Link>
      </div>
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\converter\page.tsx" $converter

$apiTemplate = @'
import { ToolShell } from "@/components/pdf/Shared";

export default function Page() {
  return (
    <ToolShell title="__TITLE__" description="__DESC__">
      <div className="rounded-lg border border-amber-200 bg-amber-50 p-5 text-amber-900">
        This tool needs a secure server or API integration before public use.
        No secret API key should be placed in browser code.
      </div>
    </ToolShell>
  );
}
'@

$items = @{
  "pdf-word" = @("PDF <-> Word", "High quality Word conversion needs a document conversion service.")
  "translate" = @("Translate PDF", "Translation needs a translation or AI API.")
  "ocr" = @("PDF OCR", "Reliable scanned PDF OCR needs an OCR service or additional rendering setup.")
  "protect" = @("Protect PDF", "Password encryption needs a server-side PDF encryption engine.")
  "chat" = @("Chat with PDF", "PDF chat needs a secure AI API.")
  "ai-assistant" = @("AI PDF Assistant", "AI document analysis needs a secure AI API.")
}

foreach ($key in $items.Keys) {
  $title = $items[$key][0]
  $desc = $items[$key][1]
  $content = $apiTemplate.Replace("__TITLE__", $title).Replace("__DESC__", $desc)
  WriteFile "app\pdf-tools\$key\page.tsx" $content
}

Write-Host "Running production build check..." -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) {
  Write-Host "Build failed. Do not push yet. Send the error to ChatGPT." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "SUCCESS: PDF tools were installed and the production build passed." -ForegroundColor Green
Write-Host "Next: npm run dev -- -p 3001" -ForegroundColor Yellow
