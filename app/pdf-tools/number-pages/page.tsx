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