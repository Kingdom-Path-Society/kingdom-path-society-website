param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

Write-Host "Installing dependencies..." -ForegroundColor Cyan
npm install pdf-lib

Write-Host "Creating PDF tools..." -ForegroundColor Cyan

function WriteFile([string]$Path,[string]$Content) {
  $full = Join-Path $ProjectRoot $Path
  New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
  [IO.File]::WriteAllText($full,$Content,[Text.UTF8Encoding]::new($false))
}

$hub = @'
import Link from "next/link";
import { Bot, Combine, Crop, FileText, Files, Image, Languages, ListOrdered, MessageSquareText, Minimize2, Pencil, RefreshCcw, RotateCw, ScanText, Scissors, ShieldCheck, Signature, Stamp, Trash2 } from "lucide-react";
import { PageHeader } from "@/components/PageHeader";

const tools = [
  ["Merge", Combine, "/pdf-tools/merge", "Ready to use"],
  ["Compress", Minimize2, "/pdf-tools/compress", "Ready to use"],
  ["Annotate", Pencil, "/pdf-tools/annotate", "Ready to use"],
  ["Split", Scissors, "/pdf-tools/split", "Ready to use"],
  ["PDF ↔ Word", FileText, "/pdf-tools/pdf-word", "Needs conversion API"],
  ["PDF ↔ Image", Image, "/pdf-tools/pdf-image", "Ready to use"],
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
            Merge, compress, split, rotate, sign and organize PDF documents.
          </p>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {tools.map(([name, Icon, href, status]) => (
              <Link key={name} href={href} className="group flex min-h-24 items-center gap-4 rounded-lg border border-slate-200 bg-white px-5 py-4 shadow-sm transition hover:-translate-y-0.5 hover:border-gold-400 hover:shadow-md">
                <span className="grid size-11 shrink-0 place-items-center rounded-md bg-navy-950 text-white"><Icon className="size-5" /></span>
                <div><h2 className="font-black text-navy-950">{name}</h2><p className="mt-1 text-xs font-semibold text-slate-500">{status}</p></div>
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

$shared = @'
"use client";
import { PDFDocument, StandardFonts, rgb, degrees } from "pdf-lib";

export function downloadPdf(bytes: Uint8Array, name: string) {
  const blob = new Blob([bytes as BlobPart], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = name; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function pagesFromText(text: string, max: number) {
  const out = new Set<number>();
  for (const part of text.split(",").map(v => v.trim()).filter(Boolean)) {
    if (part.includes("-")) {
      const [a,b] = part.split("-").map(Number);
      for (let n=Math.min(a,b); n<=Math.max(a,b); n++) if(n>=1&&n<=max) out.add(n-1);
    } else {
      const n=Number(part); if(n>=1&&n<=max) out.add(n-1);
    }
  }
  return [...out].sort((a,b)=>a-b);
}

export function Shell({title,description,children}:{title:string;description:string;children:React.ReactNode}) {
 return <main className="min-h-screen bg-slate-50 py-12"><div className="container-page max-w-4xl">
  <p className="eyebrow">PDF Tools</p><h1 className="mt-3 text-4xl font-black text-navy-950">{title}</h1>
  <p className="mt-4 text-lg leading-8 text-slate-700">{description}</p>
  <div className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">{children}</div>
 </div></main>
}

export function Picker({file,setFile}:{file:File|null;setFile:(f:File|null)=>void}) {
 return <label className="block cursor-pointer rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 p-8 text-center hover:border-gold-400">
  <span className="font-black text-navy-950">{file ? file.name : "Choose PDF file"}</span>
  <input type="file" accept="application/pdf" className="hidden" onChange={e=>setFile(e.target.files?.[0]||null)} />
 </label>
}
'@
WriteFile "components\pdf\Shared.tsx" $shared

$generic = @'
"use client";
import { useState } from "react";
import { PDFDocument, StandardFonts, rgb, degrees } from "pdf-lib";
import { Shell, Picker, downloadPdf, pagesFromText } from "@/components/pdf/Shared";

export default function Page(){
 const [file,setFile]=useState<File|null>(null);
 const [value,setValue]=useState("__DEFAULT__");
 async function run(){
  if(!file) return;
  const doc=await PDFDocument.load(await file.arrayBuffer());
  __ACTION__
  downloadPdf(await doc.save(),"__OUT__");
 }
 return <Shell title="__TITLE__" description="__DESC__"><Picker file={file} setFile={setFile}/>
  __CONTROL__
  <button onClick={run} className="mt-4 w-full rounded-lg bg-navy-950 px-5 py-4 font-black text-white">__BUTTON__</button>
 </Shell>
}
'@

$rotate = $generic.Replace("__TITLE__","Rotate PDF").Replace("__DESC__","Rotate all pages in a PDF.").Replace("__DEFAULT__","90").Replace("__ACTION__",'doc.getPages().forEach(p=>p.setRotation(degrees((p.getRotation().angle+Number(value))%360)));').Replace("__OUT__","rotated.pdf").Replace("__CONTROL__",' <select value={value} onChange={e=>setValue(e.target.value)} className="mt-4 w-full rounded border p-3"><option value="90">90°</option><option value="180">180°</option><option value="270">270°</option></select>').Replace("__BUTTON__","Rotate & Download")
WriteFile "app\pdf-tools\rotate\page.tsx" $rotate

$water = $generic.Replace("__TITLE__","Watermark PDF").Replace("__DESC__","Add a text watermark to every page.").Replace("__DEFAULT__","KINGDOM PATH SOCIETY").Replace("__ACTION__",'const font=await doc.embedFont(StandardFonts.HelveticaBold); for(const p of doc.getPages()){const {width,height}=p.getSize();p.drawText(value,{x:width*.12,y:height*.45,size:32,font,color:rgb(.65,.65,.65),rotate:degrees(35),opacity:.35});}').Replace("__OUT__","watermarked.pdf").Replace("__CONTROL__",' <input value={value} onChange={e=>setValue(e.target.value)} className="mt-4 w-full rounded border p-3"/>').Replace("__BUTTON__","Add Watermark")
WriteFile "app\pdf-tools\watermark\page.tsx" $water

$number = $generic.Replace("__TITLE__","Number Pages").Replace("__DESC__","Add page numbers to each page.").Replace("__DEFAULT__","").Replace("__ACTION__",'const font=await doc.embedFont(StandardFonts.Helvetica);doc.getPages().forEach((p,i)=>{const {width}=p.getSize();p.drawText(`${i+1} / ${doc.getPageCount()}`,{x:width/2-15,y:18,size:10,font,color:rgb(.2,.2,.2)});});').Replace("__OUT__","numbered.pdf").Replace("__CONTROL__","").Replace("__BUTTON__","Number Pages")
WriteFile "app\pdf-tools\number-pages\page.tsx" $number

$crop = $generic.Replace("__TITLE__","Crop PDF").Replace("__DESC__","Crop the same margin from every page.").Replace("__DEFAULT__","18").Replace("__ACTION__",'for(const p of doc.getPages()){const {width,height}=p.getSize();const m=Number(value)||0;p.setCropBox(m,m,width-2*m,height-2*m);}').Replace("__OUT__","cropped.pdf").Replace("__CONTROL__",' <input type="number" value={value} onChange={e=>setValue(e.target.value)} className="mt-4 w-full rounded border p-3"/>').Replace("__BUTTON__","Crop & Download")
WriteFile "app\pdf-tools\crop\page.tsx" $crop

$annotate = $generic.Replace("__TITLE__","Annotate PDF").Replace("__DESC__","Add a simple note to the first page.").Replace("__DEFAULT__","Note").Replace("__ACTION__",'const font=await doc.embedFont(StandardFonts.HelveticaBold);const p=doc.getPage(0);const {height}=p.getSize();p.drawRectangle({x:36,y:height-90,width:280,height:48,color:rgb(1,1,.75)});p.drawText(value,{x:48,y:height-64,size:14,font,color:rgb(.1,.1,.1)});').Replace("__OUT__","annotated.pdf").Replace("__CONTROL__",' <input value={value} onChange={e=>setValue(e.target.value)} className="mt-4 w-full rounded border p-3"/>').Replace("__BUTTON__","Add Note")
WriteFile "app\pdf-tools\annotate\page.tsx" $annotate

$compress = $generic.Replace("__TITLE__","Compress PDF").Replace("__DESC__","Optimize PDF object streams. Image-heavy maximum compression requires a stronger server-side engine.").Replace("__DEFAULT__","").Replace("__ACTION__","").Replace("__OUT__","compressed.pdf").Replace("__CONTROL__","").Replace("__BUTTON__","Compress & Download")
WriteFile "app\pdf-tools\compress\page.tsx" $compress

$split = @'
"use client";
import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { Shell, Picker, downloadPdf, pagesFromText } from "@/components/pdf/Shared";
export default function Page(){
 const [file,setFile]=useState<File|null>(null); const [range,setRange]=useState("1");
 async function run(){if(!file)return;const src=await PDFDocument.load(await file.arrayBuffer());const ids=pagesFromText(range,src.getPageCount());if(!ids.length)return alert("Use pages like 1,3-5");const out=await PDFDocument.create();(await out.copyPages(src,ids)).forEach(p=>out.addPage(p));downloadPdf(await out.save(),"split.pdf")}
 return <Shell title="Split PDF" description="Create a new PDF from selected pages."><Picker file={file} setFile={setFile}/><input value={range} onChange={e=>setRange(e.target.value)} placeholder="1,3-5" className="mt-4 w-full rounded border p-3"/><button onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">Create PDF</button></Shell>
}
'@
WriteFile "app\pdf-tools\split\page.tsx" $split
WriteFile "app\pdf-tools\extract-pages\page.tsx" ($split.Replace('title="Split PDF"','title="Extract Pages"').Replace('description="Create a new PDF from selected pages."','description="Extract selected pages into a new PDF."').Replace('"split.pdf"','"extracted-pages.pdf"').Replace(">Create PDF<",">Extract & Download<"))

$delete = @'
"use client";
import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { Shell, Picker, downloadPdf, pagesFromText } from "@/components/pdf/Shared";
export default function Page(){
 const [file,setFile]=useState<File|null>(null);const [range,setRange]=useState("");
 async function run(){if(!file)return;const src=await PDFDocument.load(await file.arrayBuffer());const del=new Set(pagesFromText(range,src.getPageCount()));const keep=src.getPageIndices().filter(i=>!del.has(i));if(!keep.length)return alert("Cannot delete all pages.");const out=await PDFDocument.create();(await out.copyPages(src,keep)).forEach(p=>out.addPage(p));downloadPdf(await out.save(),"pages-deleted.pdf")}
 return <Shell title="Delete Pages" description="Remove selected pages from a PDF."><Picker file={file} setFile={setFile}/><input value={range} onChange={e=>setRange(e.target.value)} placeholder="2,4-6" className="mt-4 w-full rounded border p-3"/><button onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">Delete Pages</button></Shell>
}
'@
WriteFile "app\pdf-tools\delete-pages\page.tsx" $delete

$sign = @'
"use client";
import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { Shell, Picker, downloadPdf } from "@/components/pdf/Shared";
export default function Page(){
 const [file,setFile]=useState<File|null>(null);const [sig,setSig]=useState<File|null>(null);
 async function run(){if(!file||!sig)return alert("Choose PDF and a PNG/JPG signature image.");const doc=await PDFDocument.load(await file.arrayBuffer());const b=await sig.arrayBuffer();const img=sig.type.includes("png")?await doc.embedPng(b):await doc.embedJpg(b);const p=doc.getPage(doc.getPageCount()-1);const {width}=p.getSize();const s=Math.min(160/img.width,70/img.height,1);p.drawImage(img,{x:width-190,y:45,width:img.width*s,height:img.height*s});downloadPdf(await doc.save(),"signed.pdf")}
 return <Shell title="Sign PDF" description="Place a signature image on the last page."><Picker file={file} setFile={setFile}/><input type="file" accept="image/png,image/jpeg" onChange={e=>setSig(e.target.files?.[0]||null)} className="mt-4 block w-full rounded border p-3"/><button onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">Sign & Download</button></Shell>
}
'@
WriteFile "app\pdf-tools\sign\page.tsx" $sign

$image = @'
"use client";
import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { Shell, downloadPdf } from "@/components/pdf/Shared";
export default function Page(){
 const [files,setFiles]=useState<File[]>([]);
 async function run(){if(!files.length)return;const doc=await PDFDocument.create();for(const f of files){const b=await f.arrayBuffer();const img=f.type.includes("png")?await doc.embedPng(b):await doc.embedJpg(b);const p=doc.addPage([img.width,img.height]);p.drawImage(img,{x:0,y:0,width:img.width,height:img.height});}downloadPdf(await doc.save(),"images-to-pdf.pdf")}
 return <Shell title="PDF ↔ Image" description="This version converts JPG/PNG images to PDF."><input type="file" multiple accept="image/png,image/jpeg" onChange={e=>setFiles(Array.from(e.target.files||[]))} className="block w-full rounded border p-3"/><button onClick={run} className="mt-4 w-full rounded bg-navy-950 p-4 font-black text-white">Images → PDF</button></Shell>
}
'@
WriteFile "app\pdf-tools\pdf-image\page.tsx" $image

$converter = @'
import Link from "next/link";
import { Shell } from "@/components/pdf/Shared";
export default function Page(){return <Shell title="PDF Converter" description="Choose a conversion tool."><div className="grid gap-4 sm:grid-cols-2"><Link className="rounded border p-5 font-black" href="/pdf-tools/pdf-image">Images → PDF</Link><Link className="rounded border p-5 font-black" href="/pdf-tools/pdf-word">PDF ↔ Word</Link></div></Shell>}
'@
WriteFile "app\pdf-tools\converter\page.tsx" $converter

$api = @'
import { Shell } from "@/components/pdf/Shared";
export default function Page(){return <Shell title="__TITLE__" description="__DESC__"><div className="rounded-lg border border-amber-200 bg-amber-50 p-5 text-amber-900">This tool needs a secure server/API integration before public use. No secret API key should be placed in browser code.</div></Shell>}
'@
@{
 "pdf-word"=@("PDF ↔ Word","High-quality Word conversion needs a document conversion service.");
 "translate"=@("Translate PDF","Translation needs a translation or AI API.");
 "ocr"=@("PDF OCR","Reliable scanned-PDF OCR needs an OCR service or additional rendering/OCR setup.");
 "protect"=@("Protect PDF","Password encryption needs a server-side PDF encryption engine.");
 "chat"=@("Chat with PDF","PDF chat needs a secure AI API.");
 "ai-assistant"=@("AI PDF Assistant","AI document analysis needs a secure AI API.")
}.GetEnumerator() | ForEach-Object {
 $c=$api.Replace("__TITLE__",$_.Value[0]).Replace("__DESC__",$_.Value[1])
 WriteFile ("app\pdf-tools\"+$_.Key+"\page.tsx") $c
}

Write-Host "Running build check..." -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -eq 0) {
  Write-Host "SUCCESS: core PDF tools installed and build passed." -ForegroundColor Green
} else {
  Write-Host "Build failed. Do not push yet; send the error to ChatGPT." -ForegroundColor Red
  exit 1
}
