/**
 * Server-owned matching lifecycle.
 *
 * Both of these used to live inside a widget: geo-broadcast radius expansion
 * ran on a `Timer.periodic` created in `MatchingScreen`'s stream `onListen`,
 * and candidate-lease expiry on a timer inside `ProviderReviewScreen`. If the
 * customer backgrounded the app or navigated away, the radius never grew past
 * 5 km and the ticket sat in `matching` forever — invisible to a provider 6 km
 * away — while losing candidates stayed pinned as pending indefinitely.
 *
 * This is business logic, not UI state. It belongs here, where it runs whether
 * or not anybody is looking at a screen.
 *
 * Deploy: firebase deploy --only functions
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

// Must match AppConstants in the Flutter app.
const SEARCH_RADII_KM = [2, 5, 10, 15];
const BROADCAST_TIMEOUT_SECONDS = 60;

const db = () => getFirestore();

/**
 * Expands the search radius of stalled tickets, and gives up once every tier
 * has been tried without a candidate.
 */
exports.expandBroadcastRadius = onSchedule("every 1 minutes", async () => {
  const cutoff = new Date(Date.now() - BROADCAST_TIMEOUT_SECONDS * 1000);

  const stalled = await db()
    .collection("tickets")
    .where("status", "==", "matching")
    .where("updatedAt", "<=", cutoff)
    .limit(200)
    .get();

  if (stalled.empty) return;

  const batch = db().batch();
  let touched = 0;

  for (const doc of stalled.docs) {
    const ticket = doc.data();
    const currentRadius = ticket.broadcastRadiusKm ?? SEARCH_RADII_KM[0];
    const tier = SEARCH_RADII_KM.indexOf(currentRadius);
    const next = tier + 1;

    if (next >= SEARCH_RADII_KM.length) {
      // Every tier tried, nobody accepted.
      batch.update(doc.ref, {
        status: "failed",
        updatedAt: FieldValue.serverTimestamp(),
      });
      batch.delete(db().collection("openTickets").doc(doc.id));
    } else {
      const radius = SEARCH_RADII_KM[next];
      batch.update(doc.ref, {
        broadcastRadiusKm: radius,
        updatedAt: FieldValue.serverTimestamp(),
      });
      // Keep the provider-facing projection in step.
      batch.update(db().collection("openTickets").doc(doc.id), {
        broadcastRadiusKm: radius,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    touched += 1;
  }

  await batch.commit();
  console.log(`Advanced ${touched} stalled ticket(s).`);
});

/**
 * Expires candidate leases whose review window has passed and returns the
 * ticket to matching so broadcasting resumes.
 */
exports.expireCandidateLeases = onSchedule("every 1 minutes", async () => {
  const now = new Date();

  const waiting = await db()
    .collection("tickets")
    .where("status", "==", "awaitingCustomerConfirmation")
    .where("candidateWindowExpiresAt", "<=", now)
    .limit(200)
    .get();

  if (waiting.empty) return;

  for (const doc of waiting.docs) {
    const candidates = await doc.ref
      .collection("candidates")
      .where("status", "==", "pending")
      .get();

    const batch = db().batch();
    for (const candidate of candidates.docs) {
      batch.update(candidate.ref, { status: "expired" });
    }
    batch.update(doc.ref, {
      status: "matching",
      candidateWindowExpiresAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // Republish the redacted projection so providers can find it again.
    const ticket = doc.data();
    await db()
      .collection("openTickets")
      .doc(doc.id)
      .set(
        {
          id: doc.id,
          customerId: ticket.customerId,
          description: ticket.description ?? "",
          imageUrls: ticket.imageUrls ?? [],
          category: ticket.category,
          complexity: ticket.complexity,
          approximateLocation: ticket.approximateLocation,
          status: "matching",
          createdAt: ticket.createdAt,
          updatedAt: FieldValue.serverTimestamp(),
          clarifyingQa: ticket.clarifyingQa ?? [],
          recommendedEquipment: ticket.recommendedEquipment ?? [],
          broadcastRadiusKm: ticket.broadcastRadiusKm ?? SEARCH_RADII_KM[0],
          ...(ticket.aiSummary ? { aiSummary: ticket.aiSummary } : {}),
        },
        { merge: true }
      );

    console.log(`Expired ${candidates.size} lease(s) on ticket ${doc.id}.`);
  }
});
