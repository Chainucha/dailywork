from pydantic import BaseModel, UUID4, field_validator
from uuid import UUID
from datetime import date, datetime, time
from typing import Literal


class JobCreate(BaseModel):
    category_id: UUID4
    title: str
    description: str | None = None
    location_lat: float
    location_lng: float
    address_text: str | None = None
    wage_per_day: float
    workers_needed: int = 1
    start_date: date
    end_date: date
    start_time: time | None = None
    end_time: time | None = None
    is_urgent: bool = False

    @field_validator("wage_per_day")
    @classmethod
    def wage_must_be_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("wage_per_day must be positive")
        return v

    @field_validator("workers_needed")
    @classmethod
    def workers_must_be_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("workers_needed must be at least 1")
        return v


class JobUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    wage_per_day: float | None = None
    workers_needed: int | None = None
    status: Literal["open", "assigned", "in_progress", "completed", "cancelled"] | None = None
    start_date: date | None = None
    end_date: date | None = None
    start_time: time | None = None
    end_time: time | None = None
    is_urgent: bool | None = None
    address_text: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None


class JobCancelRequest(BaseModel):
    reason: str | None = None


class JobResponse(BaseModel):
    id: UUID
    employer_id: UUID
    category_id: UUID
    title: str
    description: str | None = None
    location_lat: float
    location_lng: float
    address_text: str | None = None
    wage_per_day: float
    workers_needed: int
    workers_assigned: int
    status: str
    start_date: date
    end_date: date
    start_time: time | None = None
    end_time: time | None = None
    is_urgent: bool = False
    cancellation_reason: str | None = None
    created_at: datetime
    category_name: str | None = None
    employer_name: str | None = None
    applicant_count: int = 0


class JobListResponse(BaseModel):
    data: list[JobResponse]
    page: int
    page_size: int
    total: int


class EmployerJobsGroupedResponse(BaseModel):
    open: list[JobResponse] = []
    assigned: list[JobResponse] = []
    in_progress: list[JobResponse] = []
    completed: list[JobResponse] = []
    cancelled: list[JobResponse] = []
