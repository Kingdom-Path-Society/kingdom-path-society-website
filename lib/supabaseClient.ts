import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://aycfrqzgyeeteamxacof.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_4Y7VeRJiPxbHgYOOwr5tTg_ixDM-ptP";

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY
);