ALTER TABLE public.donations
ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'Other';

ALTER TABLE public.donations
DROP CONSTRAINT IF EXISTS donations_category_check;

ALTER TABLE public.donations
ADD CONSTRAINT donations_category_check
CHECK (
  category IN (
    'Bakery',
    'Fruits & vegetables',
    'Dairy',
    'Meat & fish',
    'Prepared meals',
    'Groceries',
    'Other'
  )
);
