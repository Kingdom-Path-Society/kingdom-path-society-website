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