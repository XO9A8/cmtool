-- =============================================================================
-- CMTool Database — T_Matches updated_at Trigger
-- Migration: 20260820000001_t_matches_updated_at_trigger.sql
-- =============================================================================

-- Ensure the generic update_updated_at_column function exists
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach the trigger to t_matches
DROP TRIGGER IF EXISTS trg_t_matches_updated_at ON public.t_matches;
CREATE TRIGGER trg_t_matches_updated_at
BEFORE UPDATE ON public.t_matches
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
