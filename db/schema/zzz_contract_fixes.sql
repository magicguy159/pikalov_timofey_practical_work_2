SET search_path TO pikalov_food, exts, public;

-- The backlog specifies CALL add_product(...), therefore expose it as a procedure.
DROP FUNCTION IF EXISTS add_product(uuid,uuid,character varying,numeric,numeric,product_status,text,text);
CREATE OR REPLACE PROCEDURE add_product(
  p_restaurant_id uuid,
  p_product_category_id uuid,
  p_name varchar,
  p_price numeric,
  p_rating numeric,
  p_status product_status,
  p_description text,
  p_photo_url text DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id=p_restaurant_id) THEN
    RAISE EXCEPTION 'Ресторан % не существует',p_restaurant_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM product_category WHERE product_category_id=p_product_category_id) THEN
    RAISE EXCEPTION 'Категория % не существует',p_product_category_id;
  END IF;
  INSERT INTO product(restaurant_id,product_category_id,product_name,price,rating,status,description,photo_url)
  VALUES(p_restaurant_id,p_product_category_id,p_name,p_price,p_rating,p_status,p_description,p_photo_url);
END $$;
