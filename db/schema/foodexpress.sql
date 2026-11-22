-- FoodExpress physical schema
-- PostgreSQL 15+. Run after the instructor-provided exts schema and uuid-ossp extension exist.
CREATE SCHEMA IF NOT EXISTS pikalov_food;
SET search_path TO pikalov_food, exts, public;

CREATE TYPE restaurant_status AS ENUM ('активен','неактивен');
CREATE TYPE product_status AS ENUM ('доступно','нет_в_наличии','архив');
CREATE TYPE courier_status AS ENUM ('свободен','занят','на_доставке','уволен');
CREATE TYPE order_status AS ENUM ('создан','готовится','в_доставке','доставлен','отменён');
CREATE TYPE pay_status AS ENUM ('ожидает','оплачен','ошибка');
CREATE TYPE payment_status AS ENUM ('успех','ошибка','в_обработке');
CREATE TYPE payment_type AS ENUM ('карта','наличные','безнал');
CREATE TYPE review_entity_type AS ENUM ('блюдо','ресторан','заказ');

CREATE TABLE client (
  client_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  login varchar(50) NOT NULL UNIQUE CHECK (length(login) BETWEEN 1 AND 50),
  password varchar(32) NOT NULL CHECK (password ~ '^[0-9a-f]{32}$'),
  phone_number char(12) NOT NULL UNIQUE CHECK (btrim(phone_number) <> '')
);

CREATE TABLE address (
  address_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  street varchar(100) NOT NULL CHECK (length(street) BETWEEN 1 AND 100),
  house_number varchar(15) NOT NULL CHECK (length(house_number) BETWEEN 1 AND 15),
  apartment_office varchar(15) CHECK (apartment_office IS NULL OR length(apartment_office) BETWEEN 1 AND 15),
  UNIQUE (street, house_number, apartment_office)
);

CREATE TABLE client_address (
  client_id uuid NOT NULL REFERENCES client(client_id) ON DELETE RESTRICT,
  address_id uuid NOT NULL REFERENCES address(address_id) ON DELETE RESTRICT,
  PRIMARY KEY (client_id,address_id)
);

CREATE TABLE restaurant (
  restaurant_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  restaurant_name varchar(100) NOT NULL CHECK (length(restaurant_name) BETWEEN 1 AND 100),
  address_id uuid NOT NULL UNIQUE REFERENCES address(address_id) ON DELETE RESTRICT,
  description text NOT NULL,
  work_start time NOT NULL,
  work_end time NOT NULL,
  company_details text NOT NULL,
  rating numeric(3,2) CHECK (rating BETWEEN 0 AND 5),
  status restaurant_status NOT NULL DEFAULT 'активен',
  CHECK (work_end > work_start),
  UNIQUE (restaurant_id,address_id)
);

CREATE TABLE courier (
  courier_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  fio varchar(150) NOT NULL CHECK (length(fio) BETWEEN 1 AND 150),
  phone_number char(12) NOT NULL UNIQUE CHECK (btrim(phone_number) <> ''),
  status courier_status NOT NULL DEFAULT 'свободен',
  hire_date date NOT NULL,
  dismissal_date date,
  coefficient numeric(2,1) NOT NULL DEFAULT 0.1 CHECK (coefficient BETWEEN 0.1 AND 0.5),
  CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
  CHECK ((status <> 'уволен') OR dismissal_date IS NOT NULL)
);

CREATE TABLE courier_pay (
  year integer NOT NULL CHECK (year BETWEEN 2000 AND 2100),
  month integer NOT NULL CHECK (month BETWEEN 1 AND 12),
  courier_id uuid NOT NULL REFERENCES courier(courier_id) ON DELETE RESTRICT,
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  coefficient_used numeric(2,1) NOT NULL CHECK (coefficient_used BETWEEN 0.1 AND 0.5),
  PRIMARY KEY (year,month,courier_id)
);

CREATE TABLE product_category (
  product_category_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  product_category_name varchar(80) NOT NULL UNIQUE CHECK (length(product_category_name) BETWEEN 1 AND 80)
);

CREATE TABLE product (
  product_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  product_name varchar(120) NOT NULL CHECK (length(product_name) BETWEEN 1 AND 120),
  product_category_id uuid NOT NULL REFERENCES product_category(product_category_id) ON DELETE RESTRICT,
  price numeric(12,2) NOT NULL CHECK (price >= 0),
  restaurant_id uuid NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE RESTRICT,
  photo_url text,
  rating numeric(3,2) CHECK (rating BETWEEN 0 AND 5),
  status product_status NOT NULL DEFAULT 'доступно',
  description text NOT NULL,
  UNIQUE (product_id,restaurant_id)
);

CREATE TABLE "order" (
  order_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  courier_id uuid NOT NULL REFERENCES courier(courier_id) ON DELETE RESTRICT,
  client_id uuid NOT NULL,
  address_id uuid NOT NULL,
  restaurant_id uuid NOT NULL REFERENCES restaurant(restaurant_id) ON DELETE RESTRICT,
  order_timestamp timestamp NOT NULL DEFAULT localtimestamp,
  delivery_timestamp timestamp,
  order_amount numeric(14,2) NOT NULL CHECK (order_amount >= 0),
  commission numeric(14,2) NOT NULL CHECK (commission = round(order_amount * 0.10,2)),
  total_amount numeric(14,2) NOT NULL CHECK (total_amount = round(order_amount + commission,2) AND total_amount >= 1000),
  status order_status NOT NULL DEFAULT 'создан',
  pay_status pay_status NOT NULL DEFAULT 'ожидает',
  description text NOT NULL,
  CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp),
  CHECK ((status <> 'доставлен') OR delivery_timestamp IS NOT NULL),
  FOREIGN KEY (client_id,address_id) REFERENCES client_address(client_id,address_id) ON DELETE RESTRICT,
  UNIQUE (order_id,restaurant_id)
);

CREATE TABLE order_structure (
  order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  restaurant_id uuid NOT NULL,
  quantity numeric(10,3) NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (order_id,product_id),
  FOREIGN KEY (order_id,restaurant_id) REFERENCES "order"(order_id,restaurant_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id,restaurant_id) REFERENCES product(product_id,restaurant_id) ON DELETE RESTRICT
);

CREATE TABLE payment (
  payment_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  order_id uuid NOT NULL REFERENCES "order"(order_id) ON DELETE CASCADE,
  payment_type payment_type NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  transaction_id varchar(100) NOT NULL UNIQUE CHECK (length(transaction_id) BETWEEN 1 AND 100),
  transaction_timestamp timestamp NOT NULL DEFAULT localtimestamp,
  status payment_status NOT NULL,
  UNIQUE (payment_id,order_id)
);
CREATE UNIQUE INDEX payment_one_success_per_order ON payment(order_id) WHERE status = 'успех';

CREATE TABLE review (
  review_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
  client_id uuid NOT NULL REFERENCES client(client_id) ON DELETE RESTRICT,
  review_timestamp timestamp NOT NULL DEFAULT localtimestamp,
  entity_id uuid NOT NULL,
  entity_type review_entity_type NOT NULL,
  order_id uuid NOT NULL REFERENCES "order"(order_id) ON DELETE CASCADE,
  description text NOT NULL,
  photo_url text,
  rating numeric(2,1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
  UNIQUE (order_id,entity_type,entity_id)
);

CREATE INDEX order_restaurant_status_idx ON "order"(restaurant_id,status);
CREATE INDEX order_courier_timestamp_idx ON "order"(courier_id,order_timestamp);
CREATE INDEX payment_order_idx ON payment(order_id);
CREATE INDEX review_entity_idx ON review(entity_type,entity_id);

-- Cross-row business rules that cannot be expressed as ordinary CHECK/FK constraints.
CREATE OR REPLACE FUNCTION validate_payment_consistency()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_total numeric(14,2);
BEGIN
  SELECT total_amount INTO v_total FROM "order" WHERE order_id = NEW.order_id;
  IF v_total IS NULL THEN RAISE EXCEPTION 'Заказ % не найден', NEW.order_id; END IF;
  IF NEW.amount <> v_total THEN RAISE EXCEPTION 'Сумма платежа должна совпадать с total_amount заказа'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER payment_consistency_trg
BEFORE INSERT OR UPDATE ON payment
FOR EACH ROW EXECUTE FUNCTION validate_payment_consistency();

CREATE OR REPLACE FUNCTION validate_review_target()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_client uuid; v_restaurant uuid; v_exists boolean;
BEGIN
  SELECT client_id,restaurant_id INTO v_client,v_restaurant
  FROM "order" WHERE order_id=NEW.order_id;
  IF v_client IS NULL THEN RAISE EXCEPTION 'Заказ отзыва не найден'; END IF;
  IF v_client <> NEW.client_id THEN RAISE EXCEPTION 'Отзыв может оставить только клиент заказа'; END IF;
  IF NEW.entity_type='заказ' THEN
    IF NEW.entity_id <> NEW.order_id THEN RAISE EXCEPTION 'entity_id отзыва на заказ должен совпадать с order_id'; END IF;
  ELSIF NEW.entity_type='ресторан' THEN
    IF NEW.entity_id <> v_restaurant THEN RAISE EXCEPTION 'Ресторан отзыва должен совпадать с рестораном заказа'; END IF;
  ELSIF NEW.entity_type='блюдо' THEN
    SELECT EXISTS(SELECT 1 FROM order_structure WHERE order_id=NEW.order_id AND product_id=NEW.entity_id) INTO v_exists;
    IF NOT v_exists THEN RAISE EXCEPTION 'Нельзя оставить отзыв на блюдо, которого нет в заказе'; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER review_target_trg
BEFORE INSERT OR UPDATE ON review
FOR EACH ROW EXECUTE FUNCTION validate_review_target();

CREATE OR REPLACE FUNCTION sync_order_pay_status()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_order uuid; v_new pay_status;
BEGIN
  v_order := COALESCE(NEW.order_id,OLD.order_id);
  SELECT CASE
    WHEN bool_or(status='успех') THEN 'оплачен'::pay_status
    WHEN count(*) FILTER (WHERE status='в_обработке') > 0 THEN 'ожидает'::pay_status
    WHEN count(*) > 0 AND bool_and(status='ошибка') THEN 'ошибка'::pay_status
    ELSE 'ожидает'::pay_status END
  INTO v_new FROM payment WHERE order_id=v_order;
  UPDATE "order" SET pay_status=v_new WHERE order_id=v_order;
  IF TG_OP='UPDATE' AND OLD.order_id IS DISTINCT FROM NEW.order_id THEN
    UPDATE "order" SET pay_status=CASE
      WHEN EXISTS(SELECT 1 FROM payment WHERE order_id=OLD.order_id AND status='успех') THEN 'оплачен'::pay_status
      WHEN EXISTS(SELECT 1 FROM payment WHERE order_id=OLD.order_id AND status='в_обработке') THEN 'ожидает'::pay_status
      WHEN EXISTS(SELECT 1 FROM payment WHERE order_id=OLD.order_id) THEN 'ошибка'::pay_status
      ELSE 'ожидает'::pay_status END WHERE order_id=OLD.order_id;
  END IF;
  RETURN COALESCE(NEW,OLD);
END $$;
CREATE TRIGGER payment_pay_status_trg
AFTER INSERT OR UPDATE OR DELETE ON payment
FOR EACH ROW EXECUTE FUNCTION sync_order_pay_status();

CREATE OR REPLACE FUNCTION rating_change()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT DISTINCT entity_type,entity_id
    FROM (VALUES
      (CASE WHEN TG_OP <> 'INSERT' THEN OLD.entity_type END, CASE WHEN TG_OP <> 'INSERT' THEN OLD.entity_id END),
      (CASE WHEN TG_OP <> 'DELETE' THEN NEW.entity_type END, CASE WHEN TG_OP <> 'DELETE' THEN NEW.entity_id END)
    ) AS x(entity_type,entity_id)
    WHERE entity_type IS NOT NULL
  LOOP
    IF r.entity_type='блюдо' THEN
      UPDATE product SET rating=(SELECT round(avg(rating),2) FROM review WHERE entity_type='блюдо' AND entity_id=r.entity_id)
      WHERE product_id=r.entity_id;
    ELSIF r.entity_type='ресторан' THEN
      UPDATE restaurant SET rating=(SELECT round(avg(rating),2) FROM review WHERE entity_type='ресторан' AND entity_id=r.entity_id)
      WHERE restaurant_id=r.entity_id;
    END IF;
  END LOOP;
  RETURN COALESCE(NEW,OLD);
END $$;
CREATE TRIGGER review_rating_trg
AFTER INSERT OR UPDATE OR DELETE ON review
FOR EACH ROW EXECUTE FUNCTION rating_change();

CREATE OR REPLACE FUNCTION add_product(
  p_restaurant_id uuid,
  p_product_category_id uuid,
  p_name varchar,
  p_price numeric,
  p_rating numeric,
  p_status product_status,
  p_description text,
  p_photo_url text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM restaurant WHERE restaurant_id=p_restaurant_id) THEN
    RAISE EXCEPTION 'Ресторан % не существует',p_restaurant_id;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM product_category WHERE product_category_id=p_product_category_id) THEN
    RAISE EXCEPTION 'Категория % не существует',p_product_category_id;
  END IF;
  INSERT INTO product(restaurant_id,product_category_id,product_name,price,rating,status,description,photo_url)
  VALUES(p_restaurant_id,p_product_category_id,p_name,p_price,p_rating,p_status,p_description,p_photo_url);
END $$;

CREATE OR REPLACE FUNCTION get_statistic()
RETURNS TABLE(restaurant_name varchar,best_product_name varchar,total_amount numeric,avg_amount numeric,best_user varchar)
LANGUAGE sql STABLE AS $$
WITH delivered AS (
  SELECT o.order_id,o.restaurant_id,o.client_id,o.total_amount
  FROM "order" o WHERE o.status='доставлен'
),
sales AS (
  SELECT d.restaurant_id,p.product_name,sum(os.quantity) qty
  FROM delivered d JOIN order_structure os USING(order_id)
  JOIN product p USING(product_id)
  GROUP BY d.restaurant_id,p.product_name
),
best_products AS (
  SELECT DISTINCT ON (restaurant_id) restaurant_id,product_name
  FROM sales ORDER BY restaurant_id,qty DESC,random()
),
users AS (
  SELECT restaurant_id,c.login,count(*) orders_count
  FROM delivered d JOIN client c USING(client_id)
  GROUP BY restaurant_id,c.login
),
best_users AS (
  SELECT DISTINCT ON (restaurant_id) restaurant_id,login
  FROM users ORDER BY restaurant_id,orders_count DESC,random()
),
totals AS (
  SELECT restaurant_id,sum(total_amount) total_amount,avg(total_amount) avg_amount
  FROM delivered GROUP BY restaurant_id
)
SELECT r.restaurant_name,bp.product_name,coalesce(t.total_amount,0),t.avg_amount,bu.login
FROM restaurant r LEFT JOIN best_products bp USING(restaurant_id)
LEFT JOIN totals t USING(restaurant_id) LEFT JOIN best_users bu USING(restaurant_id)
$$;

CREATE OR REPLACE PROCEDURE courier_salary()
LANGUAGE plpgsql AS $$
DECLARE c record; v_count integer; v_commission numeric(14,2); v_new numeric(2,1);
BEGIN
  FOR c IN SELECT courier_id,coefficient,status FROM courier LOOP
    SELECT count(*),coalesce(sum(commission),0)
    INTO v_count,v_commission
    FROM "order"
    WHERE courier_id=c.courier_id AND status='доставлен'
      AND date_trunc('month',order_timestamp)=date_trunc('month',localtimestamp);
    INSERT INTO courier_pay(year,month,courier_id,amount,coefficient_used)
    VALUES(extract(year from current_date)::int,extract(month from current_date)::int,
           c.courier_id,round(v_commission*c.coefficient,2),c.coefficient)
    ON CONFLICT(year,month,courier_id) DO UPDATE
      SET amount=excluded.amount,coefficient_used=excluded.coefficient_used;
    IF c.status <> 'уволен' THEN
      v_new := CASE WHEN v_count<=150 THEN 0.1 WHEN v_count<=250 THEN 0.2
                    WHEN v_count<=500 THEN 0.3 ELSE 0.5 END;
      UPDATE courier SET coefficient=v_new WHERE courier_id=c.courier_id;
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE VIEW how_much_money AS
WITH RECURSIVE bounds AS (
  SELECT date_trunc('month',min(order_timestamp))::date first_month,
         date_trunc('month',max(order_timestamp))::date last_month
  FROM "order" WHERE status='доставлен'
),
months(month_start,last_month) AS (
  SELECT first_month,last_month FROM bounds WHERE first_month IS NOT NULL
  UNION ALL
  SELECT (month_start + interval '1 month')::date,last_month
  FROM months WHERE month_start < last_month
),
monthly AS (
  SELECT to_char(m.month_start,'YYYY-MM') year_month,
         coalesce(sum(o.order_amount),0)::numeric sum_no_commission,
         coalesce(sum(o.total_amount),0)::numeric sum_with_commission,
         coalesce(sum(o.commission),0)::numeric commission,
         coalesce(sum(cp.amount),0)::numeric courier_pay
  FROM months m
  LEFT JOIN "order" o ON o.status='доставлен'
    AND o.order_timestamp >= m.month_start
    AND o.order_timestamp < (m.month_start + interval '1 month')
  LEFT JOIN courier_pay cp ON cp.year=extract(year from m.month_start)::int
    AND cp.month=extract(month from m.month_start)::int
  GROUP BY m.month_start
),
with_prev AS (
  SELECT *,lag(commission) OVER(ORDER BY year_month) prev_commission FROM monthly
)
SELECT year_month,sum_no_commission,sum_with_commission,commission,prev_commission,
       commission-prev_commission commission_diff,courier_pay,commission-courier_pay net_profit
FROM with_prev;

CREATE OR REPLACE PROCEDURE erase_test_data()
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM review;
  DELETE FROM payment;
  DELETE FROM order_structure;
  DELETE FROM courier_pay;
  DELETE FROM "order";
  DELETE FROM client_address;
  DELETE FROM product;
  DELETE FROM restaurant;
  DELETE FROM product_category;
  DELETE FROM courier;
  DELETE FROM client;
  DELETE FROM address;
END $$;

CREATE OR REPLACE PROCEDURE insert_test_data(value integer)
LANGUAGE plpgsql AS $$
DECLARE
  i integer; j integer; k integer; m integer;
  v_client uuid; v_courier uuid; v_rest uuid; v_addr uuid; v_product uuid;
  v_order uuid; v_cat uuid; v_order_ts timestamp; v_status order_status;
  v_amount numeric(14,2); v_comm numeric(14,2); v_coef numeric(2,1);
  v_count integer; v_commission numeric(14,2); v_month date;
  clients uuid[] := ARRAY[]::uuid[];
  couriers uuid[] := ARRAY[]::uuid[];
  restaurants uuid[] := ARRAY[]::uuid[];
  categories uuid[] := ARRAY[]::uuid[];
  client_addresses uuid[] := ARRAY[]::uuid[];
  restaurant_products uuid[] := ARRAY[]::uuid[];
  v_product_price numeric(12,2);
BEGIN
  IF value IS NULL OR value < 1 THEN RAISE EXCEPTION 'value должен быть положительным целым числом'; END IF;
  -- Each call appends a fresh independent batch; no existing rows are deleted.
  FOR i IN 1..value LOOP
    INSERT INTO client(login,password,phone_number)
    VALUES('user_'||substr(replace(exts.uuid_generate_v4()::text,'-',''),1,16),
           md5(random()::text),'+79'||lpad((floor(random()*1000000000)::bigint)::text,9,'0'))
    RETURNING client_id INTO v_client;
    clients := array_append(clients,v_client);

    INSERT INTO courier(fio,phone_number,status,hire_date,dismissal_date,coefficient)
    VALUES('Курьер '||substr(exts.uuid_generate_v4()::text,1,8),
           '+78'||lpad((floor(random()*1000000000)::bigint)::text,9,'0'),
           CASE WHEN i=1 THEN 'свободен'::courier_status
                ELSE (enum_range(NULL::courier_status))[1+floor(random()*3)::int] END,
           current_date-(floor(random()*180)::int),
           NULL,0.1)
    RETURNING courier_id INTO v_courier;
    couriers := array_append(couriers,v_courier);

    INSERT INTO product_category(product_category_name)
    VALUES('Категория '||substr(exts.uuid_generate_v4()::text,1,8))
    RETURNING product_category_id INTO v_cat;
    categories := array_append(categories,v_cat);

    INSERT INTO address(street,house_number,apartment_office)
    VALUES('Улица '||i, i::text, NULL)
    RETURNING address_id INTO v_addr;
    INSERT INTO restaurant(restaurant_name,address_id,description,work_start,work_end,company_details,status)
    VALUES('Ресторан '||i,v_addr,'Описание ресторана '||i,'09:00','22:00',
           'ИНН 0000000000; ОГРН 0000000000000; счёт 00000000000000000000','активен')
    RETURNING restaurant_id INTO v_rest;
    restaurants := array_append(restaurants,v_rest);

    FOR j IN 1..4 LOOP
      INSERT INTO address(street,house_number,apartment_office)
      VALUES('Проспект '||i||'-'||j, (j+10)::text, NULL)
      RETURNING address_id INTO v_addr;
      INSERT INTO client_address(client_id,address_id) VALUES(v_client,v_addr);
      client_addresses := array_append(client_addresses,v_addr);
    END LOOP;

    -- Five dishes per restaurant; price ensures the minimum order threshold.
    FOR j IN 1..5 LOOP
      INSERT INTO product(product_name,product_category_id,price,restaurant_id,status,description)
      VALUES('Блюдо '||i||'-'||j,v_cat,round((1100+random()*900)::numeric,2),v_rest,'доступно',
             'Описание блюда '||i||'-'||j)
      RETURNING product_id INTO v_product;
      restaurant_products := array_append(restaurant_products,v_product);
    END LOOP;
  END LOOP;

  -- Five orders, reviews and payment attempts per client/restaurant batch.
  FOR i IN 1..(value*5) LOOP
    v_client := clients[1+((i-1)/5)];
    v_courier := couriers[1+((i-1)%value)];
    v_rest := restaurants[1+((i-1)/5)];
    v_addr := client_addresses[1+((i-1)/5)*4+((i-1)%4)];
    v_product := restaurant_products[1+((i-1)/5)*5+((i-1)%5)];
    SELECT price INTO v_product_price FROM product WHERE product_id=v_product;
    v_amount := v_product_price;
    v_comm := round(v_amount*0.10,2);
    v_order_ts := localtimestamp - (floor(random()*180)::int * interval '1 day')
                  - (floor(random()*1440)::int * interval '1 minute');
    v_status := (enum_range(NULL::order_status))[1+floor(random()*cardinality(enum_range(NULL::order_status)))::int];
    IF v_status='доставлен' THEN
      INSERT INTO "order"(courier_id,client_id,address_id,restaurant_id,order_timestamp,delivery_timestamp,
                          order_amount,commission,total_amount,status,pay_status,description)
      VALUES(v_courier,v_client,v_addr,v_rest,v_order_ts,v_order_ts+interval '30 minutes',
             v_amount,v_comm,v_amount+v_comm,v_status,'оплачен','Тестовый заказ')
      RETURNING order_id INTO v_order;
    ELSE
      INSERT INTO "order"(courier_id,client_id,address_id,restaurant_id,order_timestamp,delivery_timestamp,
                          order_amount,commission,total_amount,status,pay_status,description)
      VALUES(v_courier,v_client,v_addr,v_rest,v_order_ts,NULL,
             v_amount,v_comm,v_amount+v_comm,v_status,'оплачен','Тестовый заказ')
      RETURNING order_id INTO v_order;
    END IF;
    INSERT INTO order_structure(order_id,product_id,restaurant_id,quantity)
    VALUES(v_order,v_product,v_rest,1);
    INSERT INTO payment(order_id,payment_type,amount,transaction_id,transaction_timestamp,status)
    VALUES(v_order,(enum_range(NULL::payment_type))[1+floor(random()*3)::int],
           v_amount+v_comm,'tx_'||replace(exts.uuid_generate_v4()::text,'-',''),v_order_ts,'успех');
    INSERT INTO review(client_id,review_timestamp,entity_id,entity_type,order_id,description,rating)
    VALUES(v_client,v_order_ts+interval '1 hour',
           CASE WHEN i%3=0 THEN v_order WHEN i%3=1 THEN v_product ELSE v_rest END,
           CASE WHEN i%3=0 THEN 'заказ'::review_entity_type
                WHEN i%3=1 THEN 'блюдо'::review_entity_type ELSE 'ресторан'::review_entity_type END,
           v_order,'Тестовый отзыв',1+floor(random()*5));
  END LOOP;

  -- Six months of consistent courier_pay history. Coefficient for a month is
  -- the tier determined by the preceding month's delivered-order count.
  FOR i IN 1..value LOOP
    v_coef := 0.1;
    FOR m IN 5..0 BY -1 LOOP
      v_month := (date_trunc('month',current_date) - (m||' months')::interval)::date;
      SELECT count(*),coalesce(sum(commission),0) INTO v_count,v_commission
      FROM "order" WHERE courier_id=couriers[i] AND status='доставлен'
        AND order_timestamp >= v_month AND order_timestamp < (v_month+interval '1 month');
      INSERT INTO courier_pay(year,month,courier_id,amount,coefficient_used)
      VALUES(extract(year from v_month)::int,extract(month from v_month)::int,couriers[i],
             round(v_commission*v_coef,2),v_coef)
      ON CONFLICT(year,month,courier_id) DO UPDATE
      SET amount=excluded.amount,coefficient_used=excluded.coefficient_used;
      v_coef := CASE WHEN v_count<=150 THEN 0.1 WHEN v_count<=250 THEN 0.2
                     WHEN v_count<=500 THEN 0.3 ELSE 0.5 END;
    END LOOP;
    UPDATE courier SET coefficient=v_coef WHERE courier_id=couriers[i];
  END LOOP;
END $$;
