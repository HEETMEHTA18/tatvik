from collections import defaultdict, deque
from time import time

from fastapi import HTTPException, Request, status


class InMemoryRateLimiter:
    def __init__(self, max_requests: int, window_seconds: int):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.buckets: dict[str, deque[float]] = defaultdict(deque)

    def __call__(self, request: Request):
        key = request.client.host if request.client else "unknown"
        now = time()
        bucket = self.buckets[key]
        while bucket and now - bucket[0] > self.window_seconds:
            bucket.popleft()
        if len(bucket) >= self.max_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={"code": "RATE_LIMITED", "message": "Too many requests"},
            )
        bucket.append(now)


moderate_rate_limit = InMemoryRateLimiter(max_requests=60, window_seconds=60)
