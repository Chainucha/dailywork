from pydantic import BaseModel, UUID4, field_validator
from datetime import datetime


class ReviewCreate(BaseModel):
    reviewee_id: UUID4
    job_id: UUID4
    rating: int
    comment: str | None = None

    @field_validator("rating")
    @classmethod
    def rating_range(cls, v: int) -> int:
        if not 1 <= v <= 5:
            raise ValueError("rating must be between 1 and 5")
        return v


class ReviewResponse(BaseModel):
    id: UUID4
    reviewer_id: UUID4
    reviewee_id: UUID4
    job_id: UUID4
    rating: int
    comment: str | None = None
    created_at: datetime
