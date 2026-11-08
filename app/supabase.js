import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://ocqslehcfeelsbwpmqcm.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_E34Z2n-jnFv1FS_G4eTuIg_eUPHsxes";

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY
);
