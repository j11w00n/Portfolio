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

- 

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

- 

### 분석쿼리 0-3:

### 분석쿼리 0-4:

### 분석쿼리 1:
```sql
/*
  분석 쿼리 1: 데이터 완성도 검증
  - 필수 분석 컬럼(평점, 할인율)의 누락 정도를 확인하여 데이터 품질을 평가
*/
SELECT
    COUNT(P.product_id) AS total_products,
    COUNT(PR.rating) AS valid_rating_count,
    ROUND(
        CAST(COUNT(PR.rating) AS REAL) * 100 / COUNT(P.product_id), 1
    ) AS rating_completeness_rate_percent,
    COUNT(PR.discount_percentage) AS valid_discount_count,
    ROUND(
        CAST(COUNT(PR.discount_percentage) AS REAL) * 100 / COUNT(P.product_id), 1
    ) AS discount_completeness_rate_percent
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id;
```
<img width="1005" height="60" alt="image" src="https://github.com/user-attachments/assets/28d19bd8-83b4-4f79-98e0-e9cd4a2e0168" />

- 

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
<img width="766" height="156" alt="image" src="https://github.com/user-attachments/assets/dd0293b0-d78a-45db-b8a3-221c2a02ffa4" />

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
- 또한 할인률(discounted_percentage)이 60%를 넘는 제품이 Top5 중 4개나 차지하고 있다. 이를 통해 할인효과를 극대화하는 전략이 매우 효과적이었음을 알 수 있다.

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

- 

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

- 

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

- 

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

- 
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
