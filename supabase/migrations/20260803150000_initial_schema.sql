--
-- PostgreSQL database dump
--

\restrict dyEhKLKwyABhKSAlLPEUKi7c9e2LyQ2HGHwsLpVab8jDdDMkhmwqkEhx35tycqx

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _sqlx_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._sqlx_migrations (
    version bigint NOT NULL,
    description text NOT NULL,
    installed_on timestamp with time zone DEFAULT now() NOT NULL,
    success boolean NOT NULL,
    checksum bytea NOT NULL,
    execution_time bigint NOT NULL
);


ALTER TABLE public._sqlx_migrations OWNER TO postgres;

--
-- Name: badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    icon_url text,
    criteria jsonb NOT NULL
);


ALTER TABLE public.badges OWNER TO postgres;

--
-- Name: club_memberships; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.club_memberships (
    player_id uuid NOT NULL,
    club_id uuid NOT NULL,
    role character varying(20) DEFAULT 'player'::character varying,
    joined_at timestamp with time zone DEFAULT now(),
    skill_rating integer DEFAULT 1000,
    form_rating numeric(5,2) DEFAULT 50.00,
    play_style character varying(50) DEFAULT 'Unclassified'::character varying
);


ALTER TABLE public.club_memberships OWNER TO postgres;

--
-- Name: clubs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clubs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    invite_code character varying(10) NOT NULL,
    owner_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone
);


ALTER TABLE public.clubs OWNER TO postgres;

--
-- Name: elo_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.elo_history (
    id bigint NOT NULL,
    player_id uuid,
    match_record_id uuid,
    rating_before integer NOT NULL,
    rating_after integer NOT NULL,
    recorded_at timestamp with time zone DEFAULT now(),
    club_id uuid
);


ALTER TABLE public.elo_history OWNER TO postgres;

--
-- Name: elo_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.elo_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.elo_history_id_seq OWNER TO postgres;

--
-- Name: elo_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.elo_history_id_seq OWNED BY public.elo_history.id;


--
-- Name: league_standings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.league_standings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tournament_id uuid,
    player_id uuid,
    played integer DEFAULT 0,
    won integer DEFAULT 0,
    drawn integer DEFAULT 0,
    lost integer DEFAULT 0,
    goals_for integer DEFAULT 0,
    goals_against integer DEFAULT 0,
    goal_diff integer DEFAULT 0,
    points integer DEFAULT 0,
    updated_at timestamp with time zone DEFAULT now(),
    group_name character varying(50),
    last_processed_match_id uuid
);


ALTER TABLE public.league_standings OWNER TO postgres;

--
-- Name: match_disputes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.match_disputes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    match_record_id uuid,
    raised_by uuid,
    reason text NOT NULL,
    status character varying(20) DEFAULT 'open'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    counter_screenshot_url text,
    resolved_by uuid,
    resolution_notes text,
    resolved_at timestamp with time zone
);


ALTER TABLE public.match_disputes OWNER TO postgres;

--
-- Name: match_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.match_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    player_id uuid,
    opponent_id uuid,
    partner_id uuid,
    opponent_partner_id uuid,
    t_match_id uuid,
    match_type character varying(20) DEFAULT 'friendly'::character varying NOT NULL,
    result character varying(10) NOT NULL,
    goals_for integer NOT NULL,
    goals_against integer NOT NULL,
    possession numeric(4,1) NOT NULL,
    passes_completed integer NOT NULL,
    passes_attempted integer NOT NULL,
    shots_on_target integer NOT NULL,
    shots_total integer NOT NULL,
    interceptions integer NOT NULL,
    ocr_confidence numeric(4,1) DEFAULT 100.0,
    screenshot_hash character varying(64) NOT NULL,
    screenshot_url text,
    verification_status character varying(20) DEFAULT 'approved'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    club_id uuid,
    fouls integer DEFAULT 0 NOT NULL,
    offsides integer DEFAULT 0 NOT NULL,
    corners integer DEFAULT 0 NOT NULL,
    free_kicks integer DEFAULT 0 NOT NULL,
    crosses integer DEFAULT 0 NOT NULL,
    tackles integer DEFAULT 0 NOT NULL,
    saves integer DEFAULT 0 NOT NULL,
    verified_by_id uuid
);


ALTER TABLE public.match_records OWNER TO postgres;

--
-- Name: player_badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_badges (
    player_id uuid NOT NULL,
    badge_id uuid NOT NULL,
    earned_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.player_badges OWNER TO postgres;

--
-- Name: player_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_profiles (
    user_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    lifetime_matches integer DEFAULT 0,
    lifetime_wins integer DEFAULT 0,
    efootball_game_id character varying(50),
    preferred_foot character varying(10) DEFAULT 'RIGHT'::character varying,
    jersey_number integer DEFAULT 10,
    system_device character varying(100) DEFAULT 'REDMI NOTE 14 PRO+'::character varying,
    facebook character varying(255),
    blood_group character varying(10) DEFAULT 'O+'::character varying,
    district character varying(100) DEFAULT 'DHAKA'::character varying,
    date_of_birth date DEFAULT '2000-01-01'::date,
    registrar_joined date DEFAULT '2026-07-26'::date,
    contract_start date DEFAULT '2026-07-29'::date,
    contract_end date DEFAULT '2027-01-25'::date,
    facebook_link character varying(100),
    email_node character varying(150),
    phone_line character varying(50),
    node_state character varying(20) DEFAULT 'ACTIVE'::character varying,
    auth_status character varying(20) DEFAULT 'MEMBER'::character varying,
    source_feed character varying(100) DEFAULT 'CENTRAL FEDERATION'::character varying
);


ALTER TABLE public.player_profiles OWNER TO postgres;

--
-- Name: season_snapshots; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.season_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    season_id uuid,
    player_id uuid,
    final_skill_rating integer NOT NULL,
    final_form_rating numeric(5,2),
    matches_played integer,
    win_rate numeric(5,2)
);


ALTER TABLE public.season_snapshots OWNER TO postgres;

--
-- Name: seasons; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seasons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id uuid,
    name character varying(100) NOT NULL,
    start_date date NOT NULL,
    end_date date,
    is_active boolean DEFAULT true
);


ALTER TABLE public.seasons OWNER TO postgres;

--
-- Name: squad_verifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.squad_verifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    t_match_id uuid,
    player_id uuid,
    team_strength integer NOT NULL,
    screenshot_url text NOT NULL,
    is_valid boolean DEFAULT true,
    uploaded_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.squad_verifications OWNER TO postgres;

--
-- Name: t_matches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.t_matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tournament_id uuid,
    player_1_id uuid,
    player_2_id uuid,
    round_number integer NOT NULL,
    status character varying(20) DEFAULT 'scheduled'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    match_record_id uuid,
    group_name character varying(50),
    player_1_score integer,
    player_2_score integer,
    match_number integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.t_matches OWNER TO postgres;

--
-- Name: tournaments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tournaments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id uuid,
    name character varying(100) NOT NULL,
    format_type character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'draft'::character varying,
    rules_config jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    CONSTRAINT tournaments_format_type_check CHECK (((format_type)::text = ANY ((ARRAY['knockout'::character varying, 'round_robin'::character varying, 'league'::character varying, 'group_knockout'::character varying])::text[])))
);


ALTER TABLE public.tournaments OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    password_hash text
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: elo_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elo_history ALTER COLUMN id SET DEFAULT nextval('public.elo_history_id_seq'::regclass);


--
-- Name: _sqlx_migrations _sqlx_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._sqlx_migrations
    ADD CONSTRAINT _sqlx_migrations_pkey PRIMARY KEY (version);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: club_memberships club_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.club_memberships
    ADD CONSTRAINT club_memberships_pkey PRIMARY KEY (player_id, club_id);


--
-- Name: clubs clubs_invite_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clubs
    ADD CONSTRAINT clubs_invite_code_key UNIQUE (invite_code);


--
-- Name: clubs clubs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clubs
    ADD CONSTRAINT clubs_pkey PRIMARY KEY (id);


--
-- Name: elo_history elo_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elo_history
    ADD CONSTRAINT elo_history_pkey PRIMARY KEY (id);


--
-- Name: league_standings league_standings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_standings
    ADD CONSTRAINT league_standings_pkey PRIMARY KEY (id);


--
-- Name: league_standings league_standings_tournament_id_player_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_standings
    ADD CONSTRAINT league_standings_tournament_id_player_id_key UNIQUE (tournament_id, player_id);


--
-- Name: match_disputes match_disputes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_disputes
    ADD CONSTRAINT match_disputes_pkey PRIMARY KEY (id);


--
-- Name: match_records match_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_pkey PRIMARY KEY (id);


--
-- Name: match_records match_records_screenshot_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_screenshot_hash_key UNIQUE (screenshot_hash);


--
-- Name: player_badges player_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_badges
    ADD CONSTRAINT player_badges_pkey PRIMARY KEY (player_id, badge_id);


--
-- Name: player_profiles player_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_profiles
    ADD CONSTRAINT player_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: season_snapshots season_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.season_snapshots
    ADD CONSTRAINT season_snapshots_pkey PRIMARY KEY (id);


--
-- Name: seasons seasons_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_pkey PRIMARY KEY (id);


--
-- Name: squad_verifications squad_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.squad_verifications
    ADD CONSTRAINT squad_verifications_pkey PRIMARY KEY (id);


--
-- Name: t_matches t_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_matches
    ADD CONSTRAINT t_matches_pkey PRIMARY KEY (id);


--
-- Name: tournaments tournaments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournaments
    ADD CONSTRAINT tournaments_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_elo_history_club; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_elo_history_club ON public.elo_history USING btree (club_id, recorded_at DESC);


--
-- Name: idx_elo_history_player; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_elo_history_player ON public.elo_history USING btree (player_id, recorded_at DESC);


--
-- Name: idx_league_standings_tournament; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_league_standings_tournament ON public.league_standings USING btree (tournament_id, points DESC);


--
-- Name: idx_match_records_player; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_match_records_player ON public.match_records USING btree (player_id, created_at DESC);


--
-- Name: idx_matches_composite; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matches_composite ON public.match_records USING btree (player_id, opponent_id, created_at DESC);


--
-- Name: club_memberships club_memberships_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.club_memberships
    ADD CONSTRAINT club_memberships_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;


--
-- Name: club_memberships club_memberships_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.club_memberships
    ADD CONSTRAINT club_memberships_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: elo_history elo_history_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elo_history
    ADD CONSTRAINT elo_history_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;


--
-- Name: elo_history elo_history_match_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elo_history
    ADD CONSTRAINT elo_history_match_record_id_fkey FOREIGN KEY (match_record_id) REFERENCES public.match_records(id) ON DELETE CASCADE;


--
-- Name: elo_history elo_history_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.elo_history
    ADD CONSTRAINT elo_history_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: clubs fk_owner; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clubs
    ADD CONSTRAINT fk_owner FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: league_standings league_standings_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_standings
    ADD CONSTRAINT league_standings_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: league_standings league_standings_tournament_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.league_standings
    ADD CONSTRAINT league_standings_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE;


--
-- Name: match_disputes match_disputes_match_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_disputes
    ADD CONSTRAINT match_disputes_match_record_id_fkey FOREIGN KEY (match_record_id) REFERENCES public.match_records(id) ON DELETE CASCADE;


--
-- Name: match_disputes match_disputes_raised_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_disputes
    ADD CONSTRAINT match_disputes_raised_by_fkey FOREIGN KEY (raised_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_disputes match_disputes_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_disputes
    ADD CONSTRAINT match_disputes_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: match_records match_records_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;


--
-- Name: match_records match_records_opponent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_opponent_id_fkey FOREIGN KEY (opponent_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_records match_records_opponent_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_opponent_partner_id_fkey FOREIGN KEY (opponent_partner_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: match_records match_records_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: match_records match_records_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: match_records match_records_t_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_t_match_id_fkey FOREIGN KEY (t_match_id) REFERENCES public.t_matches(id) ON DELETE SET NULL;


--
-- Name: match_records match_records_verified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.match_records
    ADD CONSTRAINT match_records_verified_by_id_fkey FOREIGN KEY (verified_by_id) REFERENCES public.users(id);


--
-- Name: player_badges player_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_badges
    ADD CONSTRAINT player_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.badges(id);


--
-- Name: player_badges player_badges_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_badges
    ADD CONSTRAINT player_badges_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: player_profiles player_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_profiles
    ADD CONSTRAINT player_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: season_snapshots season_snapshots_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.season_snapshots
    ADD CONSTRAINT season_snapshots_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id);


--
-- Name: season_snapshots season_snapshots_season_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.season_snapshots
    ADD CONSTRAINT season_snapshots_season_id_fkey FOREIGN KEY (season_id) REFERENCES public.seasons(id);


--
-- Name: seasons seasons_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id);


--
-- Name: squad_verifications squad_verifications_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.squad_verifications
    ADD CONSTRAINT squad_verifications_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: squad_verifications squad_verifications_t_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.squad_verifications
    ADD CONSTRAINT squad_verifications_t_match_id_fkey FOREIGN KEY (t_match_id) REFERENCES public.t_matches(id) ON DELETE CASCADE;


--
-- Name: t_matches t_matches_match_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_matches
    ADD CONSTRAINT t_matches_match_record_id_fkey FOREIGN KEY (match_record_id) REFERENCES public.match_records(id) ON DELETE SET NULL;


--
-- Name: t_matches t_matches_player_1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_matches
    ADD CONSTRAINT t_matches_player_1_id_fkey FOREIGN KEY (player_1_id) REFERENCES public.users(id);


--
-- Name: t_matches t_matches_player_2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_matches
    ADD CONSTRAINT t_matches_player_2_id_fkey FOREIGN KEY (player_2_id) REFERENCES public.users(id);


--
-- Name: t_matches t_matches_tournament_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.t_matches
    ADD CONSTRAINT t_matches_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE;


--
-- Name: tournaments tournaments_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tournaments
    ADD CONSTRAINT tournaments_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.clubs(id) ON DELETE CASCADE;


--
-- Name: match_records; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.match_records ENABLE ROW LEVEL SECURITY;

--
-- Name: tournaments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict dyEhKLKwyABhKSAlLPEUKi7c9e2LyQ2HGHwsLpVab8jDdDMkhmwqkEhx35tycqx

