CREATE TABLE raw_data (
    product_id TEXT, product_name TEXT, category TEXT, discounted_price TEXT,
    actual_price TEXT, discount_percentage TEXT, rating TEXT, rating_count TEXT,
    about_product TEXT, user_id TEXT, user_name TEXT, review_id TEXT,
    review_title TEXT, review_content TEXT, img_link TEXT, product_link TEXT
);

-- Products 테이블 생성
CREATE TABLE Products (
    product_id TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    category TEXT,
    about_product TEXT
);

-- 데이터 삽입 및 정제
INSERT INTO Products (product_id, product_name, category, about_product)
SELECT
    -- 1. TRIM()으로 공백 제거 후 PRIMARY KEY로 사용
    TRIM(T1.product_id) AS product_id,
    -- 2. 그룹 내에서 product_name의 대표값(MIN)을 선택하고, NULL이면 대체
    COALESCE(MIN(T1.product_name), 'Unknown Product Name') AS product_name,
    MIN(T1.category) AS category,
    MIN(T1.about_product) AS about_product
FROM raw_data AS T1
WHERE
    T1.product_id IS NOT NULL  -- PRIMARY KEY NULL 방지
    AND T1.product_name IS NOT NULL -- NOT NULL 제약 조건 오류 방지
-- 3. TRIM된 product_id를 기준으로 그룹화하여 중복을 해결
GROUP BY TRIM(T1.product_id);

-- Pricing 테이블 생성
CREATE TABLE Pricing (
    product_id TEXT PRIMARY KEY REFERENCES Products(product_id),
    discounted_price REAL,
    actual_price REAL,
    discount_percentage REAL,
    rating REAL,
    rating_count INTEGER
);

-- Pricing 데이터 삽입
INSERT INTO Pricing (product_id, discounted_price, actual_price, discount_percentage, rating, rating_count)
SELECT
    -- TRIM() 적용
    TRIM(product_id) AS product_id,
    CAST(REPLACE(REPLACE(discounted_price, '₹', ''), ',', '') AS REAL),
    CAST(REPLACE(REPLACE(actual_price, '₹', ''), ',', '') AS REAL),
    CAST(REPLACE(discount_percentage, '%', '') AS REAL),
    CAST(rating AS REAL),
    CAST(REPLACE(REPLACE(rating_count, ' global ratings', ''), ',', '') AS INTEGER)
FROM raw_data
-- TRIM된 product_id를 기준으로 그룹화
GROUP BY TRIM(product_id)
HAVING TRIM(product_id) IN (SELECT product_id FROM Products);

-- Users 테이블 생성 및 데이터 삽입
CREATE TABLE Users (
    user_id TEXT PRIMARY KEY,
    user_name TEXT -- 사용자 이름은 NULL을 허용해도 괜찮다고 가정합니다.
);

INSERT INTO Users (user_id, user_name)
SELECT
    DISTINCT user_id,
    user_name
FROM raw_data
WHERE user_id IS NOT NULL;

-- Reviews 테이블 생성 및 데이터 삽입
CREATE TABLE Reviews (
    review_id TEXT PRIMARY KEY,
    product_id TEXT REFERENCES Products(product_id), -- Products 테이블 참조
    user_id TEXT REFERENCES Users(user_id),         -- Users 테이블 참조
    review_title TEXT,
    review_content TEXT
);

INSERT INTO Reviews (review_id, product_id, user_id, review_title, review_content)
SELECT
    T1.review_id,
    TRIM(T1.product_id) AS product_id,
    MIN(T1.user_id) AS user_id,
    MIN(T1.review_title) AS review_title,
    MIN(T1.review_content) AS review_content
FROM raw_data AS T1
WHERE
    T1.review_id IS NOT NULL -- Primary Key NULL 방지
GROUP BY T1.review_id -- review_id가 같은 행은 하나로 묶음
HAVING
    TRIM(T1.product_id) IN (SELECT product_id FROM Products)
    AND MIN(T1.user_id) IN (SELECT user_id FROM Users);

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

/*
  분석 쿼리 0-4: Reviews 테이블 기본 통계
  - 총 리뷰 수 및 리뷰 내용의 평균 길이(상세도) 계산
*/
SELECT
    COUNT(review_id) AS total_reviews_recorded,
    ROUND(AVG(LENGTH(review_content)), 0) AS average_review_length_chars
FROM Reviews
WHERE review_content IS NOT NULL;

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

/*
  분석 쿼리 3: 리뷰 작성 횟수 분석
  - 가장 많은 사용자 그룹의 리뷰 작성 횟수 확인
*/
SELECT
    COUNT(T1.user_id) AS users_in_group,
    T1.reviews_written
FROM (
    SELECT
        user_id,
        COUNT(review_pk_id) AS reviews_written
    FROM Reviews
    GROUP BY user_id
) AS T1
GROUP BY T1.reviews_written
ORDER BY users_in_group DESC
LIMIT 10;

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

/*
  분석 쿼리 B: 가격대 분석 - 가장 비싼 상품 Top 3
  목표: 원래 가격이 가장 비싼 상품 3개를 추출하여 회사의 프리미엄 포지셔닝 및 고수익 카테고리 파악
*/
SELECT
    P.product_name,
    P.category,
    PR.actual_price,
    PR.discounted_price,
    PR.discount_percentage
FROM Products AS P
JOIN Pricing AS PR ON P.product_id = PR.product_id
WHERE PR.actual_price IS NOT NULL AND PR.actual_price > 0
ORDER BY PR.actual_price DESC
LIMIT 3;

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