import Link from "next/link";
import { ToolShell } from "@/components/pdf/Shared";

export default function Page() {
  return (
    <ToolShell title="PDF Converter" description="Choose a conversion tool.">
      <div className="grid gap-4 sm:grid-cols-2">
        <Link className="rounded border p-5 font-black" href="/pdf-tools/pdf-image">
          Images to PDF
        </Link>
        <Link className="rounded border p-5 font-black" href="/pdf-tools/pdf-word">
          PDF to Word
        </Link>
      </div>
    </ToolShell>
  );
}