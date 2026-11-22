SET search_path TO pikalov_food, exts, public;

CREATE OR REPLACE FUNCTION sync_order_pay_status()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_order uuid; v_new pay_status;
BEGIN
  IF TG_OP='DELETE' THEN v_order := OLD.order_id;
  ELSE v_order := NEW.order_id;
  END IF;
  SELECT CASE
    WHEN count(*) FILTER (WHERE status='успех') > 0 THEN 'оплачен'::pay_status
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
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;

CREATE OR REPLACE FUNCTION rating_change()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_type review_entity_type; v_id uuid;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    v_type := OLD.entity_type; v_id := OLD.entity_id;
    IF v_type='блюдо' THEN
      UPDATE product SET rating=(SELECT round(avg(rating),2) FROM review WHERE entity_type='блюдо' AND entity_id=v_id)
      WHERE product_id=v_id;
    ELSIF v_type='ресторан' THEN
      UPDATE restaurant SET rating=(SELECT round(avg(rating),2) FROM review WHERE entity_type='ресторан' AND entity_id=v_id)
      WHERE restaurant_id=v_id;
    END IF;
  END IF;
  IF TG_OP <> 'DELETE' THEN
    IF TG_OP='UPDATE' AND OLD.entity_type=NEW.entity_type AND OLD.entity_id=NEW.entity_id THEN
      v_type := NULL;
    ELSE
      v_type := NEW.entity_type; v_id := NEW.entity_id;
    END IF;
    IF v_type='блюдо' THEN
      UPDATE product SET rating=(SELECT round(avg(rating),2) FROM review WHERE entity_type='блюдо' AND entity_id=v_id)
      WHERE product_id=v_id;
    ELSIF v_type='ресторан' THEN
      UPDATE restaurant SET rating=(SELECT round(avg(rating),2) FROM review WHERE entity_type='ресторан' AND entity_id=v_id)
      WHERE restaurant_id=v_id;
    END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
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
orders_monthly AS (
  SELECT date_trunc('month',order_timestamp)::date month_start,
         sum(order_amount)::numeric sum_no_commission,
         sum(total_amount)::numeric sum_with_commission,
         sum(commission)::numeric commission
  FROM "order" WHERE status='доставлен' GROUP BY 1
),
pay_monthly AS (
  SELECT make_date(year,month,1) month_start,sum(amount)::numeric courier_pay
  FROM courier_pay GROUP BY year,month
),
monthly AS (
  SELECT to_char(m.month_start,'YYYY-MM') year_month,
         coalesce(o.sum_no_commission,0)::numeric sum_no_commission,
         coalesce(o.sum_with_commission,0)::numeric sum_with_commission,
         coalesce(o.commission,0)::numeric commission,
         coalesce(p.courier_pay,0)::numeric courier_pay
  FROM months m LEFT JOIN orders_monthly o USING(month_start)
  LEFT JOIN pay_monthly p USING(month_start)
),
with_prev AS (
  SELECT *,lag(commission) OVER(ORDER BY year_month) prev_commission FROM monthly
)
SELECT year_month,sum_no_commission,sum_with_commission,commission,prev_commission,
       commission-prev_commission commission_diff,courier_pay,commission-courier_pay net_profit
FROM with_prev;
