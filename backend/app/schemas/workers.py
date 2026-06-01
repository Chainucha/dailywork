from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class WorkerProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    skills: list[str]
    availability_status: bool
    daily_wage_expectation: float | None = None
    rating_avg: float
    total_reviews: int
    jobs_completed: int = 0
    updated_at: datetime


class WorkerProfileUpdate(BaseModel):
    skills: list[str] | None = None
    availability_status: bool | None = None
    daily_wage_expectation: float | None = None
