"use client";

import { useEffect, useMemo, useState } from "react";
import { CalendarDays, Headphones, PlayCircle } from "lucide-react";
import { supabase } from "@/lib/supabaseClient";

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

const categories = ["All", "Sermon", "Video", "Audio", "News", "Announcement", "Teaching", "Testimony"];

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

  useEffect(() => {
    async function load() {
      const { data, error } = await supabase
        .from("content_posts")
        .select("*")
        .eq("published", true)
        .order("created_at", { ascending: false });

      if (error) console.error(error);
      setPosts((data || []) as ContentPost[]);
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
            Sermons, videos, audio teachings, news, announcements, testimonies, and English/Tigrinya resources.
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
                    <img src={post.image_url} alt="" className="h-60 w-full object-cover" />
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

          {!loading && filtered.length === 0 ? (
            <div className="mt-8 rounded-xl border border-slate-200 bg-white p-8 text-center text-slate-600">
              No published items in this category yet.
            </div>
          ) : null}
        </div>
      </section>
    </main>
  );
}