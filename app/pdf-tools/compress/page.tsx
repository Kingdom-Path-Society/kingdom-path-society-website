"use client";

import { useState } from "react";
import { PDFDocument } from "pdf-lib";
import { ToolShell } from "@/components/pdf/Shared";
import { loadPdfJs } from "@/lib/pdfjsClient";

type Mode = "light" | "medium" | "maximum";

const modes: Record<
  Mode,
  { label: string; scale: number; quality: number; description: string }
> = {
  light: {
    label: "Light",
    scale: 1.0,
    quality: 0.72,
    description: "Better visual quality"
  },
  medium: {
    label: "Medium",
    scale: 0.78,
    quality: 0.5,
    description: "Balanced compression"
  },
  maximum: {
    label: "Maximum",
    scale: 0.58,
    quality: 0.3,
    description: "Smallest file"
  }
};

function download(bytes: Uint8Array, filename: string) {
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

export default function CompressPdfPage() {
  const [file, setFile] = useState<File | null>(null);
  const [mode, setMode] = useState<Mode>("medium");
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState("");
  const [result, setResult] = useState("");

  async function compress() {
    if (!file) return;

    setBusy(true);
    setResult("");

    try {
      const input = await file.arrayBuffer();
      const pdfjs = await loadPdfJs();
      const source = await pdfjs.getDocument({ data: input.slice(0) }).promise;
      const output = await PDFDocument.create();
      const setting = modes[mode];

      for (let pageIndex = 0; pageIndex < source.numPages; pageIndex += 1) {
        setProgress(`Compressing page ${pageIndex + 1} of ${source.numPages}...`);

        const sourcePage = await source.getPage(pageIndex + 1);
        const baseViewport = sourcePage.getViewport({ scale: 1 });
        const renderViewport = sourcePage.getViewport({ scale: setting.scale });

        const canvas = document.createElement("canvas");
        const context = canvas.getContext("2d");
        if (!context) throw new Error("Canvas unavailable");

        canvas.width = Math.max(1, Math.floor(renderViewport.width));
        canvas.height = Math.max(1, Math.floor(renderViewport.height));

        await sourcePage.render({
          canvas,
          canvasContext: context,
          viewport: renderViewport
        }).promise;

        const imageBlob = await new Promise<Blob>((resolve, reject) => {
          canvas.toBlob(
            (blob) => (blob ? resolve(blob) : reject(new Error("JPEG conversion failed"))),
            "image/jpeg",
            setting.quality
          );
        });

        const image = await output.embedJpg(await imageBlob.arrayBuffer());
        const page = output.addPage([baseViewport.width, baseViewport.height]);

        page.drawImage(image, {
          x: 0,
          y: 0,
          width: baseViewport.width,
          height: baseViewport.height
        });
      }

      setProgress("Finalizing compressed PDF...");
      const bytes = await output.save({ useObjectStreams: true });

      const before = file.size;
      const after = bytes.length;
      const percent = before > 0 ? (1 - after / before) * 100 : 0;

      if (after >= before) {
        setResult(
          `This PDF is already efficiently compressed. Generated size ${(after / 1048576).toFixed(2)} MB versus original ${(before / 1048576).toFixed(2)} MB. Try Maximum for a smaller result.`
        );
      } else {
        setResult(
          `Original ${(before / 1048576).toFixed(2)} MB -> ${(after / 1048576).toFixed(2)} MB (${percent.toFixed(1)}% smaller)`
        );
      }

      download(bytes, `compressed-${mode}.pdf`);
      setProgress("");
    } catch (error) {
      console.error(error);
      setProgress("");
      alert("Compression could not complete for this PDF.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ToolShell
      title="Compress PDF"
      description="Compress image-heavy and scanned PDFs. Maximum gives the smallest file and lowers image quality the most."
    >
      <input
        type="file"
        accept="application/pdf"
        onChange={(event) => setFile(event.target.files?.[0] || null)}
        className="block w-full rounded-lg border border-slate-300 p-3"
      />

      {file ? (
        <div className="mt-4 rounded-lg bg-slate-50 p-4">
          <p className="font-black text-navy-950">{file.name}</p>
          <p className="mt-1 text-sm font-semibold text-slate-600">
            Original size: {(file.size / 1048576).toFixed(2)} MB
          </p>
        </div>
      ) : null}

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
            <span className="mt-1 block text-xs font-semibold text-slate-600">
              {modes[key].description}
            </span>
          </button>
        ))}
      </div>

      <button
        type="button"
        onClick={compress}
        disabled={!file || busy}
        className="mt-5 w-full rounded-lg bg-navy-950 p-4 font-black text-white disabled:opacity-50"
      >
        {busy ? "Compressing..." : `Compress - ${modes[mode].label}`}
      </button>

      {progress ? (
        <p className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">
          {progress}
        </p>
      ) : null}

      {result ? (
        <div className="mt-4 rounded-lg border border-green-200 bg-green-50 p-4 font-bold text-green-800">
          {result}
        </div>
      ) : null}

      <p className="mt-4 text-sm leading-6 text-amber-800">
        Strong compression rasterizes each page. The document remains visually readable,
        but selectable/searchable text becomes part of the page image.
      </p>
    </ToolShell>
  );
}