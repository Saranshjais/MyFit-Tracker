// The muscles the app can show on an exercise. Stored by [Muscle.id] in the
// database (comma-separated), so ids must never change.

enum BodyPart {
  chest('Chest'),
  shoulders('Shoulders'),
  back('Back'),
  arms('Arms'),
  core('Core'),
  legs('Legs');

  const BodyPart(this.label);
  final String label;
}

/// Which side of the body diagram shows the muscle.
enum MuscleSide { front, back, both }

enum Muscle {
  chestUpper(
    'chest_upper',
    'Upper chest',
    'Pectoralis major, clavicular head',
    BodyPart.chest,
    MuscleSide.front,
    'Presses the arms up and forward; fills out the top of the chest.',
  ),
  chest(
    'chest',
    'Chest (pecs)',
    'Pectoralis major, sternal head',
    BodyPart.chest,
    MuscleSide.front,
    'Pushes the arms forward and brings them across the body.',
  ),
  frontDelts(
    'front_delts',
    'Front shoulders',
    'Anterior deltoid',
    BodyPart.shoulders,
    MuscleSide.front,
    'Lifts the arms forward and overhead; works in every press.',
  ),
  sideDelts(
    'side_delts',
    'Side shoulders',
    'Lateral deltoid',
    BodyPart.shoulders,
    MuscleSide.both,
    'Lifts the arms out to the side; gives the shoulders their width.',
  ),
  rearDelts(
    'rear_delts',
    'Rear shoulders',
    'Posterior deltoid',
    BodyPart.shoulders,
    MuscleSide.back,
    'Pulls the arms back; balances the front of the shoulder and helps posture.',
  ),
  traps(
    'traps',
    'Traps',
    'Trapezius, upper and middle fibres',
    BodyPart.back,
    MuscleSide.back,
    'Shrugs and steadies the shoulder blades; builds the upper back and neck.',
  ),
  lats(
    'lats',
    'Lats',
    'Latissimus dorsi',
    BodyPart.back,
    MuscleSide.back,
    'Pulls the arms down and back; gives the back its V-shape width.',
  ),
  upperBack(
    'upper_back',
    'Upper back',
    'Rhomboids, middle trapezius and teres major',
    BodyPart.back,
    MuscleSide.back,
    'Squeezes the shoulder blades together; builds back thickness.',
  ),
  lowerBack(
    'lower_back',
    'Lower back',
    'Erector spinae',
    BodyPart.back,
    MuscleSide.back,
    'Keeps the spine straight when you lift, bend and carry.',
  ),
  biceps(
    'biceps',
    'Biceps',
    'Biceps brachii and brachialis',
    BodyPart.arms,
    MuscleSide.front,
    'Bends the elbow and turns the palm up.',
  ),
  triceps(
    'triceps',
    'Triceps',
    'Triceps brachii (long, lateral and medial heads)',
    BodyPart.arms,
    MuscleSide.back,
    'Straightens the elbow; makes up about two thirds of upper-arm size.',
  ),
  forearms(
    'forearms',
    'Forearms',
    'Brachioradialis and the wrist flexors and extensors',
    BodyPart.arms,
    MuscleSide.both,
    'Grip strength and wrist control.',
  ),
  abs(
    'abs',
    'Abs',
    'Rectus abdominis',
    BodyPart.core,
    MuscleSide.front,
    'Curls the trunk forward and braces the core.',
  ),
  obliques(
    'obliques',
    'Obliques',
    'External and internal obliques',
    BodyPart.core,
    MuscleSide.front,
    'Twists and side-bends the trunk; resists rotation.',
  ),
  glutes(
    'glutes',
    'Glutes',
    'Gluteus maximus and medius',
    BodyPart.legs,
    MuscleSide.back,
    'Drives the hips forward: standing up, climbing, sprinting and jumping.',
  ),
  quads(
    'quads',
    'Quads',
    'Quadriceps femoris (front of the thigh)',
    BodyPart.legs,
    MuscleSide.front,
    'Straightens the knee; the main muscle in squats and leg presses.',
  ),
  hamstrings(
    'hamstrings',
    'Hamstrings',
    'Biceps femoris, semitendinosus and semimembranosus',
    BodyPart.legs,
    MuscleSide.back,
    'Bends the knee and extends the hip.',
  ),
  adductors(
    'adductors',
    'Inner thighs',
    'Adductor group',
    BodyPart.legs,
    MuscleSide.both,
    'Pulls the legs together and steadies the knees in squats and lunges.',
  ),
  calves(
    'calves',
    'Calves',
    'Gastrocnemius and soleus',
    BodyPart.legs,
    MuscleSide.back,
    'Points the foot; pushes you off the ground when walking, running and jumping.',
  );

  const Muscle(this.id, this.label, this.anatomy, this.part, this.side, this.role);

  /// Stable database id.
  final String id;

  /// Everyday name, e.g. "Front shoulders".
  final String label;

  /// Anatomical name, e.g. "Anterior deltoid".
  final String anatomy;
  final BodyPart part;
  final MuscleSide side;

  /// What the muscle does, in one sentence.
  final String role;

  static Muscle? byId(String id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Parses a comma-separated id list; unknown ids are ignored.
  static List<Muscle> parse(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    return [for (final id in csv.split(',')) ?byId(id.trim())];
  }

  static String encode(Iterable<Muscle> muscles) => muscles.map((m) => m.id).join(',');
}
