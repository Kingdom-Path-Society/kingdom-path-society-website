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