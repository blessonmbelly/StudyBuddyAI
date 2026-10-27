from fastapi import APIRouter, HTTPException
from ..models import ChatRequest, ChatResponse
from ..gemini_service import answer_student_chat

router = APIRouter(prefix="/api/chat", tags=["Chat"])

@router.post("", response_model=ChatResponse)
async def chat_with_notes(req: ChatRequest):
    """
    Answers questions grounded on the student's selected study note.
    Maintains conversation context and provides key takeaways.
    """
    cleaned_msg = req.message.strip()
    if not cleaned_msg:
        raise HTTPException(status_code=400, detail="Chat message cannot be empty.")

    response = answer_student_chat(
        message=cleaned_msg,
        note_context=req.note_context or "",
        history=req.history or [],
    )
    return response
