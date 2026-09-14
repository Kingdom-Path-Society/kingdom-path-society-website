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
  ["Image to PDF", Image, "/pdf-tools/pdf-image", "Convert JPG and PNG images to PDF"],
  ["PDF Converter", RefreshCcw, "/pdf-tools/converter", "Conversion center"],
  ["PDF to Word", FileText, "/pdf-tools/pdf-word", "Convert selectable PDF text to Word"],
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