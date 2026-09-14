"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";

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
    const { data } = await supabase
      .from("content_posts")
      .select("*")
      .order("created_at", { ascending: false });

    setPosts((data || []) as Post[]);
  }

  useEffect(() => {
    async function check() {
      const { data } = await supabase.auth.getSession();

      if (!data.session) {
        router.replace("/admin-login");
        return;
      }

      await loadPosts();
    }

    check();
  }, [router]);

  async function upload(file: File, folder: string) {
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    const path = `${folder}/${Date.now()}-${safeName}`;

    const { error } = await supabase.storage
      .from("content-media")
      .upload(path, file, { cacheControl: "3600", upsert: false });

    if (error) throw error;

    return supabase.storage
      .from("content-media")
      .getPublicUrl(path).data.publicUrl;
  }

  async function save(event: FormEvent) {
    event.preventDefault();
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
        const { error } = await supabase.from("content_posts").insert(payload);
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
    await supabase.from("content_posts").delete().eq("id", id);
    await loadPosts();
  }

  async function signOut() {
    await supabase.auth.signOut();
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
                onChange={(event) => setForm({ ...form, published: event.target.checked })}
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
                onChange={(event) => setForm({ ...form, title_en: event.target.value })}
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Tigrinya Heading
              <input
                value={form.title_ti}
                onChange={(event) => setForm({ ...form, title_ti: event.target.value })}
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
                onChange={(event) => setForm({ ...form, summary_en: event.target.value })}
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Tigrinya Summary
              <textarea
                rows={3}
                value={form.summary_ti}
                onChange={(event) => setForm({ ...form, summary_ti: event.target.value })}
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
                onChange={(event) => setForm({ ...form, content_en: event.target.value })}
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>

            <label className="font-bold text-navy-950">
              Tigrinya Content
              <textarea
                rows={8}
                value={form.content_ti}
                onChange={(event) => setForm({ ...form, content_ti: event.target.value })}
                className="mt-2 w-full rounded-lg border border-slate-300 p-3"
              />
            </label>
          </div>

          <label className="mt-5 block font-bold text-navy-950">
            Video Link (YouTube or other)
            <input
              type="url"
              value={form.video_url}
              onChange={(event) => setForm({ ...form, video_url: event.target.value })}
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
            <button type="submit" className="rounded-lg bg-navy-950 px-6 py-3 font-black text-white">
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
            <p className="mt-4 rounded-lg bg-slate-100 p-4 font-bold text-slate-700">{message}</p>
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
                  <button type="button" onClick={() => edit(post)} className="rounded border px-4 py-2 font-bold">
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