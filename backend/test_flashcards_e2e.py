"""
End-to-End Test Suite for Flashcards Feature:
- AI Flashcard Generation from Study Material (POST /api/flashcards/generate)
- Validation on Insufficient Source Material (< 15 chars rejected)
- PostgreSQL Persistence of Deck and Cards
- Per-User Authorization & Data Isolation (User B cannot see or manipulate User A's cards)
- Card Status Updates ('known' / 'learning') and automatic mastery count recalculation
- Review Session Logging (POST /api/flashcards/decks/{id}/review)
- Cascade deletion of deck and cards
"""
import asyncio
import os
import sys
import uuid

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from httpx import AsyncClient, ASGITransport
from main import app


async def run_flashcards_tests():
    print("=" * 75)
    print(" FLASHCARDS FEATURE: BACKEND & DATABASE VERIFICATION")
    print("=" * 75)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        unique_suffix = uuid.uuid4().hex[:6]
        email_a = f"fc_user_a_{unique_suffix}@studybuddy.ai"
        email_b = f"fc_user_b_{unique_suffix}@studybuddy.ai"
        password = "SecurePassword123!"

        # 1. Register User A and User B
        print("\n1. Registering User A and User B...")
        res_a = await client.post("/api/auth/register", json={
            "email": email_a,
            "password": password,
            "full_name": "Flashcard Student A"
        })
        assert res_a.status_code == 201, f"User A registration failed: {res_a.text}"
        token_a = res_a.json()["access_token"]
        headers_a = {"Authorization": f"Bearer {token_a}"}

        res_b = await client.post("/api/auth/register", json={
            "email": email_b,
            "password": password,
            "full_name": "Flashcard Student B"
        })
        assert res_b.status_code == 201, f"User B registration failed: {res_b.text}"
        token_b = res_b.json()["access_token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}
        print("   [PASS] User A and User B registered successfully.")

        # 2. Test insufficient source material validation
        print("\n2. Testing validation: insufficient source material rejection (< 15 characters)...", flush=True)
        res_short = await client.post(
            "/api/flashcards/generate",
            headers=headers_a,
            json={
                "text": "Too short",
                "deck_title": "Test Short",
                "num_cards": 5
            }
        )
        assert res_short.status_code in (400, 422), f"Expected 400 or 422 for short text, got {res_short.status_code}"
        print(f"   [PASS] Short text correctly rejected with HTTP {res_short.status_code}.")

        # 3. Test flashcard generation from actual study material
        print("\n3. Generating and saving flashcard deck for User A...")
        study_content = (
            "Mitochondria are membrane-bound cell organelles that generate most of the chemical "
            "energy needed to power the cell's biochemical reactions. Chemical energy produced by the "
            "mitochondria is stored in a small molecule called adenosine triphosphate (ATP). "
            "Mitochondria contain their own small chromosomes and DNA, generally inherited only from the mother. "
            "The inner membrane is folded into cristae to maximize the surface area for ATP synthesis."
        )

        res_gen = await client.post(
            "/api/flashcards/generate",
            headers=headers_a,
            json={
                "text": study_content,
                "deck_title": "Cellular Respiration & Mitochondria",
                "subject": "Biology",
                "num_cards": 4
            }
        )
        assert res_gen.status_code == 201, f"Flashcard generation failed: {res_gen.text}"
        deck_a_data = res_gen.json()
        deck_a_id = deck_a_data["id"]
        cards = deck_a_data["cards"]

        assert len(cards) >= 3, f"Expected at least 3 cards generated, got {len(cards)}"
        assert deck_a_data["title"] is not None
        assert deck_a_data["card_count"] == len(cards)
        assert deck_a_data["mastered_count"] == 0
        card_1_id = cards[0]["id"]
        card_2_id = cards[1]["id"]
        print(f"   [PASS] Deck '{deck_a_data['title']}' created with {len(cards)} cards (Deck ID: {deck_a_id}).")

        # 4. Per-User Data Isolation: Verify User B cannot see or retrieve User A's deck
        print("\n4. Verifying per-user data isolation between User A and User B...")
        res_b_decks = await client.get("/api/flashcards/decks", headers=headers_b)
        assert res_b_decks.status_code == 200
        assert len(res_b_decks.json()) == 0, "User B should have 0 decks."

        res_b_access_a = await client.get(f"/api/flashcards/decks/{deck_a_id}", headers=headers_b)
        assert res_b_access_a.status_code == 404, f"Expected 404 for cross-user deck access, got {res_b_access_a.status_code}"

        res_b_status_update = await client.put(
            f"/api/flashcards/cards/{card_1_id}/status",
            headers=headers_b,
            json={"status": "known"}
        )
        assert res_b_status_update.status_code == 404, "User B should not be able to modify User A's card."
        print("   [PASS] Strict per-user data isolation verified. Cross-user access rejected.")

        # 5. List decks for User A and verify retrieval
        print("\n5. Testing GET /api/flashcards/decks for User A...")
        res_a_decks = await client.get("/api/flashcards/decks", headers=headers_a)
        assert res_a_decks.status_code == 200
        decks_list = res_a_decks.json()
        assert len(decks_list) == 1
        assert decks_list[0]["id"] == deck_a_id
        assert len(decks_list[0]["cards"]) == len(cards)
        print("   [PASS] User A successfully listed their decks.")

        # 6. Test Card Status Update & Mastery Calculation
        print("\n6. Testing individual card status update ('known')...")
        res_card_update = await client.put(
            f"/api/flashcards/cards/{card_1_id}/status",
            headers=headers_a,
            json={"status": "known"}
        )
        assert res_card_update.status_code == 200
        assert res_card_update.json()["status"] == "known"
        assert res_card_update.json()["review_count"] == 1

        # Check that deck mastered_count updated to 1
        res_deck_check = await client.get(f"/api/flashcards/decks/{deck_a_id}", headers=headers_a)
        assert res_deck_check.status_code == 200
        assert res_deck_check.json()["mastered_count"] == 1
        print("   [PASS] Card status updated and deck mastered count recalculated to 1.")

        # 7. Test Add Custom Card to Deck
        print("\n7. Testing POST /api/flashcards/decks/{id}/cards (Add custom card)...")
        res_add_card = await client.post(
            f"/api/flashcards/decks/{deck_a_id}/cards",
            headers=headers_a,
            json={
                "front": "What does ATP stand for?",
                "back": "Adenosine Triphosphate",
                "hint": "Energy currency of the cell"
            }
        )
        assert res_add_card.status_code == 201
        new_card = res_add_card.json()
        assert new_card["front"] == "What does ATP stand for?"
        new_card_id = new_card["id"]

        # Check card count updated on deck
        res_deck_after_add = await client.get(f"/api/flashcards/decks/{deck_a_id}", headers=headers_a)
        assert res_deck_after_add.json()["card_count"] == len(cards) + 1
        print(f"   [PASS] Custom card added. New card count: {res_deck_after_add.json()['card_count']}.")

        # 8. Test Review Session Recording (POST /api/flashcards/decks/{id}/review)
        print("\n8. Testing review session logging (POST /api/flashcards/decks/{id}/review)...", flush=True)
        res_review = await client.post(
            f"/api/flashcards/decks/{deck_a_id}/review",
            headers=headers_a,
            json={
                "cards_reviewed": 3,
                "known_count": 2,
                "review_again_count": 1,
                "duration_seconds": 45,
                "card_updates": [
                    {"card_id": card_1_id, "status": "known"},
                    {"card_id": card_2_id, "status": "known"},
                    {"card_id": new_card_id, "status": "learning"}
                ]
            }
        )
        assert res_review.status_code == 201, f"Review logging failed: {res_review.text}"
        review_data = res_review.json()
        assert review_data["cards_reviewed"] == 3
        assert review_data["known_count"] == 2
        print("   [PASS] Review session recorded successfully in PostgreSQL.")

        # 9. Test Cascading Deletion of Deck
        print("\n9. Testing DELETE /api/flashcards/decks/{id}...")
        res_del = await client.delete(f"/api/flashcards/decks/{deck_a_id}", headers=headers_a)
        assert res_del.status_code == 200

        res_check_gone = await client.get(f"/api/flashcards/decks/{deck_a_id}", headers=headers_a)
        assert res_check_gone.status_code == 404
        print("   [PASS] Flashcard deck deleted and verified 404.")

    print("\n" + "=" * 75)
    print(" ALL FLASHCARD BACKEND TESTS PASSED SUCCESSFULLY! ")
    print("=" * 75)


if __name__ == "__main__":
    asyncio.run(run_flashcards_tests())
