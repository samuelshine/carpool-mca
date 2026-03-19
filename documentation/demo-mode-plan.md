# Demo Mode Plan

Last updated: 2026-03-19

## Goal

Add a reusable `Demo Mode` to the mobile app so the team can demo the product without depending on live ride movement, a fully prepared backend account, or a real emergency/safety event.

The feature needs to do two things well:

1. give presenters a single toggle on the user-facing settings/preferences surface
2. expose the most important product stories in a safe, repeatable, and quick-to-launch way

## Thought Process

The main question was not just "where should the toggle live?" but "what makes a demo fail today?"

The fragile parts of a live demo are:

- GPS and movement requirements
- needing an already-created ride or pending request
- needing verified driver/profile state
- needing safety/reporting data to already exist
- needing a completed ride before ratings/history feel meaningful

Because of that, the design for Demo Mode follows these principles:

- keep activation simple: one persistent toggle in `Preferences`
- keep discovery simple: once enabled, the app should clearly surface where to start
- keep demos safe: seeded demo data should stay local and should not write fake safety/rating/demo state to the real backend
- keep the narrative structured: a dedicated `Demo Center` should group the app by the story we want to tell, not by raw screen names
- keep real mode untouched: turning Demo Mode off should immediately return the app to normal behavior

## What Was Implemented

### Activation

- Added a persistent `Demo Mode` toggle to `Preferences`
- Stored the flag with shared preferences so it survives app restarts
- Added contextual "Demo Mode is active" banners on the main settings/home/driver surfaces

### Demo entry point

- Added a `Demo Center` screen
- The Demo Center groups features into:
  - Rider Journey
  - Driver Operations
  - Safety and Trust
  - Account and Verification

### Seeded demo behaviors

Demo Mode now provides local demo data or demo-safe behavior for:

- route preview launch shortcuts
- available rides / ride match browsing
- live ride simulation
- driver ride creation
- driver join-request review
- activity history
- post-ride ratings
- safety center contacts, SOS history, and reports
- profile and verification read-only walkthroughs

## Demo Feature Inventory

| Feature Area | Why it matters in a demo | Demo Mode behavior | Recommended launch path |
| --- | --- | --- | --- |
| Rider route planning | Shows pickup, destination, and trip intent | Uses seeded demo route coordinates | `Preferences -> Demo Mode -> Open Demo Center -> Rider Journey -> Route Preview` |
| Ride discovery | Shows that riders can find matching rides | Loads seeded ride cards locally | `Demo Center -> Rider Journey -> Ride Matches` |
| Ride request outcome | Moves the story from search to trip | Demo request is approved immediately | `Ride Matches -> Request -> Open Live Demo` |
| Live ride tracking | This is the most visually convincing demo flow | Uses simulated movement and OTP flow | `Demo Center -> Rider Journey -> Live Ride` |
| Driver ride creation | Shows supply-side setup | Returns a local demo ride instead of backend creation | `Demo Center -> Driver Operations -> Create Ride` |
| Driver request management | Shows driver control over riders | Loads seeded requests and moves accepted riders into participants locally | `Demo Center -> Driver Operations -> Requests` |
| Driver live flow | Shows status progression from the driver side | Opens live ride in driver view | `Demo Center -> Driver Operations -> Driver Live` |
| Safety center | Demonstrates readiness and trust | Uses seeded contacts/reports and stores new demo actions locally | `Demo Center -> Safety And Trust -> Safety Center` |
| Activity/history | Shows ride lifecycle continuity | Loads seeded active/requested/completed/cancelled trips | `Demo Center -> Safety And Trust -> Activity` |
| Ratings | Shows trust and accountability after a ride | Stores the rating only within the demo flow | `Demo Center -> Safety And Trust -> Rate Ride` |
| Profile | Shows user identity and verified state | Loads seeded account and vehicle information | `Demo Center -> Account And Verification -> Profile` |
| Verification | Explains onboarding and approval logic | Shows approved sample state in read-only form | `Demo Center -> Account And Verification -> Verification` |

## Recommended Demo Script

This is the order that best tells the product story in a short presentation.

### 1. Turn Demo Mode on

- Open `Settings -> Preferences`
- Enable `Demo Mode`
- Tap `Open Demo Center`

Talking point:

- "This lets us present the whole product without needing a moving vehicle, a live ride state, or fake backend safety events."

### 2. Show the rider story

- Open `Route Preview`
- Explain pickup, destination, time, distance, and fare framing
- Move to `Ride Matches`
- Open one of the seeded rides
- Send the request and continue into the live ride simulation
- Show OTP, progress, status changes, rider/driver view switch, and SOS entry point

Talking point:

- "This is the rider journey from route intent to in-trip visibility."

### 3. Show the driver story

- Open `Create Ride`
- Walk through vehicle, starting point, timing, seat count, and restrictions
- Return and open `Requests`
- Accept one seeded request and show how it moves into confirmed passengers
- Open `Driver Live` and explain arrival, pickup confirmation, and trip progression

Talking point:

- "The same app also supports the operational side for student drivers."

### 4. Show trust and safety

- Open `Safety Center`
- Show emergency contacts
- Trigger a demo SOS
- Add a demo report if needed
- Open `Activity` and point out active/requested/completed/cancelled buckets
- Open `Rate Ride` to show the post-trip trust loop

Talking point:

- "We treat safety and accountability as part of the ride lifecycle, not as separate afterthoughts."

### 5. Close with account readiness

- Open `Profile`
- Show verified account/vehicle posture
- Open `Verification`
- Explain what each approval unlocks

Talking point:

- "Verification controls who can book, who can drive, and how trust is maintained."

## Presenter Notes

- If time is short, the strongest 3-step demo is:
  - `Ride Matches`
  - `Live Ride`
  - `Safety Center`
- If the audience cares about operations, swap in:
  - `Create Ride`
  - `Requests`
  - `Driver Live`
- If the audience cares about trust/compliance, end on:
  - `Activity`
  - `Rate Ride`
  - `Verification`

## Implementation Notes

- `Demo Mode` is stored persistently via shared preferences
- seeded demo data is centralized so multiple screens reuse the same scenario
- Demo Mode avoids unsafe fake backend writes for:
  - ratings
  - SOS
  - emergency contacts
  - reports
  - ride creation
- demo-specific launch paths are intentionally grouped in `Demo Center` so presenters do not need to remember a hidden navigation sequence

## Known Boundaries

- Route preview still uses the existing map/routing presentation, so an environment without map/routing availability may still reduce that part of the experience
- Demo Mode currently focuses on the mobile user app, not the admin web
- Verification and profile demo flows are intentionally read-only so presenters do not accidentally change real account data during a demo

## Suggested Future Enhancements

- add an admin-side demo bundle for verification review and SOS oversight
- add a one-tap "guided tour" mode that auto-opens the next recommended screen
- add analytics to understand which demo paths are used most often by the team
- add branded canned personas for different audiences such as rider-first, safety-first, and investor-first demos
