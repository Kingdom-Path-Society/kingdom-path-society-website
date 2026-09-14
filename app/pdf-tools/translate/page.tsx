import { ToolShell } from "@/components/pdf/Shared";

export default function Page() {
  return (
    <ToolShell title="Translate PDF" description="Translation needs a translation or AI API.">
      <div className="rounded-lg border border-amber-200 bg-amber-50 p-5 text-amber-900">
        This tool needs a secure server or API integration before public use.
        No secret API key should be placed in browser code.
      </div>
    </ToolShell>
  );
}