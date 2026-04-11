from pydantic import BaseModel, UUID4
from datetime import datetime


class WorkerProfileResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    skills: list[str]
    availability_status: bool
    daily_wage_expectation: float | None = None
    rating_avg: float
    total_reviews: int
    updated_at: datetime


class WorkerProfileUpdate(BaseModel):
    skills: list[str] | None = None
    availability_status: bool | None = None
    daily_wage_expectation: float | None = None
