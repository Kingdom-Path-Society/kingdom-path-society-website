param(
  [string]$ProjectRoot = "C:\Users\tesfi\Documents\kingdom-path-society-website"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

function WriteFile {
  param([string]$Path,[string]$Content)
  $full = Join-Path $ProjectRoot $Path
  New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
  [System.IO.File]::WriteAllText($full,$Content,[System.Text.UTF8Encoding]::new($false))
  Write-Host "Updated $Path" -ForegroundColor Green
}

Write-Host "Installing content portal dependencies..." -ForegroundColor Cyan
npm install @supabase/supabase-js docx
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$supabaseClient = @'
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let client: SupabaseClient | null = null;

export function getSupabaseClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) return null;

  if (!client) {
    client = createClient(url, anonKey);
  }

  return client;
}
'@
WriteFile "lib\supabaseClient.ts" $supabaseClient

$pdfWord = @'
"use client";

import { useState } from "react";
import { Document, Packer, Paragraph, TextRun } from "docx";
import { FileText } from "lucide-react";
import { ToolShell } from "@/components/pdf/Shared";
import { loadPdfJs } from "@/lib/pdfjsClient";

export default function PdfToWordPage() {
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  async function convert() {
    if (!file) return;

    setBusy(true);
    setMessage("");

    try {
      const bytes = await file.arrayBuffer();
      const pdfjs = await loadPdfJs();
      const pdf = await pdfjs.getDocument({ data: bytes.slice(0) }).promise;
      const children: Paragraph[] = [];

      for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
        setMessage(`Reading page ${pageNumber} of ${pdf.numPages}...`);

        const page = await pdf.getPage(pageNumber);
        const textContent = await page.getTextContent();

        const text = textContent.items
          .map((item) => ("str" in item ? item.str : ""))
          .join(" ")
          .replace(/\s+/g, " ")
          .trim();

        children.push(
          new Paragraph({
            children: [new TextRun({ text: `Page ${pageNumber}`, bold: true })],
            spacing: { after: 160 }
          })
        );

        children.push(
          new Paragraph({
            children: [new TextRun(text || "[No selectable text found on this page]")],
            spacing: { after: 260 }
          })
        );
      }

      const doc = new Document({
        sections: [{ properties: {}, children }]
      });

      const blob = await Packer.toBlob(doc);
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");

      link.href = url;
      link.download = file.name.replace(/\.pdf$/i, "") + ".docx";
      document.body.appendChild(link);
      link.click();
      link.remove();

      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setMessage("Word document created.");
    } catch (error) {
      console.error(error);
      alert("This PDF could not be converted to Word.");
      setMessage("");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ToolShell
      title="PDF to Word"
      description="Convert selectable PDF text into a Microsoft Word document. Complex page layouts may not look exactly like the original PDF."
    >
      <label className="flex cursor-pointer items-center justify-center gap-2 rounded-xl border-2 border-dashed border-slate-300 bg-slate-50 p-8 font-black text-navy-950">
        <FileText className="size-5" />
        {file ? file.name : "Choose PDF file"}
        <input
          type="file"
          accept="application/pdf"
          className="hidden"
          onChange={(event) => setFile(event.target.files?.[0] || null)}
        />
      </label>

      <button
        type="button"
        disabled={!file || busy}
        onClick={convert}
        className="mt-5 w-full rounded-lg bg-navy-950 p-4 font-black text-white disabled:opacity-50"
      >
        {busy ? "Converting..." : "Convert to Word"}
      </button>

      {message ? (
        <p className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">
          {message}
        </p>
      ) : null}
    </ToolShell>
  );
}
'@
WriteFile "app\pdf-tools\pdf-word\page.tsx" $pdfWord

$resources = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { CalendarDays, Headphones, PlayCircle } from "lucide-react";
import { getSupabaseClient } from "@/lib/supabaseClient";

type ContentPost = {
  id: string;
  type: string;
  title_en: string;
  title_ti: string | null;
  summary_en: string | null;
  summary_ti: string | null;
  content_en: string | null;
  content_ti: string | null;
  video_url: string | null;
  audio_url: string | null;
  image_url: string | null;
  created_at: string;
};

const categories = ["All", "Sermon", "Video", "Audio", "News", "Announcement"];

function youtubeEmbed(url: string | null) {
  if (!url) return null;

  const watch = url.match(/[?&]v=([^&]+)/);
  if (watch?.[1]) return `https://www.youtube.com/embed/${watch[1]}`;

  const short = url.match(/youtu\.be\/([^?&/]+)/);
  if (short?.[1]) return `https://www.youtube.com/embed/${short[1]}`;

  return null;
}

export default function ResourcesPage() {
  const [posts, setPosts] = useState<ContentPost[]>([]);
  const [category, setCategory] = useState("All");
  const [loading, setLoading] = useState(true);
  const [setupMissing, setSetupMissing] = useState(false);

  useEffect(() => {
    async function load() {
      const supabase = getSupabaseClient();

      if (!supabase) {
        setSetupMissing(true);
        setLoading(false);
        return;
      }

      const { data, error } = await supabase
        .from("content_posts")
        .select("*")
        .eq("published", true)
        .order("created_at", { ascending: false });

      if (error) {
        console.error(error);
      } else {
        setPosts((data || []) as ContentPost[]);
      }

      setLoading(false);
    }

    load();
  }, []);

  const filtered = useMemo(() => {
    if (category === "All") return posts;
    return posts.filter((post) => post.type.toLowerCase() === category.toLowerCase());
  }, [posts, category]);

  return (
    <main className="min-h-screen bg-slate-50">
      <section className="bg-navy-950 py-16 text-white">
        <div className="container-page">
          <p className="eyebrow text-gold-300">Kingdom Path Society</p>
          <h1 className="mt-3 text-4xl font-black sm:text-5xl">Media & Resources</h1>
          <p className="mt-4 max-w-3xl text-lg leading-8 text-slate-200">
            Sermons, videos, audio teachings, announcements, news, and bilingual English/Tigrinya resources.
          </p>
        </div>
      </section>

      <section className="section-y">
        <div className="container-page">
          <div className="flex flex-wrap gap-2">
            {categories.map((item) => (
              <button
                key={item}
                type="button"
                onClick={() => setCategory(item)}
                className={`rounded-full border px-4 py-2 text-sm font-black ${
                  category === item
                    ? "border-navy-950 bg-navy-950 text-white"
                    : "border-slate-200 bg-white text-navy-950"
                }`}
              >
                {item}
              </button>
            ))}
          </div>

          {setupMissing ? (
            <div className="mt-8 rounded-xl border border-amber-200 bg-amber-50 p-6 text-amber-900">
              The public content page is ready. Connect Supabase to publish live posts.
            </div>
          ) : null}

          {loading ? (
            <p className="mt-8 font-bold text-slate-600">Loading resources...</p>
          ) : null}

          <div className="mt-8 grid gap-6 lg:grid-cols-2">
            {filtered.map((post) => {
              const embed = youtubeEmbed(post.video_url);

              return (
                <article
                  key={post.id}
                  className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"
                >
                  {post.image_url ? (
                    <img
                      src={post.image_url}
                      alt=""
                      className="h-60 w-full object-cover"
                    />
                  ) : null}

                  {embed ? (
                    <div className="aspect-video">
                      <iframe
                        src={embed}
                        title={post.title_en}
                        className="h-full w-full"
                        allowFullScreen
                      />
                    </div>
                  ) : null}

                  <div className="p-6">
                    <div className="flex flex-wrap items-center gap-3 text-xs font-bold uppercase tracking-wide text-slate-500">
                      <span>{post.type}</span>
                      <span className="inline-flex items-center gap-1">
                        <CalendarDays className="size-3" />
                        {new Date(post.created_at).toLocaleDateString()}
                      </span>
                    </div>

                    <h2 className="mt-3 text-2xl font-black text-navy-950">
                      {post.title_en}
                    </h2>

                    {post.title_ti ? (
                      <h3 className="mt-2 text-xl font-black text-navy-900">
                        {post.title_ti}
                      </h3>
                    ) : null}

                    {post.summary_en ? (
                      <p className="mt-4 leading-7 text-slate-700">{post.summary_en}</p>
                    ) : null}

                    {post.summary_ti ? (
                      <p className="mt-3 leading-7 text-slate-700">{post.summary_ti}</p>
                    ) : null}

                    {post.audio_url ? (
                      <div className="mt-5 rounded-lg bg-slate-50 p-4">
                        <p className="mb-2 inline-flex items-center gap-2 font-black text-navy-950">
                          <Headphones className="size-4" />
                          Audio
                        </p>
                        <audio controls className="w-full" src={post.audio_url} />
                      </div>
                    ) : null}

                    {post.video_url && !embed ? (
                      <a
                        href={post.video_url}
                        target="_blank"
                        rel="noreferrer"
                        className="mt-5 inline-flex items-center gap-2 font-black text-navy-950 underline"
                      >
                        <PlayCircle className="size-4" />
                        Watch Video
                      </a>
                    ) : null}

                    {post.content_en ? (
                      <div className="mt-5 whitespace-pre-wrap leading-7 text-slate-700">
                        {post.content_en}
                      </div>
                    ) : null}

                    {post.content_ti ? (
                      <div className="mt-5 whitespace-pre-wrap border-t border-slate-200 pt-5 leading-7 text-slate-700">
                        {post.content_ti}
                      </div>
                    ) : null}
                  </div>
                </article>
              );
            })}
          </div>

          {!loading && !setupMissing && filtered.length === 0 ? (
            <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center text-slate-600">
              No published items in this category yet.
            </div>
          ) : null}
        </div>
      </section>
    </main>
  );
}
'@
WriteFile "app\resources\page.tsx" $resources

$login = @'
"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent) {
    event.preventDefault();

    const supabase = getSupabaseClient();

    if (!supabase) {
      setMessage("Supabase is not connected yet. Add the environment variables first.");
      return;
    }

    setMessage("Signing in...");

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      setMessage(error.message);
      return;
    }

    router.push("/admin-dashboard/content");
  }

  return (
    <main className="min-h-screen bg-slate-50 py-16">
      <div className="container-page max-w-lg">
        <div className="rounded-xl border border-slate-200 bg-white p-8 shadow-sm">
          <p className="eyebrow">Private Portal</p>
          <h1 className="mt-3 text-3xl font-black text-navy-950">Content Admin Login</h1>
          <p className="mt-3 text-slate-600">
            Sign in to publish sermons, videos, audio, news, and bilingual resources.
          </p>

          <form onSubmit={submit} className="mt-6 space-y-4">
            <input
              type="email"
              required
              placeholder="Email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="w-full rounded-lg border border-slate-300 p-3"
            />

            <input
              type="password"
              required
              placeholder="Password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="w-full rounded-lg border border-slate-300 p-3"
            />

            <button
              type="submit"
              className="w-full rounded-lg bg-navy-950 p-4 font-black text-white"
            >
              Sign In
            </button>
          </form>

          {message ? (
            <p className="mt-4 rounded-lg bg-slate-100 p-4 text-sm font-bold text-slate-700">
              {message}
            </p>
          ) : null}
        </div>
      </div>
    </main>
  );
}
'@
WriteFile "app\admin-login\page.tsx" $login

$admin = @'
"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";

type Post = {
  id: string;
  type: string;
  title_en: string;
  title_ti: string | null;
  summary_en: string | null;
  summary_ti: string | null;
  content_en: string | null;
  content_ti: string | null;
  video_url: string | null;
  audio_url: string | null;
  image_url: string | null;
  published: boolean;
};

const emptyForm = {
  id: "",
  type: "Sermon",
  title_en: "",
  title_ti: "",
  summary_en: "",
  summary_ti: "",
  content_en: "",
  content_ti: "",
  video_url: "",
  audio_url: "",
  image_url: "",
  published: true
};

export default function ContentAdminPage() {
  const router = useRouter();
  const [form, setForm] = useState(emptyForm);
  const [posts, setPosts] = useState<Post[]>([]);
  const [message, setMessage] = useState("");
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [audioFile, setAudioFile] = useState<File | null>(null);

  async function loadPosts() {
    const supabase = getSupabaseClient();
    if (!supabase) return;

    const { data } = await supabase
      .from("content_posts")
      .select("*")
      .order("created_at", { ascending: false });

    setPosts((data || []) as Post[]);
  }

  useEffect(() => {
    async function check() {
      const supabase = getSupabaseClient();

      if (!supabase) {
        setMessage("Supabase setup is required before using the live portal.");
        return;
      }

      const { data } = await supabase.auth.getSession();

      if (!data.session) {
        router.replace("/admin-login");
        return;
      }

      loadPosts();
    }

    check();
  }, [router]);

  async function upload(file: File, folder: string) {
    const supabase = getSupabaseClient();
    if (!supabase) throw new Error("Supabase is not connected.");

    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    const path = `${folder}/${Date.now()}-${safeName}`;

    const { error } = await supabase.storage
      .from("content-media")
      .upload(path, file, {
        cacheControl: "3600",
        upsert: false
      });

    if (error) throw error;

    return supabase.storage
      .from("content-media")
      .getPublicUrl(path).data.publicUrl;
  }

  async function save(event: FormEvent) {
    event.preventDefault();

    const supabase = getSupabaseClient();
    if (!supabase) return;

    setMessage("Saving...");

    try {
      let imageUrl = form.image_url;
      let audioUrl = form.audio_url;

      if (coverFile) imageUrl = await upload(coverFile, "images");
      if (audioFile) audioUrl = await upload(audioFile, "audio");

      const payload = {
        type: form.type,
        title_en: form.title_en,
        title_ti: form.title_ti || null,
        summary_en: form.summary_en || null,
        summary_ti: form.summary_ti || null,
        content_en: form.content_en || null,
        content_ti: form.content_ti || null,
        video_url: form.video_url || null,
        audio_url: audioUrl || null,
        image_url: imageUrl || null,
        published: form.published
      };

      if (form.id) {
        const { error } = await supabase
          .from("content_posts")
          .update(payload)
          .eq("id", form.id);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from("content_posts")
          .insert(payload);

        if (error) throw error;
      }

      setForm(emptyForm);
      setCoverFile(null);
      setAudioFile(null);
      setMessage("Saved successfully.");
      await loadPosts();
    } catch (error) {
      console.error(error);
      setMessage(error instanceof Error ? error.message : "Save failed.");
    }
  }

  function edit(post: Post) {
    setForm({
      id: post.id,
      type: post.type,
      title_en: post.title_en,
      title_ti: post.title_ti || "",
      summary_en: post.summary_en || "",
      summary_ti: post.summary_ti || "",
      content_en: post.content_en || "",
      content_ti: post.content_ti || "",
      video_url: post.video_url || "",
      audio_url: post.audio_url || "",
      image_url: post.image_url || "",
      published: post.published
    });

    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function remove(id: string) {
    if (!confirm("Delete this post?")) return;

    const supabase = getSupabaseClient();
    if (!supabase) return;

    await supabase.from("content_posts").delete().eq("id", id);
    await loadPosts();
  }

  async function signOut() {
    const supabase = getSupabaseClient();
    if (supabase) await supabase.auth.signOut();
    router.push("/admin-login");
  }

  return (
    <main className="min-h-screen bg-slate-50 py-12">
      <div className="container-page max-w-6xl">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="eyebrow">Private Admin</p>
            <h1 className="mt-2 text-4xl font-black text-navy-950">
              Content Publishing Portal
            </h1>
          </div>

          <button
            type="button"
            onClick={signOut}
            className="rounded-lg border border-slate-300 bg-white px-4 py-2 font-black text-navy-950"
          >
            Sign Out
          </button>
        </div>

        <form
          onSubmit={save}
          className="mt-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm"
        >
          <div className="grid gap-5 md:grid-cols-2">
            <label className="font-bold text-navy-950">
              Content Type
              <select
                value={form.type}
                onChange={(event) => setForm({ ...form, type: event.target.value })}
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              >
                <option>Sermon</option>
                <option>Video</option>
                <option>Audio</option>
                <option>News</option>
                <option>Announcement</option>
                <option>Teaching</option>
                <option>Testimony</option>
              </select>
            </label>

            <label className="flex items-center gap-3 pt-8 font-bold text-navy-950">
              <input
                type="checkbox"
                checked={form.published}
                onChange={(event) =>
                  setForm({ ...form, published: event.target.checked })
                }
              />
              Publish immediately
            </label>
          </div>

          <div className="mt-5 grid gap-5 md:grid-cols-2">
            <label className="font-bold text-navy-950">
              English Heading
              <input
                required
                value={form.title_en}
                onChange={(event) =>
                  setForm({ ...form, title_en: event.target.value })
                }
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Tigrinya Heading
              <input
                value={form.title_ti}
                onChange={(event) =>
                  setForm({ ...form, title_ti: event.target.value })
                }
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>
          </div>

          <div className="mt-5 grid gap-5 md:grid-cols-2">
            <label className="font-bold text-navy-950">
              English Summary
              <textarea
                rows={3}
                value={form.summary_en}
                onChange={(event) =>
                  setForm({ ...form, summary_en: event.target.value })
                }
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Tigrinya Summary
              <textarea
                rows={3}
                value={form.summary_ti}
                onChange={(event) =>
                  setForm({ ...form, summary_ti: event.target.value })
                }
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>
          </div>

          <div className="mt-5 grid gap-5 md:grid-cols-2">
            <label className="font-bold text-navy-950">
              English Content
              <textarea
                rows={8}
                value={form.content_en}
                onChange={(event) =>
                  setForm({ ...form, content_en: event.target.value })
                }
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Tigrinya Content
              <textarea
                rows={8}
                value={form.content_ti}
                onChange={(event) =>
                  setForm({ ...form, content_ti: event.target.value })
                }
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>
          </div>

          <label className="mt-5 block font-bold text-navy-950">
            Video Link (YouTube or other)
            <input
              type="url"
              value={form.video_url}
              onChange={(event) =>
                setForm({ ...form, video_url: event.target.value })
              }
              className="mt-2 w-full rounded-lg border border-slate-300 p-3"
            />
          </label>

          <div className="mt-5 grid gap-5 md:grid-cols-2">
            <label className="font-bold text-navy-950">
              Cover Image Upload
              <input
                type="file"
                accept="image/*"
                onChange={(event) => setCoverFile(event.target.files?.[0] || null)}
                className="mt-2 block w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Audio Upload (sermon / teaching)
              <input
                type="file"
                accept="audio/*"
                onChange={(event) => setAudioFile(event.target.files?.[0] || null)}
                className="mt-2 block w-full rounded-lg border border-slate-300 p-3"
              />
            </label>
          </div>

          <div className="mt-6 flex flex-wrap gap-3">
            <button
              type="submit"
              className="rounded-lg bg-navy-950 px-6 py-3 font-black text-white"
            >
              {form.id ? "Update Post" : "Publish / Save Post"}
            </button>

            <button
              type="button"
              onClick={() => setForm(emptyForm)}
              className="rounded-lg border border-slate-300 bg-white px-6 py-3 font-black text-navy-950"
            >
              New / Clear
            </button>
          </div>

          {message ? (
            <p className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">
              {message}
            </p>
          ) : null}
        </form>

        <section className="mt-8">
          <h2 className="text-2xl font-black text-navy-950">Existing Posts</h2>

          <div className="mt-4 space-y-3">
            {posts.map((post) => (
              <div
                key={post.id}
                className="flex flex-wrap items-center justify-between gap-4 rounded-lg border border-slate-200 bg-white p-4"
              >
                <div>
                  <p className="font-black text-navy-950">{post.title_en}</p>
                  <p className="mt-1 text-xs font-bold text-slate-500">
                    {post.type} - {post.published ? "Published" : "Draft"}
                  </p>
                </div>

                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => edit(post)}
                    className="rounded border px-4 py-2 font-bold"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => remove(post.id)}
                    className="rounded border border-red-200 px-4 py-2 font-bold text-red-700"
                  >
                    Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>
    </main>
  );
}
'@
WriteFile "app\admin-dashboard\content\page.tsx" $admin

$sql = @'
-- Kingdom Path Society Content CMS
-- Run this in the Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.content_posts (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'Sermon',
  title_en text not null,
  title_ti text,
  summary_en text,
  summary_ti text,
  content_en text,
  content_ti text,
  video_url text,
  audio_url text,
  image_url text,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.content_posts enable row level security;

drop policy if exists "Public can read published content" on public.content_posts;
create policy "Public can read published content"
on public.content_posts
for select
using (published = true or auth.role() = 'authenticated');

drop policy if exists "Authenticated users can insert content" on public.content_posts;
create policy "Authenticated users can insert content"
on public.content_posts
for insert
to authenticated
with check (true);

drop policy if exists "Authenticated users can update content" on public.content_posts;
create policy "Authenticated users can update content"
on public.content_posts
for update
to authenticated
using (true)
with check (true);

drop policy if exists "Authenticated users can delete content" on public.content_posts;
create policy "Authenticated users can delete content"
on public.content_posts
for delete
to authenticated
using (true);

insert into storage.buckets (id, name, public)
values ('content-media', 'content-media', true)
on conflict (id) do update set public = true;

drop policy if exists "Public content media read" on storage.objects;
create policy "Public content media read"
on storage.objects
for select
using (bucket_id = 'content-media');

drop policy if exists "Authenticated content media upload" on storage.objects;
create policy "Authenticated content media upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'content-media');

drop policy if exists "Authenticated content media update" on storage.objects;
create policy "Authenticated content media update"
on storage.objects
for update
to authenticated
using (bucket_id = 'content-media');

drop policy if exists "Authenticated content media delete" on storage.objects;
create policy "Authenticated content media delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'content-media');

-- In Supabase Authentication settings, disable public sign-ups
-- if only your staff should use the admin portal.
'@
WriteFile "supabase\content-cms.sql" $sql

$envExample = @'
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
'@
WriteFile ".env.cms.example" $envExample

$pdfHubPath = Join-Path $ProjectRoot "app\pdf-tools\page.tsx"
$pdfHub = Get-Content $pdfHubPath -Raw
$pdfHub = $pdfHub.Replace('["PDF <-> Image", Image, "/pdf-tools/pdf-image", "Images to PDF"]','["Image to PDF", Image, "/pdf-tools/pdf-image", "Convert JPG and PNG images to PDF"]')
$pdfHub = $pdfHub.Replace('["PDF <-> Word", FileText, "/pdf-tools/pdf-word", "Needs conversion API"]','["PDF to Word", FileText, "/pdf-tools/pdf-word", "Convert selectable PDF text to Word"]')
[System.IO.File]::WriteAllText($pdfHubPath,$pdfHub,[System.Text.UTF8Encoding]::new($false))
Write-Host "Corrected PDF tool names." -ForegroundColor Green

$sitePath = Join-Path $ProjectRoot "data\site.ts"
$siteText = Get-Content $sitePath -Raw
if ($siteText -notmatch 'label:\s*"Resources"') {
  $insert = '{ label: "PDF Tools", href: "/pdf-tools" },' + "`r`n  " + '{ label: "Resources", href: "/resources" },'
  $siteText = $siteText.Replace('{ label: "PDF Tools", href: "/pdf-tools" },', $insert)
  [System.IO.File]::WriteAllText($sitePath,$siteText,[System.Text.UTF8Encoding]::new($false))
  Write-Host "Added Resources to navigation." -ForegroundColor Green
}

Write-Host "Running production build check..." -ForegroundColor Cyan
npm run build

if ($LASTEXITCODE -ne 0) {
  Write-Host "BUILD FAILED. Nothing was pushed." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "SUCCESS: PDF corrections and Content Portal installed. Build passed." -ForegroundColor Green
Write-Host "Supabase connection is the remaining setup step for live publishing." -ForegroundColor Yellow
