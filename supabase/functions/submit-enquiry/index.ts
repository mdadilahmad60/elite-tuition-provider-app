// ELITE TUITION PROVIDER - public enquiry endpoint
// Deploy with: supabase functions deploy submit-enquiry
// Supabase injects SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY into the function runtime.
// Never copy the service-role key into browser code or GitHub frontend files.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const clean = (value: unknown, max = 200) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const contentLength = Number(req.headers.get("content-length") || "0");
  if (contentLength > 12_000) return json({ error: "Request too large" }, 413);

  try {
    const body = await req.json();
    const name = clean(body.name, 100);
    const phone = clean(body.phone, 25);
    const email = clean(body.email, 150);
    const service = clean(body.service || "Home Tuition", 80);
    const studentClass = clean(body.student_class, 50);
    const board = clean(body.board, 50);
    const subjects = clean(body.subjects, 250);
    const district = clean(body.district || body.area, 100);
    const area = clean(body.area, 150);
    const message = clean(body.message, 1500);

    if (name.length < 2) return json({ error: "Please enter a valid name." }, 400);
    if (!/^[+0-9()\s-]{8,20}$/.test(phone)) {
      return json({ error: "Please enter a valid phone number." }, 400);
    }
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: "Please enter a valid email address." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing server-side Supabase environment configuration.");
      return json({ error: "Service is temporarily unavailable." }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error } = await supabase.from("enquiries").insert({
      name,
      phone,
      email: email || null,
      service,
      student_class: studentClass || null,
      board: board || null,
      subjects: subjects || null,
      district: district || null,
      area: area || null,
      message: message || null,
      source: "website",
      status: "New",
    });

    if (error) {
      console.error("Enquiry insert failed:", error.message);
      return json({ error: "Could not submit your enquiry. Please try again." }, 500);
    }

    return json({ success: true, message: "Your enquiry has been submitted." }, 201);
  } catch {
    return json({ error: "Invalid request. Please check the submitted details." }, 400);
  }
});
