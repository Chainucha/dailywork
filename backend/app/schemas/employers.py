from pydantic import BaseModel, UUID4
from datetime import datetime


class EmployerProfileResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    business_name: str
    business_type: str | None = None
    rating_avg: float
    total_reviews: int
    updated_at: datetime


class EmployerProfileUpdate(BaseModel):
    business_name: str | None = None
    business_type: str | None = None
