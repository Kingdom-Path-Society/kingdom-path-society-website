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