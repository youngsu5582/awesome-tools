## 1회

- 푼 날: 2026-11-08 10:00 시작 · 10:40 제출 (40분 12초)

### 코딩
- 결과: 전부 통과 · 통과 20/20
- 메모: 해시맵에 값 → 인덱스

```java
Map<Integer, Integer> seen = new HashMap<>();
for (int i = 0; i < nums.length; i++) {
    Integer j = seen.get(target - nums[i]);
    if (j != null) return new int[]{j, i};
    seen.put(nums[i], i);
}
return new int[0];
```

### 주관식
1.
   - ① 2, 1
   - ② first 는 1, second 는 2
   - ③ putIfAbsent
2.
   - ① 못 찾는다. 인덱스는 email 순서인데 LOWER 를 씌우면 그 순서를 못 쓴다
   - ② LOWER(email) 로 인덱스를 따로 만든다
   - ③

### 서술형 1
1. 하루 10만 건, 앱은 응답이 늦으면 같은 요청을 한 번 더 보낸다고 가정한다.
2. 앱이 주문마다 멱등 키를 만들어 보내고, 서버는 결제 테이블의 멱등 키에 UNIQUE 를 건다. 두 번째 요청은 UNIQUE 에 걸려 첫 요청의 결과를 돌려준다.
3. 결제사 응답이 없으면 결제 상태를 UNKNOWN 으로 두고 다시 보내지 않으며, 결제사 조회로 확정한다.

### 복기
| 구간 | 계획 | 실제 |
|---|---|---|
| 훑기 | 1분 | 30초 |
| 코딩 | 20분 | 15분 |
| 주관식 | 10분 | 9분 |
| 서술형 | 12분 | 14분 |
