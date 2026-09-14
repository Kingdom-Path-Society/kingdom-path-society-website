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