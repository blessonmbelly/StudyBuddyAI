import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.routes import files, notes, quiz, chat

app = FastAPI(
    title="StudyBuddy AI API",
    description="Lightweight backend for study document extraction, notes generation, quiz creation, and notes-grounded chat powered by Gemini.",
    version="1.0.0",
)

# Enable CORS for Flutter app (both local USB ADB reverse and local Wi-Fi)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API endpoints
app.include_router(files.router)
app.include_router(notes.router)
app.include_router(quiz.router)
app.include_router(chat.router)

@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint to verify backend status and Gemini configuration."""
    return {
        "status": "ok",
        "service": "StudyBuddy AI Backend",
        "version": "1.0.0",
        "gemini_configured": settings.is_gemini_configured,
        "gemini_model": settings.GEMINI_MODEL,
        "max_upload_size_mb": settings.MAX_UPLOAD_SIZE_MB,
    }

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Ensure HTTP exceptions preserve their exact status code and detail."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global fallback exception handler to return clean JSON error responses."""
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal server error: {str(exc)}"},
    )

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
    )
