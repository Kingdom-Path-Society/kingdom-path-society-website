"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";

const ADMIN_EMAIL = "tesfalem.woldeab@kingdompathsociety.org";

export default function AdminLoginPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");

  async function signIn(event: FormEvent) {
    event.preventDefault();
    setMessage("Signing in...");

    const { error } = await supabase.auth.signInWithPassword({
      email: ADMIN_EMAIL,
      password
    });

    if (error) {
      setMessage(error.message);
      return;
    }

    router.push("/admin-dashboard/content");
  }

  async function createAdmin() {
    if (password.length < 8) {
      setMessage("Use a password with at least 8 characters.");
      return;
    }

    setMessage("Creating the admin account...");

    const { error } = await supabase.auth.signUp({
      email: ADMIN_EMAIL,
      password
    });

    if (error) {
      setMessage(error.message);
      return;
    }

    setMessage(
      "Admin account created. If Supabase asks for email confirmation, check the Kingdom Path Society email, confirm it, then return here and sign in."
    );
  }

  return (
    <main className="min-h-screen bg-slate-50 py-16">
      <div className="container-page max-w-lg">
        <div className="rounded-xl border border-slate-200 bg-white p-8 shadow-sm">
          <p className="eyebrow">Private Portal</p>
          <h1 className="mt-3 text-3xl font-black text-navy-950">Content Admin Login</h1>

          <div className="mt-5 rounded-lg bg-slate-50 p-4">
            <p className="text-xs font-bold uppercase tracking-wide text-slate-500">Admin email</p>
            <p className="mt-1 font-black text-navy-950">{ADMIN_EMAIL}</p>
          </div>

          <form onSubmit={signIn} className="mt-6 space-y-4">
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

            <button
              type="button"
              onClick={createAdmin}
              className="w-full rounded-lg border border-slate-300 bg-white p-4 font-black text-navy-950"
            >
              First Time? Create Admin Account
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