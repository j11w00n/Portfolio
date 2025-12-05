
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
