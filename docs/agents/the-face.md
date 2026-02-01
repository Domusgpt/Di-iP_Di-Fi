# The Face — Flutter + TypeScript Agent Specification

**The Face** is the user-facing agent. It comprises a Flutter mobile/web application and a TypeScript backend deployed as Firebase Cloud Functions. Together they own the UI layer, social features, API gateway, and event routing.

---

## Flutter Frontend

### State Management — Riverpod

All application state is managed through Riverpod providers. The following provider families form the core state tree:

| Provider | Responsibility |
|---|---|
| `authProvider` | Current user authentication state, sign-in/sign-out actions |
| `feedProvider` | Paginated invention feed with filter support |
| `walletProvider` | Connected wallet address and balance |
| `notificationsProvider` | Real-time notification stream for the authenticated user |

Providers are scoped to minimize rebuilds. Family providers are used where state is parameterized (e.g., `inventionProvider(id)`).

### Routing — GoRouter

The application uses GoRouter for declarative, URL-driven navigation.

| Route | Screen | Auth Required |
|---|---|---|
| `/` | Feed | No |
| `/login` | Auth (Login / Signup) | No |
| `/invention/:id` | Invention Detail | No |
| `/create` | Create Invention | Yes |
| `/search` | Search | No |
| `/notifications` | Notifications | Yes |
| `/invest/:id` | Invest | Yes |
| `/profile/:uid` | Profile | No |

A redirect guard on GoRouter checks `authProvider` and sends unauthenticated users to `/login` when they attempt to access protected routes.

### Screens

#### Feed

- Displays a scrollable list of `InventionCard` widgets.
- **Filter chips** at the top allow switching between feed modes:
  - **Trending** — sorted by engagement score (likes + comments + investment count).
  - **Near Goal** — inventions closest to reaching their funding target.
  - **Newest** — reverse chronological order.
  - **Following** — inventions by users the current user follows.
- Infinite scroll with Firestore cursor-based pagination.

#### Search

- Supports searching by **tags** and **title**.
- Debounced text input triggers a Firestore query.
- Results are rendered as `InventionCard` widgets.

#### Notifications

- Real-time stream from the `notifications` Firestore collection filtered by the authenticated user's UID.
- Notification types include: new follower, comment on your invention, investment confirmed, AI processing complete.
- Tap a notification to navigate to the relevant screen.

#### Auth (Login / Signup)

- Email and password fields with validation.
- Toggle between login and signup modes.
- Google OAuth button (planned, currently disabled).
- On successful authentication, navigates to the Feed.

#### Invention Detail

- **Hero section**: invention title, creator avatar, cover image or sketch.
- **Funding progress**: progress bar, current amount / goal, number of investors, deadline countdown.
- **Brief**: AI-generated structured summary (populated by the Brain agent).
- **Comments section**: `CommentSection` widget with real-time Firestore stream.
- **Like button**: `LikeButton` widget toggling a UID-keyed document in the likes sub-collection.

#### Create Invention

- Multi-modal input:
  - **Text**: title and description fields.
  - **Voice**: audio recording that is transcribed and attached.
  - **Sketch**: simple drawing canvas; the image is uploaded to Firebase Storage.
- On submit, creates a Firestore invention document and triggers the `onInventionCreated` event.

#### Invest

- Displays the invention summary and current funding status.
- **USDC amount selector**: preset buttons (10, 50, 100, 500) and a custom input field.
- Initiates a blockchain transaction via the connected wallet.
- Shows a pending state until the Vault confirms the transaction.

#### Profile

- **Tabs**:
  - *Inventions* — list of inventions created by this user.
  - *Investments* — list of inventions this user has invested in (visible only to the profile owner).
- **Follow button**: toggles a document in the `following` collection; a Cloud Function mirrors it to the `followers` collection.
- Displays follower and following counts.

### Key Widgets

| Widget | Description |
|---|---|
| `InventionCard` | Compact card showing title, creator, thumbnail, funding progress, like count, and comment count. Tappable to navigate to Invention Detail. |
| `CommentSection` | Real-time comment list with an input field. Each comment shows the author, timestamp, and text. Supports edit and delete for the comment owner. |
| `LikeButton` | Heart icon that toggles between liked and unliked states. Writes a UID-keyed document to the likes sub-collection. Displays the total like count. |

### Firebase SDK Integration

| SDK Feature | Usage |
|---|---|
| **Cloud Firestore** | Real-time streams (`snapshots()`) power the feed, comments, likes, and notifications. All reads are streamed; writes go through the TypeScript backend API or directly to Firestore where rules permit. |
| **Firebase Authentication** | Provides the ID token attached to API requests and the `uid` used for Firestore rules evaluation. |
| **Firebase Cloud Messaging** | Delivers push notifications to the device. The TypeScript backend sends messages via the Admin SDK when relevant events occur (e.g., investment confirmed). |

---

## TypeScript Backend

The backend is an **Express application** mounted on **Firebase Cloud Functions Gen 2**. It serves as the API gateway and event router for the Face agent.

### Express Router Structure

All routes are prefixed with `/api/v1` and organized by domain:

| Service Module | Base Path | Responsibility |
|---|---|---|
| `invention-service` | `/api/v1/inventions` | CRUD for inventions, feed queries |
| `investment-service` | `/api/v1/investments` | Investment submission, status lookup |
| `profile-service` | `/api/v1/profiles` | User profile read/update, follow/unfollow |
| `social-service` | `/api/v1/social` | Comments, likes, engagement metrics |
| `notification-service` | `/api/v1/notifications` | Notification preferences, mark-as-read |

### Middleware

Every request passes through the **Firebase Auth middleware**:

1. Extract the `Authorization: Bearer <token>` header.
2. Verify the token using `admin.auth().verifyIdToken(token)`.
3. Attach the decoded token (including `uid`, `email`, and custom claims) to `req.user`.
4. Reject with `401` if the token is missing or invalid.

Additional middleware handles CORS, request logging, and error formatting.

### Event Handlers

Event handlers are Cloud Functions triggered by Firestore document writes or Pub/Sub messages.

| Event | Trigger | Actions |
|---|---|---|
| `onInventionCreated` | Firestore `onCreate` on `inventions/{id}` | Index the invention for feed queries. Send notifications to the creator's followers. Publish `invention.created` to Pub/Sub for the Brain. |
| `onInvestmentPending` | Pub/Sub `investment.pending` | Write a pending investment record to Firestore. Notify the invention creator that an investment is incoming. |
| `onInvestmentConfirmed` | Pub/Sub `investment.confirmed` | Update the Firestore investment record to confirmed status. Update the invention's funding progress. Send a confirmation notification to the investor. |
| `onAiProcessingComplete` | Pub/Sub `ai.processing.complete` | Merge the AI-generated brief and analysis into the invention document. Notify the creator that their invention has been analyzed. |
| `onUserCreated` | Firebase Auth `onCreate` | Create a default profile document in Firestore with display name, avatar placeholder, and empty follower/following counts. |
| `blockchainIndexer` | Cloud Scheduler (every 1 minute) | Poll for recent on-chain events related to platform contracts. Publish any new `investment.pending` events discovered. Acts as a safety net alongside real-time wallet submissions. |
