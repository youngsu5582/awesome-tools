## 1회

- 푼 날: 2026-11-08 10:00 시작 · 10:50 제출 (50분 3초)

### 코딩 1
- 결과: 전부 통과 · 통과 20/20
- 메모: 해시맵에 값 → 인덱스

```
Map<Integer, Integer> seen = new HashMap<>();
for (int i = 0; i < nums.length; i++) {
    Integer j = seen.get(target - nums[i]);
    if (j != null) return new int[]{j, i};
    seen.put(nums[i], i);
}
return new int[0];
```

### 코딩 2
- 결과: 일부 통과 · 통과 12/15
- 메모: 닫는 괄호가 먼저 올 때 스택이 비어 있는 경우를 놓침

```python
stack = []
pairs = {")": "(", "]": "[", "}": "{"}
for ch in s:
    if ch in pairs:
        if stack.pop() != pairs[ch]:
            return False
    else:
        stack.append(ch)
return not stack
```

### 코딩 3
- 결과: 제출 못 함

### 복기
| 구간 | 계획 | 실제 |
|---|---|---|
| 훑기 | 3분 | 40초 |
| 코딩 | 60분 | 49분 |

- 문항별: 코1 15분 · 코2 20분 · 코3 14분
- 깃발 남은 문항: 코딩 3
