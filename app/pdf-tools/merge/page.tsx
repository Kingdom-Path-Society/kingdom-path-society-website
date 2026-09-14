import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Merge PDF"
      description="Open all PDF documents visually. Add more PDFs, remove a whole PDF, delete pages, reorder pages, rotate pages, extract pages, then merge and download the final document."
    />
  );
}