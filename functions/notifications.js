/**
 * Push notification triggers.
 *
 * Notifications used to be fired locally by whichever device happened to
 * observe a Firestore change while in the foreground. That meant a provider
 * only learned about a nearby job while staring at the open app, and a
 * customer only learned a provider had accepted while the matching screen was
 * in front of them.
 *
 * These triggers run server-side, so delivery does not depend on anyone having
 * the app open.
 */

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const db = () => getFirestore();

/** Every registered device token for a user. */
async function tokensFor(userId) {
  const snap = await db()
    .collection("deviceTokens")
    .where("userId", "==", userId)
    .get();
  return snap.docs.map((d) => d.get("token")).filter(Boolean);
}

/** Sends to a user's devices and prunes tokens the service rejects. */
async function notifyUser(userId, notification, data = {}) {
  const tokens = await tokensFor(userId);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification,
    data,
    android: { priority: "high" },
  });

  // A token that is gone stays gone — leaving them accumulates and every
  // send drags dead entries along.
  const stale = [];
  response.responses.forEach((result, i) => {
    const code = result.error?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      stale.push(tokens[i]);
    }
  });
  await Promise.all(
    stale.map((token) => db().collection("deviceTokens").doc(token).delete())
  );
}

/**
 * A new open ticket → notify providers subscribed to the provider topic.
 *
 * Topic fan-out is deliberately coarse: precise geo/skill targeting would mean
 * querying every online provider on each ticket. The client already filters by
 * skill and radius, so this wakes the app; the app decides whether to show it.
 */
exports.onOpenTicketCreated = onDocumentCreated(
  "openTickets/{ticketId}",
  async (event) => {
    const ticket = event.data?.data();
    if (!ticket || ticket.status !== "matching") return;

    await getMessaging().send({
      topic: "role_provider",
      notification: {
        title: "New job nearby",
        body: ticket.description
          ? String(ticket.description).slice(0, 120)
          : "A new request is available in your area.",
      },
      data: {
        type: "openTicket",
        ticketId: event.params.ticketId,
        category: String(ticket.category ?? ""),
      },
      android: { priority: "high" },
    });
  }
);

/** A provider accepted → tell the customer someone is waiting on their choice. */
exports.onCandidateCreated = onDocumentCreated(
  "tickets/{ticketId}/candidates/{providerId}",
  async (event) => {
    const candidate = event.data?.data();
    if (!candidate || candidate.status === "rejected") return;

    const ticket = await db()
      .collection("tickets")
      .doc(event.params.ticketId)
      .get();
    const customerId = ticket.get("customerId");
    if (!customerId) return;

    await notifyUser(
      customerId,
      {
        title: "A provider is available",
        body: `${candidate.displayName || "A provider"} accepted your request. Review and confirm.`,
      },
      { type: "candidate", ticketId: event.params.ticketId }
    );
  }
);

/** Job status changed → tell whichever party did not make the change. */
exports.onJobStatusChanged = onDocumentUpdated(
  "jobs/{jobId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;

    const customerFacing = {
      accepted: "Your provider accepted the job.",
      enRoute: "Your provider is on the way.",
      arrived: "Your provider has arrived.",
      estimateSubmitted: "An estimate is ready for your approval.",
      workInProgress: "Work has started on your job.",
      completionRequested: "Your provider marked the work complete.",
      cancelled: "Your job was cancelled.",
    };

    const providerFacing = {
      cancelled: "This job was cancelled.",
    };

    if (customerFacing[after.status] && after.customerId) {
      await notifyUser(
        after.customerId,
        { title: "Job update", body: customerFacing[after.status] },
        { type: "job", jobId: event.params.jobId }
      );
    }

    if (providerFacing[after.status] && after.providerId) {
      await notifyUser(
        after.providerId,
        { title: "Job update", body: providerFacing[after.status] },
        { type: "job", jobId: event.params.jobId }
      );
    }
  }
);
