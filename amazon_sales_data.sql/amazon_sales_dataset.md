
### 분석쿼리 A: 고객 참여도 분석
```sql
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

  ### 분석쿼리 B: 
