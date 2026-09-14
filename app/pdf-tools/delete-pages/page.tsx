import { PdfWorkspace } from "@/components/pdf/PdfWorkspace";

export default function Page() {
  return (
    <PdfWorkspace
      title="Delete PDF Pages"
      description="Open the PDF visually, delete any page, add another PDF if needed, reorder the remaining pages, and download the final document."
    />
  );
}