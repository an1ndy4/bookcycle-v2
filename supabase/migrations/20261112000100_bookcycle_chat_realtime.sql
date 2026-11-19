-- BookCycle Chat Realtime + participant-only access.
-- This migration reflects the configuration already applied to the live project.

BEGIN;

ALTER TABLE public.chat ENABLE ROW LEVEL SECURITY;

-- Do not expose chat through the anon role. Authenticated users can read
-- conversations they participate in, insert their own messages, and update
-- only the read-receipt column.
REVOKE ALL PRIVILEGES ON TABLE public.chat FROM anon, authenticated;

GRANT SELECT ON TABLE public.chat TO authenticated;
GRANT INSERT (pengirim_id, penerima_id, buku_id, pesan)
  ON TABLE public.chat TO authenticated;
GRANT UPDATE (sudah_dibaca)
  ON TABLE public.chat TO authenticated;

DROP POLICY IF EXISTS "User bisa kirim pesan" ON public.chat;
DROP POLICY IF EXISTS "User bisa lihat pesan sendiri" ON public.chat;
DROP POLICY IF EXISTS "User bisa update status baca pesan" ON public.chat;
DROP POLICY IF EXISTS "chat_participants_can_read" ON public.chat;
DROP POLICY IF EXISTS "chat_sender_can_insert" ON public.chat;
DROP POLICY IF EXISTS "chat_recipient_can_mark_read" ON public.chat;

CREATE POLICY "chat_participants_can_read"
ON public.chat
FOR SELECT
TO authenticated
USING (
  (SELECT auth.uid()) IN (
    SELECT u.auth_id
    FROM public.users AS u
    WHERE u.user_id IN (chat.pengirim_id, chat.penerima_id)
      AND u.auth_id IS NOT NULL
  )
);

CREATE POLICY "chat_sender_can_insert"
ON public.chat
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.users AS sender
    WHERE sender.user_id = chat.pengirim_id
      AND sender.auth_id = (SELECT auth.uid())
  )
);

CREATE POLICY "chat_recipient_can_mark_read"
ON public.chat
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.users AS recipient
    WHERE recipient.user_id = chat.penerima_id
      AND recipient.auth_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  sudah_dibaca = true
  AND EXISTS (
    SELECT 1
    FROM public.users AS recipient
    WHERE recipient.user_id = chat.penerima_id
      AND recipient.auth_id = (SELECT auth.uid())
  )
);

-- Add only the chat table to the existing publication.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat;
  END IF;
END
$$;

COMMIT;
