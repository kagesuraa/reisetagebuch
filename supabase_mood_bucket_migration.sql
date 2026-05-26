-- ════════════════════════════════════════════════════════════════
--  Migration: mood + is_wishlist (Bucket-List) für reise_eintraege
--  Ausführen in: Supabase Dashboard → SQL Editor → New Query
-- ════════════════════════════════════════════════════════════════

-- 1. mood-Spalte (Emoji-String, optional)
ALTER TABLE reise_eintraege
  ADD COLUMN IF NOT EXISTS mood text;

-- 2. is_wishlist-Spalte: TRUE = Bucket-List-Eintrag (noch nicht besucht)
ALTER TABLE reise_eintraege
  ADD COLUMN IF NOT EXISTS is_wishlist boolean NOT NULL DEFAULT false;

-- 3. Index für Filter „nur Bucket-List" / „nur Reisen"
CREATE INDEX IF NOT EXISTS idx_reise_eintraege_is_wishlist
  ON reise_eintraege(is_wishlist);
