-- Test query to check category data
SELECT id, name, category_type, updated_at, typeof(updated_at) as updated_at_type
FROM categories 
LIMIT 1;
