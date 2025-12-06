### 분석쿼리 0-1
```sql
/*
  분석 쿼리 0-1: 데이터 무결성 및 수량 확인
  - 전체 레코드 수와 고유 ID 수를 비교하여 데이터 중복 여부 검증
*/
SELECT
    COUNT(product_id) AS total_products_in_products_table,
    COUNT(DISTINCT product_id) AS unique_product_id_count,
    CASE
        WHEN COUNT(product_id) = COUNT(DISTINCT product_id) THEN 'SUCCESS: All IDs are Unique'
        ELSE 'FAIL: Duplicate IDs Found'
    END AS integrity_check_result
FROM Products;
```
<img width="697" height="57" alt="image" src="https://github.com/user-attachments/assets/c4dd7c70-13e3-4190-be96-523a82f7cbf5" />

- Products 테이블에 총 1,351개의 상품 레코드가 있으며 모든 product_id가 고유함을 확인하였다.
- 이는 테이블의 기본 키(Primary Key) 무결성이 확보되었음을 의미하며 이후 분석 과정에서 다른 테이블과 JOIN 작업 시 데이터 손실이나 중복 없이 신뢰할 수 있는 결합을 수행할 수 있다.

### 분석쿼리 0-2
```sql
/*
  분석 쿼리 0-2: 핵심 통계량 요약
  - 주요 수치 데이터의 최소, 최대, 평균을 파악하여 이상치 여부 확인
*/
SELECT
    MIN(PR.actual_price) AS min_actual_price,
    MAX(PR.actual_price) AS max_actual_price,
    ROUND(AVG(PR.actual_price), 2) AS avg_actual_price,
   
    MIN(PR.rating) AS min_rating,
    MAX(PR.rating) AS max_rating,
    ROUND(AVG(PR.rating), 2) AS avg_rating
FROM Pricing AS PR
WHERE PR.actual_price IS NOT NULL AND PR.actual_price > 0
    AND PR.rating IS NOT NULL;
```
<img width="508" height="57" alt="image" src="https://github.com/user-attachments/assets/36029489-5def-4e2b-aa90-3709d6f33b93" />

- 상품 가격은 최저 ₹39에서 최고 ₹139,900으로 매우 넓은 범위에 걸쳐 분포하고 있으며 평균 가격은 ₹5,691.18이다.
- 평점은 0점부터 5점까지 모든 범위에 걸쳐 있으며 평균 평점은 4.09점이다.

### 분석쿼리 0-3:
```sql
/*
  분석 쿼리 0-3: Users 테이블 무결성 및 기본 통계
  - 데이터셋에 포함된 총 사용자 수 확인 및 ID 중복 여부 검증
*/
SELECT
    COUNT(user_id) AS total_users_in_table,
    COUNT(DISTINCT user_id) AS unique_user_id_count,
    CASE
        WHEN COUNT(user_id) = COUNT(DISTINCT user_id)
        THEN 'SUCCESS: All IDs are Unique'
        ELSE 'ERROR: Duplicate User IDs Found'
    END AS integrity_check_result
FROM Users;
```
<img width="572" height="57" alt="image" src="https://github.com/user-attachments/assets/6b9dcda5-912f-4fa7-a1ed-de533307b93f" />

- Users 테이블에는 총 1,194명의 사용자 레코드가 있으며 모든 user_id가 고유하여 무결성이 확보되었다.

### 분석쿼리 0-4:
```sql
/*
  분석 쿼리 0-4: Reviews 테이블 기본 통계
  - 총 리뷰 수 및 리뷰 내용의 평균 길이(상세도) 계산
*/
SELECT
    COUNT(review_id) AS total_reviews_recorded,
    ROUND(AVG(LENGTH(review_content)), 0) AS average_review_length_chars
FROM Reviews
WHERE review_content IS NOT NULL;
```
<img width="451" height="58" alt="image" src="https://github.com/user-attachments/assets/f66a4cbe-368f-42f3-bee6-79a62a6e60ec" />

- User 테이블과 마찬가지로 1,194개의 레코드가 있다.
- 이는 User 한사람이 리뷰를 하나씩 작성했다는 의미를 가지는데 테이블이 데이터를 바르게 반영하고 있는지 추후 점검을 진행해 봐야한다.

### 진단쿼리: raw_data 내 멀티 리뷰 사용자 존재 여부 확인
```sql
/*
  진단 쿼리: raw_data 내 멀티 리뷰 사용자 존재 여부 확인
  - 원본 데이터에서 user_id별 리뷰 작성 수를 확인
*/
SELECT
    user_id,
    COUNT(review_id) AS review_count_in_raw_data
FROM raw_data
WHERE review_id IS NOT NULL AND user_id IS NOT NULL
GROUP BY user_id
ORDER BY review_count_in_raw_data DESC
LIMIT 10;
```
<img width="982" height="285" alt="image" src="https://github.com/user-attachments/assets/a7e54171-864c-47ee-a35a-d67b5a83b78e" />

- raw_data에는 리뷰를 5개에서 10개까지 남긴 사용자들이 명확히 존재한다.
- 문제는 raw_data 자체에 멀티 리뷰 사용자가 없었던 것이 아니라 raw_data에서 Reviews 테이블로 데이터를 로드하는 과정에서 멀티 리뷰 정보가 모두 손실되었다.

### Review 테이블 삭제 후 재생성
```sql
/*
Reviews 테이블 재생성
*/
DROP TABLE Reviews;

CREATE TABLE Reviews (
    review_pk_id INTEGER PRIMARY KEY AUTOINCREMENT, -- 인공 Primary Key (오류 회피용)
    review_id TEXT, -- 원본 review_id는 일반 컬럼으로 강등
    product_id TEXT REFERENCES Products(product_id),
    user_id TEXT REFERENCES Users(user_id),
    review_title TEXT,
    review_content TEXT
);

INSERT INTO Reviews (review_id, product_id, user_id, review_title, review_content)
SELECT
    T1.review_id,
    TRIM(T1.product_id) AS product_id,
    T1.user_id,
    T1.review_title,
    T1.review_content
FROM raw_data AS T1
WHERE
    T1.review_id IS NOT NULL
    AND T1.user_id IS NOT NULL
    -- 외래 키 무결성 조건만 유지
    AND TRIM(T1.product_id) IN (SELECT product_id FROM Products)
    AND T1.user_id IN (SELECT user_id FROM Users);
    
/*
  분석 쿼리 0-4(재실행): Reviews 테이블 기본 통계
  - 총 리뷰 수 및 리뷰 내용의 평균 길이(상세도) 계산
*/
SELECT
    COUNT(review_id) AS total_reviews_recorded,
    ROUND(AVG(LENGTH(review_content)), 0) AS average_review_length_chars
FROM Reviews
WHERE review_content IS NOT NULL;
```
<img width="447" height="58" alt="image" src="https://github.com/user-attachments/assets/a4d5ec9b-e1fb-45a7-80c2-608787c6cb13" />

- 

### 분석쿼리 1:
```sql
/*
  분석 쿼리 1: 데이터 완성도 검증 (NULL 값 존재 여부 확인)
  - 분석에 중요한 컬럼에서 NULL 값이 몇 개나 존재하는지 확인
*/
SELECT
    (
        SELECT COUNT(*)
        FROM Pricing AS PR
        WHERE PR.rating IS NULL
    ) AS count_of_null_ratings,
    (
        SELECT COUNT(*)
        FROM Pricing AS PR
        WHERE PR.discount_percentage IS NULL
    ) AS count_of_null_discounts
FROM Pricing
LIMIT 1;
```
<img width="397" height="56" alt="image" src="https://github.com/user-attachments/assets/a6bce255-36de-4ce0-b1e0-47b9285b1cef" />

- 분석의 핵심 지표인 평점(rating)과 할인율(discount\_percentage)을 대상으로 검증을 수행한 결과 두 컬럼 모두 NULL 값이 0개임을 확인하였다.

### 분석쿼리 2:
```sql
/*
  분석 쿼리 2: 상품 카테고리 분포 분석
  - 데이터셋에서 상품 수가 가장 많은 카테고리를 식별하여 주요 시장 파악
*/
SELECT
    P.category,
    COUNT(P.product_id) AS total_products
FROM Products AS P
GROUP BY P.category
ORDER BY total_products DESC
LIMIT 5;
```
<img width="765" height="156" alt="image" src="https://github.com/user-attachments/assets/303616f1-158f-4ec0-9e9f-fd3b1d115f0e" />

- 전체 상품 중 USB 케이블(161개)이 2위 카테고리(스마트폰, 68개)와 비교할 때 약 2.4배 많은 상품 수를 차지하며 압도적인 비중을 가지고 있다.
-  USB 케이블 카테고리는 가장 많은 상품을 보유하고 있어 고객 유입 및 기본적인 매출 발생의 핵심 기반 시장임을 의미한다.
- 'Computers&Accessories'와 'Electronics' 두 분야가 시장을 주도하고 있으며 이들 카테고리에 대한 재고 및 상품 관리에 최우선 자원을 배분해야 함을 보여준다.

### 분석쿼리 3: 리뷰 콘텐츠 완성도 검증
```sql
/*
  분석 쿼리 3: 리뷰 콘텐츠 완성도 검증
  - 총 리뷰 중 리뷰 내용(review_content)이 비어있지 않은 비율 확인
*/
SELECT
    COUNT(review_id) AS total_reviews_recorded,
    COUNT(review_content) AS valid_content_count,
    ROUND(
        CAST(COUNT(review_content) AS REAL) * 100 / COUNT(review_id), 1
    ) AS content_completeness_rate_percent
FROM Reviews;
```
<img width="656" height="60" alt="image" src="https://github.com/user-attachments/assets/913fa597-91ea-4f23-99b2-b4e7533f7905" />

- 

### 분석쿼리 4:
```sql
/*
  분석 쿼리 4: 고객 감성(Sentiment) 분포 분석
  - 평점(rating)을 기준으로 고객 감성을 분류하여 분포 확인
*/
SELECT
    CASE
        WHEN PR.rating >= 4.0 THEN '1. Positive (4.0~5.0)'   -- 긍정
        WHEN PR.rating >= 3.0 AND PR.rating < 4.0 THEN '2. Neutral (3.0~3.9)' -- 중립
        ELSE '3. Negative (0.0~2.9)' -- 부정
    END AS sentiment_segment,
    COUNT(P.product_id) AS total_products_in_segment
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.rating IS NOT NULL
GROUP BY sentiment_segment
ORDER BY sentiment_segment;
```
<img width="405" height="111" alt="image" src="https://github.com/user-attachments/assets/d8a66344-acb3-4932-bd6c-01be80349882" />

- 

### 분석쿼리 A: 고객 참여도 분석
```sql
/*
  분석 쿼리 A: 고객 참여도 분석 - 가장 많이 리뷰된 상품 Top 5
  - Products와 Pricing 테이블을 JOIN하여 상품명과 평점 수를 결합
  목표: 전체 상품 중 가장 많은 리뷰를 받은 상품 5개를 순서대로 추출
*/
SELECT
    P.product_name,
    PR.rating_count,
    PR.actual_price,
    PR.discount_percentage
FROM Products AS P
-- Products와 Pricing 테이블을 product_id로 결합
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.rating_count IS NOT NULL AND PR.rating_count > 0
-- 평점 수를 기준으로 내림차순 정렬
ORDER BY PR.rating_count DESC
-- 상위 5개만 추출
LIMIT 5;
```
<img width="800" height="150" alt="Image" src="https://github.com/user-attachments/assets/8cf3a29a-890c-4ca8-af25-d9f0ac73c6de" />

- Top5를 낮은 가격대와 필수적인 소비재인 USB 케이블과 이어폰이 차지했다.
- 이 상품들은 actual_price가 저렴하거나(케이블: ₹475~₹1,400) 할인율이 매우 높다(이어폰: 62%~65%). 이는 '저가 소모품' 또는 '필수 액세서리'를 통해 고객을 유인하는 효율적인 유입 채널 역할을 수행하고 있음을 의미한다.

  ### 분석쿼리 B: 가격대 분석
```sql
/*
  분석 쿼리 B: 가격대 분석 - 가장 비싼 상품 Top 3
  목표: 원래 가격이 가장 비싼 상품 3개를 추출하여 회사의 프리미엄 포지셔닝 및 고수익 카테고리 파악
*/
SELECT
    P.product_name,
    P.category,
    PR.actual_price,
    PR.discount_percentage
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.actual_price IS NOT NULL AND PR.actual_price > 0
ORDER BY PR.actual_price DESC
LIMIT 3;
```
<img width="1500" height="150" alt="Image" src="https://github.com/user-attachments/assets/1e1b3b87-5606-406e-aff3-235eccaf2738" />

- 세 제품 모두 상당한 할인률을 보여주고 있지만 Sony Bravia 제품이 가장 높은 실제 가격과 할인률을 가지고 있어 할인을 적용한 후에도 다른 두 제품보다 훨씬 높은 가격대를 형성하고 있다.
- 모든 제품은 Electronics > Home Theater, TV & Video > Televisions > Smart Televisions 카테고리에 속한다.
- 제시된 데이터는 TV 시장의 가격 다변화 전략을 보여준다. Sony는 가장 높은 가격과 할인율로 고가 시장의 소비자들을 타겟하며 VU와 LG는 더 저렴한 가격대에서 가성비 또는 중간급 성능을 원하는 소비자들을 놓고 경쟁한다. 특히 인치 수가 작은 LG 제품이 65인치인 VU 제품과 가격대가 비슷하다는 점은 LG의 브랜드 가치나 특정 기능이 가격을 지지하고 있음을 나타낼 수 있다.

### 분석쿼리 C: 카테고리 내 우수 상품 식별
```sql
/*
  분석 쿼리 C: 카테고리 내 우수 상품 식별
  목표: 각 상품의 개별평점이 해당 카테고리의 평균 평점보다 높은 모든 우수 상품 목록 추출
*/
SELECT
    P.category,
    P.product_name,
    PR.rating AS individual_rating,
    (
        SELECT AVG(T2.rating)
        FROM Pricing AS T2
        JOIN Products AS T3 ON T2.product_id = T3.product_id
        WHERE T3.category = P.category
    ) AS category_average_rating
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.rating IS NOT NULL AND PR.rating > 0
    -- 개별 평점 > 카테고리 평균인 경우만 선택
    AND PR.rating > (
        SELECT AVG(T2.rating)
        FROM Pricing AS T2
        JOIN Products AS T3 ON T2.product_id = T3.product_id
        WHERE T3.category = P.category
    )
ORDER BY P.category, individual_rating DESC;
```
<img width="1860" height="560" alt="Image" src="https://github.com/user-attachments/assets/4d53c248-c88c-4244-b21b-baa5a11df5df" />

- 일반적인 Top 랭킹 대신 카테고리 평균 평점보다 높은 평점을 받은 상품만을 식별했다. 이는 단순한 숫자가 아닌 해당 경쟁 환경 내에서 고객 만족도가 가장 높은 상품군임을 의미한다.
- 식별된 상품들은 회사가 가장 우선적으로 투자해야 할 대상이 될 것이다. 이들은 이미 고객 기대치를 능가하고 있으므로 광고 예산을 이 상품에 집중하여 평점 우위를 시장 점유율 우위로 전환할 수 있다.
- category_average_rating 컬럼은 각 카테고리의 고객 기대치 기준선을 명확히 보여준다. 이 평균 평점을 최소 목표치로 설정하고 평균과의 격차를 줄이기 위한 개선 작업을 진행해야 한다.

### 분석쿼리 D:
```sql
/*
  분석 쿼리 D: 할인 효율성 분석
  - 평균 할인율 대비 평균 평점 수를 비교하여 효율적인 할인 전략을 파악
*/
SELECT
    P.category,
    ROUND(AVG(PR.discount_percentage), 1) AS average_discount_percentage,
    ROUND(AVG(PR.rating_count), 0) AS average_rating_count,
    COUNT(P.product_id) AS total_products
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.discount_percentage IS NOT NULL AND PR.rating_count IS NOT NULL
GROUP BY P.category
ORDER BY average_rating_count DESC
LIMIT 5;
```
<img width="1130" height="155" alt="image" src="https://github.com/user-attachments/assets/a4e34787-f22b-4e0e-bd65-fa3e648f1c5a" />

- 'Choppers' 카테고리는 60%의 할인율로 27만 건이 넘는 압도적인 평균 평점 수(고객 참여도)를 기록했다. 이는 할인율 대비 고객 반응이 가장 폭발적인 '할인 효율성 최우수' 카테고리임을 의미한다.
- 'BluetoothAdapters'는 33%라는 상대적으로 낮은 할인율로도 9만 5천 건의 높은 고객 반응을 유도하였다. 이 카테고리는 적은 비용으로 고객 유입을 이끌어내는 가장 효율적인 할인 전략을 가진 영역이라고 볼 수 있다.

### 분석쿼리 E:
```sql
/*
  분석 쿼리 E: 고객 만족도 위험 분석
  - 평균 평점이 가장 낮은 카테고리를 식별하여 품질 개선 필요 영역 제시
*/
SELECT
    P.category,
    ROUND(AVG(PR.rating), 2) AS average_rating,
    COUNT(P.product_id) AS total_products
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.rating IS NOT NULL AND PR.rating > 0
GROUP BY P.category
HAVING COUNT(P.product_id) >= 10
ORDER BY average_rating ASC
LIMIT 5;
```
<img width="871" height="152" alt="image" src="https://github.com/user-attachments/assets/d308036b-d189-41b0-961a-0658ff5f8842" />

- TV 리모컨 및 관련 액세서리 카테고리가 평균 3.80점으로 가장 낮은 평점을 기록하였다. 이는 고객 경험의 초기 단계에서 제품 호환성, 사용 편의성, 또는 내구성에 심각한 문제가 있었다고 추측할 수 있다.
- 팬 히터와 전기 히터가 나란히 하위 5위권에 포진하였다(3.81점, 3.89점). 이는 계절적 요인 또는 제품 안전성 및 성능에 대한 고객 불만이 높을 가능성이 있음을 보여주며 제품 품질 관리(QC)의 긴급한 점검이 필요함을 알려준다.
- 인이어 헤드폰은 쿼리 D에서 상품 수가 많은 경쟁 포화 영역으로 진단되었는데 쿼리 E에서는 평점도 하위권(3.89점)으로 나타났다. 이는 경쟁이 치열함에도 불구하고 품질이나 AS에서 고객을 만족시키지 못하고 있다는 것을 의미한다.

### 분석쿼리 F:
```sql
/*
  분석 쿼리 F: 가격 구간 세분화 분석
  - 가장 큰 카테고리 내 상품을 저가/중가/고가로 분류하여 분포 파악
*/
SELECT
    -- CASE WHEN을 사용해 가격 구간 분류
    CASE
        WHEN PR.actual_price < 1000 THEN '1. Low-Price (Under ₹1,000)'
        WHEN PR.actual_price >= 1000 AND PR.actual_price < 3000 THEN '2. Mid-Price (₹1,000 ~ ₹3,000)'
        ELSE '3. High-Price (Over ₹3,000)'
    END AS price_segment,
    COUNT(P.product_id) AS total_products_in_segment
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.actual_price IS NOT NULL AND PR.actual_price > 0
    -- 전체 상품 중 가장 큰 카테고리 상품만 분석 (예: 'Home&Kitchen')
    AND P.category LIKE 'Home&Kitchen%'
GROUP BY price_segment
ORDER BY price_segment;
```
<img width="442" height="108" alt="image" src="https://github.com/user-attachments/assets/d191d528-f0d7-4eed-b112-70d891a6aaef" />

- 분석 대상 카테고리(Home&Kitchen) 내 상품이 중가(₹1,000 ~ ₹3,000, 182개)와 고가(Over ₹3,000, 163개) 영역에 가장 많이 집중되어 있다.
- 저가 상품(103개)보다 중가 및 고가 상품 수가 더 많은 것으로 보아 이는 단순한 저가 경쟁 시장이 아니라 기능과 품질에 따른 가격 프리미엄이 형성된 성숙한 시장임을 시사한다.

### 분석쿼리 G:
```sql
/*
  분석 쿼리 G: 고가치 고객 세분화
  - 가장 활동적인 리뷰어를 식별하고 그들의 평점 성향을 분석
*/
SELECT
    U.user_name,
    COUNT(R.review_id) AS total_reviews_written, -- 작성한 총 리뷰 수
    ROUND(AVG(PR.rating), 2) AS avg_rating_by_user, -- 사용자가 남긴 평균 평점
    COUNT(DISTINCT P.category) AS diverse_categories_reviewed -- 리뷰한 카테고리의 다양성
FROM Users AS U
JOIN Reviews AS R ON U.user_id = R.user_id
JOIN Products AS P ON R.product_id = P.product_id
JOIN Pricing AS PR ON R.product_id = PR.product_id
WHERE PR.rating IS NOT NULL
GROUP BY U.user_name
ORDER BY total_reviews_written DESC
LIMIT 5;
```
<img width="1327" height="160" alt="image" src="https://github.com/user-attachments/assets/12d6df1d-169d-4be9-8108-fba6cf83a329" />

- Top 5 리뷰어 모두 평균 평점이 4.00~4.30 사이로 전체 평균(4.09점)과 비교했을 때 매우 긍정적이거나 비슷한 수준임
- 이들은 단순히 불만을 토로하는 고객이 아니라 적극적으로 제품 사용 경험을 공유하고 회사에 긍정적인 영향을 미치는 충성 고객임을 알 수 있음

### 분석쿼리 H:
```sql
/*
  분석 쿼리 H: 평점-리뷰 볼륨 불일치 분석
  - 높은 리뷰 볼륨 대비 낮은 평점을 가진 위험 상품군 식별
*/
SELECT
    P.product_name,
    PR.rating AS average_product_rating, -- 상품에 기록된 최종 평점
    PR.rating_count AS total_rating_count, -- 총 평점 수
    ROUND(AVG(LENGTH(R.review_content)), 0) AS avg_review_length_chars -- 고객이 남긴 리뷰 길이 평균
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
JOIN Reviews AS R ON P.product_id = R.product_id
WHERE PR.rating_count >= 5000 -- 대규모 불만이 발생했을 가능성이 높은 상품만 필터링
GROUP BY P.product_name, P.category, PR.rating, PR.rating_count
HAVING PR.rating < 3.5 -- 평점이 3.5점 미만인 경우
ORDER BY PR.rating_count DESC
LIMIT 5;
```
<img width="1281" height="153" alt="image" src="https://github.com/user-attachments/assets/ce064233-b8c3-42a0-8567-5f5793f0cf4d" />

- 5개 상품 모두 평균 평점 3.3~3.4점으로 전체 평균(4.09점)보다 현저히 낮고 리뷰 수(5,692~12,185건)가 높아 대규모 고객 불만이 이미 시장에 노출되어 있음을 보여준다.
- 특히 Canon PIXMA 프린터는 12,185건이라는 가장 많은 부정적 피드백을 축적하고 있어 가장 시급한 품질 관리 대상이다. 이 상품들은 판매가 지속될수록 브랜드 신뢰도에 치명적인 손상을 입힐 수 있다.
- avg_review_length_chars 값이 높게 나왔는데 이는 고객들이 단순히 낮은 평점을 주는 것을 넘어 상세하고 구체적인 이유를 리뷰에 작성하고 있음을 시사한다. 이 리뷰들은 제품 개발팀이 결함을 파악할 수 있는 고가치 데이터이다.

### 분석쿼리 I:
```sql
/*
  분석 쿼리 I: 리뷰 상세도 분석
  - 리뷰 길이(디테일)를 기준으로 영향력 있는 사용자 식별
*/
SELECT
    U.user_name,
    ROUND(AVG(LENGTH(R.review_content)), 0) AS average_review_length_chars, -- 평균 리뷰 길이
    COUNT(R.review_id) AS total_reviews,
    -- GROUP_CONCAT으로 리뷰한 카테고리 목록을 하나의 문자열로 결합
    GROUP_CONCAT(DISTINCT SUBSTR(P.category, 1, INSTR(P.category, '|') - 1)) AS main_categories_reviewed
FROM Users AS U
JOIN Reviews AS R ON U.user_id = R.user_id
JOIN Products AS P ON R.product_id = P.product_id
WHERE R.review_content IS NOT NULL AND LENGTH(R.review_content) > 50 -- 내용이 짧은 리뷰 제외
GROUP BY U.user_name
ORDER BY average_review_length_chars DESC
LIMIT 5;
```
<img width="1326" height="157" alt="image" src="https://github.com/user-attachments/assets/dc359d80-f4fe-46cf-8277-7da102c31507" />

- 
