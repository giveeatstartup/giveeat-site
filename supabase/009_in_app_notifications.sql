-- GiveEat in-app notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  donation_id uuid REFERENCES public.donations(id) ON DELETE SET NULL,
  reservation_id uuid REFERENCES public.reservations(id) ON DELETE SET NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can mark own notifications as read" ON public.notifications;
CREATE POLICY "Users can mark own notifications as read"
ON public.notifications FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;

-- New donations notify every registered association.
CREATE OR REPLACE FUNCTION public.notify_associations_of_new_donation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, message, donation_id)
  SELECT p.id, 'new_donation', 'New food donation available',
         NEW.business_name || ' published: ' || NEW.description,
         NEW.id
  FROM public.profiles p
  WHERE p.role = 'association';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_associations_after_donation_insert ON public.donations;
CREATE TRIGGER notify_associations_after_donation_insert
AFTER INSERT ON public.donations
FOR EACH ROW EXECUTE FUNCTION public.notify_associations_of_new_donation();

-- A reservation notifies the business that owns the donation.
CREATE OR REPLACE FUNCTION public.notify_business_of_reservation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  business_user_id uuid;
  donation_description text;
BEGIN
  SELECT d.business_id, d.description
  INTO business_user_id, donation_description
  FROM public.donations d
  WHERE d.id = NEW.donation_id;

  IF business_user_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, message, donation_id, reservation_id)
    VALUES (business_user_id, 'reservation_created', 'Your donation was reserved',
            'An association reserved: ' || COALESCE(donation_description, 'your donation'),
            NEW.donation_id, NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_business_after_reservation_insert ON public.reservations;
CREATE TRIGGER notify_business_after_reservation_insert
AFTER INSERT ON public.reservations
FOR EACH ROW
WHEN (NEW.status = 'reserved')
EXECUTE FUNCTION public.notify_business_of_reservation();

-- A cancellation notifies the business.
CREATE OR REPLACE FUNCTION public.notify_business_of_cancellation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  business_user_id uuid;
  donation_description text;
BEGIN
  SELECT d.business_id, d.description
  INTO business_user_id, donation_description
  FROM public.donations d
  WHERE d.id = NEW.donation_id;

  IF business_user_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, message, donation_id, reservation_id)
    VALUES (business_user_id, 'reservation_cancelled', 'A reservation was cancelled',
            'The association cancelled its reservation for: ' || COALESCE(donation_description, 'your donation'),
            NEW.donation_id, NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_business_after_reservation_cancelled ON public.reservations;
CREATE TRIGGER notify_business_after_reservation_cancelled
AFTER UPDATE OF status ON public.reservations
FOR EACH ROW
WHEN (OLD.status = 'reserved' AND NEW.status = 'cancelled')
EXECUTE FUNCTION public.notify_business_of_cancellation();

-- When a business marks a reserved donation as collected, notify the association.
CREATE OR REPLACE FUNCTION public.notify_association_of_collection()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  reserved_row record;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'collected' THEN
    SELECT r.id, r.association_id
    INTO reserved_row
    FROM public.reservations r
    WHERE r.donation_id = NEW.id AND r.status = 'reserved'
    ORDER BY r.created_at DESC
    LIMIT 1;

    IF reserved_row.association_id IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, type, title, message, donation_id, reservation_id)
      VALUES (reserved_row.association_id, 'donation_collected', 'Donation marked as collected',
              'The business marked "' || NEW.description || '" as collected.',
              NEW.id, reserved_row.id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_association_after_donation_collected ON public.donations;
CREATE TRIGGER notify_association_after_donation_collected
AFTER UPDATE OF status ON public.donations
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'collected')
EXECUTE FUNCTION public.notify_association_of_collection();

-- Trigger functions are called by database triggers, not directly by app users.
REVOKE ALL ON FUNCTION public.notify_associations_of_new_donation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_business_of_reservation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_business_of_cancellation() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_association_of_collection() FROM PUBLIC, anon, authenticated;
