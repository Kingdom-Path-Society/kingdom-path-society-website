import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Split / Extract PDF"
      description="Open the PDF visually, remove pages you do not want, extract individual pages, reorder pages, and download the result."
    />
  );
}