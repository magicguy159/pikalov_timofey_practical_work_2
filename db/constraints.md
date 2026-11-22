# Обоснование ограничений

## Enum-типы
| Тип | Значения | BR |
|---|---|---|
| restaurant_status | активен, неактивен | BR-4.3 |
| product_status | доступно, нет_в_наличии, архив | BR-5.5 |
| courier_status | свободен, занят, на_доставке, уволен | BR-6.2 |
| order_status | создан, готовится, в_доставке, доставлен, отменён | BR-7.7 |
| pay_status | ожидает, оплачен, ошибка | BR-7.9 |
| payment_status | успех, ошибка, в_обработке | BR-8.2 |
| payment_type | карта, наличные, безнал | BR-8.2 |
| review_entity_type | блюдо, ресторан, заказ | BR-9.1 |

## Решения по ловушкам
1. **payment:** добавлены тип, сумма, внешний transaction_id, timestamp и статус попытки; тип хранится в payment (BR-8.2, BR-8.6). Частичный уникальный индекс допускает не более одной успешной попытки (BR-8.1).
2. **Адрес заказа:** составной FK (client_id,address_id) → client_address гарантирует, что адрес принадлежит клиенту (BR-7.4).
3. **Ресторан в позициях заказа:** order_structure содержит restaurant_id и два составных FK к order и product; пара ресторан/заказ и ресторан/блюдо должна совпадать (BR-7.3).
4. **review.entity_id:** полиморфная ссылка; BEFORE-триггер проверяет тип цели, заказ, клиента и наличие блюда в заказе (BR-9.1—9.2). Один обычный FK не может ссылаться на три таблицы.

## CHECK
| Таблица | Условие | BR | Обоснование |
|---|---|---|---|
| client | login непустой; password — 32 hex; phone непустой | BR-2.1—2.3 | реквизиты регистрации и MD5 |
| address | street и house_number непустые | BR-3.1—3.2 | обязательные части адреса |
| restaurant | work_end > work_start; rating 0..5 | BR-4.2, BR-4.4 | диапазон рейтинга и график |
| courier | coefficient 0.1..0.5; dismissal_date >= hire_date; уволен => дата | BR-6.3—6.5 | даты и диапазон коэффициента |
| courier_pay | month 1..12; amount >=0; coefficient_used 0.1..0.5 | BR-10.2—10.4 | корректность выплаты |
| product | price >=0; rating 0..5 | BR-5.3—5.4 | бизнес-диапазоны |
| "order" | amount >=0; commission=10%; total=amount+commission и >=1000; delivery>=created | BR-1.4, BR-1.8, BR-7.10—7.13 | суммы и даты заказа |
| "order" | delivered => delivery_timestamp задан | BR-7.12 | время окончания доставки обязательно |
| order_structure | quantity >0 | BR-7.15 | положительное количество |
| payment | amount >0 и равно total заказа (равенство проверяет триггер) | BR-8.2, BR-8.4 | корректная сумма платежа |
| review | rating 1..5 | BR-9.4 | диапазон рейтинга отзыва |

## UNIQUE
| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| client | login | BR-2.2 | логин уникален |
| client | phone_number | BR-2.2 | телефон уникален |
| restaurant | address_id | BR-3.3 | рестораны не делят адрес |
| courier | phone_number | BR-6.1 | уникальный телефон сотрудника |
| payment | transaction_id | BR-8.3 | внешний ID транзакции уникален |
| payment WHERE status='успех' | order_id | BR-8.1 | не более одной успешной попытки |
| courier_pay | year,month,courier_id | BR-10.3 | одна выплата в месяц |
| client_address | client_id,address_id | BR-2.5 | нет повторной привязки |
| order_structure | order_id,product_id | BR-7.16 | блюдо не дублируется |
| review | order_id,entity_type,entity_id | BR-9.5 | один отзыв на объект в заказе |

## FK
| Таблица | Столбцы | → Таблица | BR |
|---|---|---|---|
| client_address | client_id | client | BR-2.4 |
| client_address | address_id | address | BR-2.4 |
| restaurant | address_id | address | BR-3.3 |
| courier_pay | courier_id | courier | BR-10.2 |
| product | product_category_id | product_category | BR-5.1 |
| product | restaurant_id | restaurant | BR-5.1 |
| "order" | courier_id | courier | BR-7.5 |
| "order" | restaurant_id | restaurant | BR-7.2 |
| "order" | client_id,address_id | client_address | BR-7.4 |
| order_structure | order_id,restaurant_id | "order" | BR-7.3 |
| order_structure | product_id,restaurant_id | product | BR-7.3 |
| payment | order_id | "order" | BR-8.1 |
| review | client_id | client | BR-9.2 |
| review | order_id | "order" | BR-9.2 |

## NULL
- address.apartment_office — BR-3.2, квартира/офис необязательны.
- restaurant.rating и product.rating — BR-9.6, до отзывов среднее отсутствует.
- courier.dismissal_date — BR-6.3, работающий курьер не имеет даты увольнения.
- "order".delivery_timestamp — BR-7.12, до завершения доставки пусто.
- product.photo_url и review.photo_url — BR-5.6, BR-9.3, фото необязательно.
- review.description — BR-9.3, текст отзыва необязателен.

## DEFAULT / GENERATED
- UUID по умолчанию через exts.uuid_generate_v4() — BR-11.1.
- Времена создания заказа и транзакции по умолчанию localtimestamp — BR-11.2.
- coefficient курьера по умолчанию 0.1 — BR-6.5.
- commission и total_amount хранятся явно, контролируются CHECK для аудируемости — BR-7.10.

## Нормализация (3НФ)
Атомарные данные разделены по сущностям; связи M:N вынесены в client_address и order_structure. Непервичные атрибуты зависят от полного ключа, транзитивные зависимости в справочниках отсутствуют. commission и total_amount — производные значения, сохранены для аудита и защищены CHECK. product.rating и restaurant.rating — осознанная денормализация, поддерживаемая триггером. review.entity_id — полиморфная ссылка, валидируемая триггером.
