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