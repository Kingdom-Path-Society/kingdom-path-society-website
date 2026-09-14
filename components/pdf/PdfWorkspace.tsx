"use client";

import { useState } from "react";
import { PDFDocument, degrees } from "pdf-lib";
import {
  ArrowLeft,
  ArrowRight,
  Download,
  FilePlus2,
  Files,
  RotateCw,
  Scissors,
  Trash2,
  X
} from "lucide-react";
import { downloadPdf } from "@/components/pdf/Shared";
import { loadPdfJs } from "@/lib/pdfjsClient";

type SourceFile = {
  id: string;
  name: string;
  bytes: ArrayBuffer;
  pageCount: number;
};

type PageItem = {
  id: string;
  sourceId: string;
  sourcePageIndex: number;
  rotation: number;
  preview: string;
};

async function makePreview(
  bytes: ArrayBuffer,
  pageIndex: number,
  rotation: number
) {
  const pdfjs = await loadPdfJs();
  const pdf = await pdfjs.getDocument({ data: bytes.slice(0) }).promise;
  const page = await pdf.getPage(pageIndex + 1);
  const viewport = page.getViewport({ scale: 0.62, rotation });

  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("Canvas unavailable");

  canvas.width = Math.max(1, Math.floor(viewport.width));
  canvas.height = Math.max(1, Math.floor(viewport.height));

  await page.render({
    canvas,
    canvasContext: context,
    viewport
  }).promise;

  return canvas.toDataURL("image/jpeg", 0.82);
}

export function PdfWorkspace({
  title,
  description
}: {
  title: string;
  description: string;
}) {
  const [sources, setSources] = useState<SourceFile[]>([]);
  const [pages, setPages] = useState<PageItem[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  async function addFiles(fileList: FileList | null) {
    if (!fileList?.length) return;

    setBusy(true);
    setMessage("Opening PDF pages...");

    try {
      const sourceAdditions: SourceFile[] = [];
      const pageAdditions: PageItem[] = [];

      for (const file of Array.from(fileList)) {
        const bytes = await file.arrayBuffer();
        const doc = await PDFDocument.load(bytes);
        const sourceId = `${Date.now()}-${Math.random()}-${file.name}`;

        sourceAdditions.push({
          id: sourceId,
          name: file.name,
          bytes,
          pageCount: doc.getPageCount()
        });

        for (let pageIndex = 0; pageIndex < doc.getPageCount(); pageIndex += 1) {
          const preview = await makePreview(bytes, pageIndex, 0);
          pageAdditions.push({
            id: `${sourceId}-${pageIndex}-${Math.random()}`,
            sourceId,
            sourcePageIndex: pageIndex,
            rotation: 0,
            preview
          });
        }
      }

      setSources((current) => [...current, ...sourceAdditions]);
      setPages((current) => [...current, ...pageAdditions]);
      setMessage("");
    } catch (error) {
      console.error(error);
      setMessage("");
      alert("One of the PDF files could not be opened.");
    } finally {
      setBusy(false);
    }
  }

  function sourceFor(page: PageItem) {
    return sources.find((source) => source.id === page.sourceId);
  }

  function removeSource(sourceId: string) {
    setSources((current) => current.filter((source) => source.id !== sourceId));
    setPages((current) => current.filter((page) => page.sourceId !== sourceId));
  }

  function removePage(pageId: string) {
    setPages((current) => current.filter((page) => page.id !== pageId));
  }

  function movePage(index: number, direction: -1 | 1) {
    const target = index + direction;
    if (target < 0 || target >= pages.length) return;

    setPages((current) => {
      const copy = [...current];
      [copy[index], copy[target]] = [copy[target], copy[index]];
      return copy;
    });
  }

  async function rotatePage(index: number) {
    const item = pages[index];
    const source = sourceFor(item);
    if (!source) return;

    const rotation = (item.rotation + 90) % 360;
    const preview = await makePreview(
      source.bytes,
      item.sourcePageIndex,
      rotation
    );

    setPages((current) =>
      current.map((page, i) =>
        i === index ? { ...page, rotation, preview } : page
      )
    );
  }

  async function extractPage(index: number) {
    const item = pages[index];
    const source = sourceFor(item);
    if (!source) return;

    const sourceDoc = await PDFDocument.load(source.bytes.slice(0));
    const output = await PDFDocument.create();
    const [copied] = await output.copyPages(sourceDoc, [item.sourcePageIndex]);
    copied.setRotation(
      degrees((copied.getRotation().angle + item.rotation) % 360)
    );
    output.addPage(copied);
    downloadPdf(await output.save(), `page-${index + 1}.pdf`);
  }

  async function downloadFinal() {
    if (!pages.length) return;

    setBusy(true);
    setMessage("Creating final PDF...");

    try {
      const output = await PDFDocument.create();
      const loaded = new Map<string, PDFDocument>();

      for (const source of sources) {
        loaded.set(source.id, await PDFDocument.load(source.bytes.slice(0)));
      }

      for (const item of pages) {
        const sourceDoc = loaded.get(item.sourceId);
        if (!sourceDoc) continue;

        const [copied] = await output.copyPages(sourceDoc, [item.sourcePageIndex]);
        copied.setRotation(
          degrees((copied.getRotation().angle + item.rotation) % 360)
        );
        output.addPage(copied);
      }

      downloadPdf(await output.save(), "merged-edited-document.pdf");
      setMessage("");
    } catch (error) {
      console.error(error);
      setMessage("");
      alert("The final PDF could not be created.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="min-h-screen bg-slate-50 py-12">
      <div className="container-page max-w-7xl">
        <p className="eyebrow">PDF Tools</p>
        <h1 className="mt-3 text-4xl font-black text-navy-950">{title}</h1>
        <p className="mt-4 max-w-4xl text-lg leading-8 text-slate-700">
          {description}
        </p>

        <div className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <label className="flex cursor-pointer items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 px-5 py-8 font-black text-navy-950 transition hover:border-gold-400">
            <FilePlus2 className="size-5" />
            {sources.length ? "Add More PDF Files" : "Choose PDF Files"}
            <input
              type="file"
              accept="application/pdf"
              multiple
              className="hidden"
              onChange={(event) => addFiles(event.target.files)}
            />
          </label>

          {message ? (
            <div className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">
              {message}
            </div>
          ) : null}

          {sources.length ? (
            <section className="mt-6">
              <div className="mb-3 flex items-center gap-2">
                <Files className="size-5 text-navy-950" />
                <h2 className="text-lg font-black text-navy-950">
                  PDF Documents ({sources.length})
                </h2>
              </div>

              <div className="grid gap-3 md:grid-cols-2">
                {sources.map((source) => (
                  <div
                    key={source.id}
                    className="flex items-center justify-between gap-4 rounded-lg border border-slate-200 bg-slate-50 p-4"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-black text-navy-950">
                        {source.name}
                      </p>
                      <p className="mt-1 text-xs font-semibold text-slate-500">
                        {source.pageCount} page{source.pageCount === 1 ? "" : "s"}
                      </p>
                    </div>

                    <button
                      type="button"
                      onClick={() => removeSource(source.id)}
                      className="inline-flex shrink-0 items-center gap-1 rounded border border-red-200 px-3 py-2 text-xs font-black text-red-700"
                    >
                      <X className="size-4" />
                      Remove PDF
                    </button>
                  </div>
                ))}
              </div>
            </section>
          ) : null}

          {pages.length ? (
            <>
              <div className="mt-6 flex flex-wrap items-center justify-between gap-3 rounded-lg bg-navy-50 p-4">
                <p className="font-black text-navy-950">
                  Final document: {pages.length} page{pages.length === 1 ? "" : "s"}
                </p>

                <button
                  type="button"
                  onClick={downloadFinal}
                  disabled={busy}
                  className="inline-flex items-center gap-2 rounded-lg bg-navy-950 px-5 py-3 font-black text-white disabled:opacity-50"
                >
                  <Download className="size-4" />
                  Merge & Download Final PDF
                </button>
              </div>

              <div className="mt-6 grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {pages.map((item, index) => {
                  const source = sourceFor(item);

                  return (
                    <article
                      key={item.id}
                      className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"
                    >
                      <div className="flex min-h-64 items-center justify-center bg-slate-100 p-3">
                        <img
                          src={item.preview}
                          alt={`Page ${index + 1}`}
                          className="max-h-72 max-w-full rounded shadow"
                        />
                      </div>

                      <div className="p-4">
                        <p className="font-black text-navy-950">
                          Final Page {index + 1}
                        </p>
                        <p className="mt-1 truncate text-xs font-semibold text-slate-500">
                          {source?.name} - original page {item.sourcePageIndex + 1}
                        </p>

                        <div className="mt-4 grid grid-cols-4 gap-2">
                          <button
                            type="button"
                            title="Move left"
                            onClick={() => movePage(index, -1)}
                            disabled={index === 0}
                            className="grid min-h-10 place-items-center rounded border disabled:opacity-30"
                          >
                            <ArrowLeft className="size-4" />
                          </button>

                          <button
                            type="button"
                            title="Move right"
                            onClick={() => movePage(index, 1)}
                            disabled={index === pages.length - 1}
                            className="grid min-h-10 place-items-center rounded border disabled:opacity-30"
                          >
                            <ArrowRight className="size-4" />
                          </button>

                          <button
                            type="button"
                            title="Rotate page"
                            onClick={() => rotatePage(index)}
                            className="grid min-h-10 place-items-center rounded border"
                          >
                            <RotateCw className="size-4" />
                          </button>

                          <button
                            type="button"
                            title="Extract page"
                            onClick={() => extractPage(index)}
                            className="grid min-h-10 place-items-center rounded border"
                          >
                            <Scissors className="size-4" />
                          </button>
                        </div>

                        <button
                          type="button"
                          onClick={() => removePage(item.id)}
                          className="mt-2 inline-flex w-full items-center justify-center gap-2 rounded border border-red-200 px-3 py-2 font-black text-red-700"
                        >
                          <Trash2 className="size-4" />
                          Delete This Page
                        </button>
                      </div>
                    </article>
                  );
                })}
              </div>
            </>
          ) : null}
        </div>
      </div>
    </main>
  );
}