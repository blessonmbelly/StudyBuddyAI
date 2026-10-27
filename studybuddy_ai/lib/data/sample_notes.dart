import '../models/note.dart';

final List<NoteItem> sampleStudyNotes = [
  NoteItem(
    id: 'note_1',
    title: 'Cognitive Neuroscience - Memory Systems',
    courseCode: 'PSYC 201',
    courseName: 'Psychology 201',
    category: 'psych',
    summary: 'Hippocampal consolidation, long-term potentiation & semantic frameworks.',
    estimatedTime: '6 min read',
    timeAgo: '3 hrs ago',
    accuracyPercent: 98,
    keyTermsCount: 14,
    readTime: '6 min read',
    sections: [
      const NoteSection(
        title: 'Dual-Store Memory Model',
        description: "Atkinson & Shiffrin's multistore architecture detailing structural memory stages:",
        bullets: [
          NoteBullet(
            term: 'Sensory Memory',
            definition: 'Holds raw sensory stimuli for milliseconds (iconic visual & echoic auditory storage).',
            iconName: 'visibility',
          ),
          NoteBullet(
            term: 'Short-Term Memory (STM)',
            definition: 'Limited capacity (7 ± 2 chunks), duration ~20–30s without active rehearsal.',
            iconName: 'timer',
          ),
          NoteBullet(
            term: 'Long-Term Memory (LTM)',
            definition: 'Potentially limitless capacity with dense semantic organization and associative indexing.',
            iconName: 'all_inclusive',
          ),
        ],
      ),
    ],
    definitions: [
      'Encoding Specificity: Retrieval is most effective when retrieval cues match the exact environmental and cognitive context present during initial encoding (Tulving, 1973).',
      'Consolidation: The biological process by which fragile, labile memories stabilize and transform into enduring, permanent neural traces within the neocortex.',
    ],
    examPitfall: "Don't confuse Retrograde with Anterograde Amnesia! Retrograde: cannot recall memories formed before injury. Anterograde: cannot form new enduring memories after trauma.",
    rawTranscript: "...dual store Atkinson-Shiffrin 1968. Sensory store holds visual icon for roughly 250ms, echoic up to 3-4s. Short term capacity Miller 1956 7 +/- 2. Rehearsal loop keeps STM alive otherwise decays fast under distraction. Long term memory consolidation happens during slow-wave sleep via hippocampal-cortical replay...",
    isBookmarked: true,
  ),
  NoteItem(
    id: 'note_2',
    title: 'Organic Chemistry - Alkene Reactions',
    courseCode: 'CHEM 302',
    courseName: 'Chem 302',
    category: 'chem',
    summary: 'Electrophilic additions, Markovnikov selectivity, and hydroboration pathways.',
    estimatedTime: '8 min read',
    timeAgo: 'Yesterday',
    accuracyPercent: 92,
    keyTermsCount: 18,
    readTime: '8 min read',
    sections: [
      const NoteSection(
        title: 'Markovnikov Addition Principles',
        description: 'Carbocation stability determines major product orientation:',
        bullets: [
          NoteBullet(
            term: 'Electrophilic Addition',
            definition: 'Protonation produces the more substituted, stable tertiary carbocation intermediate.',
            iconName: 'science',
          ),
          NoteBullet(
            term: 'Anti-Markovnikov Hydroboration',
            definition: 'BH3-THF followed by basic hydrogen peroxide yields primary alcohols through syn addition.',
            iconName: 'biotech',
          ),
        ],
      ),
    ],
    definitions: [
      'Carbocation: An ion containing a positively charged carbon atom; tertiary is more stable than secondary or primary.',
    ],
    examPitfall: 'Watch out for carbocation rearrangements (hydride and methyl shifts) when forming secondary carbocations!',
    rawTranscript: 'Lecture notes on alkene additions: Markovnikov rule states halogen bonds to carbon with fewer hydrogens...',
    isBookmarked: false,
  ),
  NoteItem(
    id: 'note_3',
    title: 'Macroeconomics - Fiscal Policy',
    courseCode: 'ECON 101',
    courseName: 'Econ 101',
    category: 'econ',
    summary: 'Government expenditure multipliers, tax levers, and debt dynamics.',
    estimatedTime: '5 min read',
    timeAgo: '3 days ago',
    accuracyPercent: 88,
    keyTermsCount: 12,
    readTime: '5 min read',
    sections: [
      const NoteSection(
        title: 'Keynesian Multiplier Effect',
        description: 'How initial government spending injections expand aggregate demand:',
        bullets: [
          NoteBullet(
            term: 'Marginal Propensity to Consume (MPC)',
            definition: 'The proportion of aggregate raise in pay that a consumer spends on goods rather than saving.',
            iconName: 'trending_up',
          ),
          NoteBullet(
            term: 'Spending Multiplier Formula',
            definition: 'k = 1 / (1 - MPC). A higher MPC leads to a substantially greater total expansionary stimulus.',
            iconName: 'calculate',
          ),
        ],
      ),
    ],
    definitions: [
      'Fiscal Drag: When high progressive tax brackets reduce private aggregate demand during inflationary recoveries.',
    ],
    examPitfall: 'Remember that the tax multiplier is always smaller in magnitude than the government purchases multiplier by exactly 1.',
    rawTranscript: 'Fiscal policy slides: Multiplier k = 1/(1-MPC). Tax cuts induce consumption only up to the MPC fraction...',
    isBookmarked: false,
  ),
];
