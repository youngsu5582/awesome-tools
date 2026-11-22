# 진단 1회 (예시)

## 주관식 (15분 · 문항당 5분 · ①②③ 각각 한두 줄)

### 1. 같은 키를 두 번 넣은 HashMap

**상황**

```java
Map<String, Integer> m = new HashMap<>();
Integer first = m.put("a", 1);
Integer second = m.put("a", 2);
```

**묻는 것**
1. `m.get("a")` 의 값과 `m.size()` 를 각각 쓴다.
2. `first` 와 `second` 에는 무엇이 들어 있나?
3. 키가 **없을 때만** 넣으려면 어떤 메서드를 쓰나?

**보려는 것** — `put` 이 덮어쓰고 이전 값을 돌려준다는 걸 아는지.

### 2. 함수로 감싼 조건

**상황** — `users.email` 에 B-tree 인덱스가 있다.

```sql
SELECT * FROM users WHERE LOWER(email) = 'a@b.com';
```

**묻는 것**
1. 이 쿼리는 `email` 인덱스로 시작점을 바로 찾을 수 있나? 왜?
2. SQL 을 그대로 두고 빠르게 만드는 방법 하나.
3. 그 방법의 대가 하나.

**보려는 것** — 인덱스의 정렬 순서와 조건의 모양을 연결하는지.

### 3. 롤백되는 범위

**상황**

```java
@Transactional
public void order() {
    stockRepository.decrease(1);
    throw new IOException("결제 실패");
}
```

**묻는 것**
1. 이 예외가 던져지면 `decrease` 는 롤백되나?
2. 그 이유를 기본 규칙으로 설명한다.
3. 롤백되게 하려면 어떻게 고치나?

**보려는 것** — 체크 예외와 언체크 예외의 기본 처리 차이를 아는지.
