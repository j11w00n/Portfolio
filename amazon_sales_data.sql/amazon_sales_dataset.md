
### 2.1 분석쿼리 A: 고객 참여도 분석
'''sql
-- [SELECT
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
LIMIT 5;]
<img width="992" height="151" alt="Image" src="https://github.com/user-attachments/assets/8cf3a29a-890c-4ca8-af25-d9f0ac73c6de" />
