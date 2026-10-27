import '../models/chat_message.dart';

final List<ChatMessage> initialChatMessages = [
  ChatMessage(
    id: 'msg_welcome',
    sender: MessageSender.ai,
    text: "Hi Alex! 👋 I'm StudyBuddy AI. I've reviewed your scanned notes on Cognitive Psychology: Memory Systems. Ask me anything—definitions, comparisons, or quiz prep!",
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    noteReference: 'PSYC 201 • Cognitive Psychology',
    keyTakeaways: [
      'Dual-Store Model (Sensory, STM, LTM)',
      'Hippocampal Consolidation & LTP',
      'Retrograde vs Anterograde Amnesia',
    ],
  ),
];

class MockChatService {
  static String generateReply(String userQuery) {
    final lower = userQuery.toLowerCase();

    if (lower.contains('atkinson') || lower.contains('dual-store') || lower.contains('model')) {
      return "Based on your PSYC 201 notes, the **Atkinson-Shiffrin Dual-Store Model** consists of 3 stages:\n\n"
          "1. **Sensory Memory:** Holds raw stimuli for milliseconds (Iconic visual ~250ms, Echoic auditory ~3-4s).\n"
          "2. **Short-Term Memory (STM):** Capacity of 7 ± 2 chunks, lasting ~20-30s without rehearsal.\n"
          "3. **Long-Term Memory (LTM):** Potentially limitless storage with semantic indexing and associative networks.";
    } else if (lower.contains('amnesia') || lower.contains('retrograde') || lower.contains('anterograde')) {
      return "⚠️ **Exam Alert from your notes:**\n\n"
          "• **Retrograde Amnesia:** Inability to recall memories formed *before* the injury/trauma (past memories lost).\n"
          "• **Anterograde Amnesia:** Inability to form *new* permanent memories after the injury (patient H.M. had this).\n\n"
          "Prof. Vance specifically flagged this as a high-frequency midterm trap!";
    } else if (lower.contains('hippocampus') || lower.contains('consolidation')) {
      return "According to your notes:\n\n"
          "The **Hippocampus** acts as the temporary biological switchboard that binds cortical representations together. "
          "During **consolidation** (especially in slow-wave sleep), synaptic changes stabilize fragile memory traces and transfer them permanently into the neocortex.";
    } else if (lower.contains('ebbinghaus') || lower.contains('forgetting curve') || lower.contains('curve')) {
      return "From your OCR Scanned Slide 3:\n\n"
          "The **Ebbinghaus Forgetting Curve** illustrates exponential memory decay:\n"
          "• Up to 70% of new information is forgotten within the first 24 hours without review.\n"
          "• **Spaced Repetition** interrupts this decay trajectory and flattens the curve progressively.";
    } else if (lower.contains('mnemonic') || lower.contains('memory trick')) {
      return "Here is a quick mnemonic from StudyBuddy AI:\n\n"
          "Remember **S-S-L** for Memory Stores:\n"
          "• **S**ee/Hear = **Sensory** (Flashes in ms)\n"
          "• **S**even Chunks = **Short-term** (20-30 secs)\n"
          "• **L**ife-long = **Long-term** (Consolidated in cortex)\n\n"
          "Would you like a rapid 3-question recall drill on this?";
    } else {
      return "I analyzed your study notes on **Memory Systems**: That concept connects directly with how the brain stabilizes information from sensory buffer into cortical storage. "
          "Would you like me to generate a practice MCQ on this or explain how it contrasts with implicit procedural memory?";
    }
  }
}
