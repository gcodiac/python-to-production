from pydantic import BaseModel


class NoteCreate(BaseModel):
    title: str
    content: str = ""


class NoteUpdate(BaseModel):
    title: str
    content: str = ""


class Note(BaseModel):
    id: int
    title: str
    content: str
    created_at: str
