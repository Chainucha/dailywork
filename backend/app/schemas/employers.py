from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class EmployerProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    business_name: str
    business_type: str | None = None
    rating_avg: float
    total_reviews: int
    jobs_posted: int = 0
    updated_at: datetime


class EmployerProfileUpdate(BaseModel):
    business_name: str | None = None
    business_type: str | None = None
