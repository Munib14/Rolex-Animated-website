# The Art of Precision — a scroll-driven watch film

A cinematic, single-page presentation of a mechanical timepiece. Five supplied
animations are treated as **one continuous take**, and the viewer's scroll
position is the only thing that moves it: scrolling down advances the film,
scrolling up reverses it, and stopping freezes it on the exact frame.

### Easiest way: double-click `start.bat`

In the project folder, double-click **`start.bat`**. It checks Node is present,
installs dependencies if they are missing, starts the server, and opens
http://localhost:3000 in your browser after a few seconds. Close the window to
stop it.

### Or from a terminal

```bash
npm.cmd run dev
```

Then open http://localhost:3000.

> **Windows / PowerShell.** Use `npm.cmd`, not `npm`. PowerShell's default
> execution policy refuses to run `npm.ps1` and fails with
> `running scripts is disabled on this system`. `npm.cmd` bypasses the shim
> entirely. (Alternatively, allow the shim once with
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.) In cmd.exe, Git Bash
> or on macOS/Linux, plain `npm` is fine.

Dependencies are already installed; re-run `npm.cmd install` only if you move
the folder or delete `node_modules`.

### If the page ever renders wrongly

Stop the server, delete the build output, and start again:

```bash
rm -rf .next .next-dev
```

`next dev` and `next build` write to separate directories here (`.next-dev` and
`.next` respectively), specifically so that building while the dev server is
running cannot leave it serving a broken mix of the two — but clearing both is
still the first thing to try if anything looks stale.

---

## 1. Configure this first

Everything factual lives in [`config/siteConfig.ts`](config/siteConfig.ts).
Search the file for `[` — every bracketed value is a placeholder waiting for a
real one:

| Field | Notes |
| --- | --- |
| `modelName`, `modelReference` | Model identity |
| `specifications[]` | Case, movement, power reserve, water resistance |
| `phoneNumber`, `emailAddress` | Rendered as `tel:` / `mailto:` |
| `addressLines`, `openingHours` | Enquiry block |
| `officialUrl`, `buyUrl` | Leave empty and the links simply don't render |

**Nothing here is invented.** No model reference, specification, price or URL
has been guessed at. Until you replace a placeholder it renders as plain grey
text rather than becoming a broken `tel:`/`mailto:` link or a link pointing
somewhere fabricated.

The site also ships with `isOfficial: false` and a visible disclaimer in the
footer stating it is an independent concept presentation and not affiliated
with or endorsed by Rolex SA. If you have actual authorisation to present as
the brand, that is the line to change — otherwise leave it in place.

Narrative copy and the timing of every card live in
[`config/storyboard.ts`](config/storyboard.ts).

---

## 2. How the scroll engine works

The core idea is one number.

All five clips live in a single fixed, full-viewport stage
([`components/VideoStage.tsx`](components/VideoStage.tsx)) and share one scalar
timeline `T`, maintained by
[`lib/StageController.ts`](lib/StageController.ts):

```
T = sum of progress(chapter_i)        each chapter's progress ∈ [0, 1]
```

Chapters occupy disjoint, sequential slices of the document, so completed
chapters contribute exactly `1` and future ones exactly `0`. `T` is therefore
always `(chapters completed) + (progress through the current one)`. The integer
part picks the clip; the fractional part *is* that clip's `currentTime`,
normalised.

`play()` is never called on any element. There is no playback clock to fight
with, which is why reversing and freezing come for free rather than needing
special handling.

Three decisions are worth knowing about:

**Progress is sampled, not pushed.** ScrollTrigger's `onUpdate` fires on scroll
events, which get coalesced or dropped during a fast flick — leaving a chapter
stuck at `0.93` after the user has already blown past it. The controller reads
`trigger.progress` once per animation frame instead: cheaper, and always
correct.

**Only one clip is ever seeked.** Opacity is a one-sided ramp — a clip fades
*in* over the last 9% of the previous chapter, then stays opaque. Walking the
stack top-down and stopping at the first fully-opaque clip means that inside a
chapter exactly one clip is visible and decoding, and inside a seam two are
visible but the incoming one is pinned to its first frame while it fades up.
Two 720p streams are never scrubbed at once.

**Seeks are gated on completion.** A new `currentTime` is only assigned when
the previous seek has finished and the target has moved by at least half a
frame. That is what stops a fast scroll from queueing hundreds of seeks the
decoder can never service.

### Pinning uses `position: sticky`, not ScrollTrigger's `pin`

`pin` injects a pin-spacer and transforms the pinned node, changing document
layout at refresh time and re-measuring on resize — both of which can produce a
visible jump exactly at a chapter boundary. Native sticky is handled on the
compositor, cannot desynchronise from scroll, and costs nothing to set up or
tear down. ScrollTrigger still does all the coordination (measuring progress,
scrubbing the card timelines); it just isn't also asked to reimplement
`position: sticky`.

---

## 3. The video pipeline — read this before replacing the clips

The supplied masters each had **exactly one keyframe** (a single 8–10 second
GOP). That is the worst possible encoding for scrubbing: every *backward* seek
forces the decoder to restart from frame 0 and roll forward, which would have
made "scroll up to reverse" visibly stutter, badly so on mobile.

They were therefore re-encoded to **all-intra H.264** — every frame a keyframe,
so a seek to any point in either direction is immediate:

```bash
ffmpeg -i input.mp4 -an -c:v libx264 -preset slow -crf 25 \
  -pix_fmt yuv420p -profile:v high \
  -x264-params "keyint=1:min-keyint=1:scenecut=0" \
  -movflags +faststart output.mp4
```

Cost: about 2× the file size (~30 MB total for all five). Audio is stripped —
nothing is ever played. A poster frame per clip is extracted to
`public/images/` so the opening frame is painted before any video byte lands.

**If you swap in new footage, run it through the same command.** A normally
encoded MP4 will look fine going forwards and fall apart going backwards.

Loading is progressive: the hero clip is fetched eagerly, and each later clip
starts fetching about one chapter before it is needed. The loader waits only
for the first clip's first frame, with a hard 3-second ceiling.

---

## 4. Tuning the pacing

Chapter length *is* playback speed — a taller chapter means the clip advances
more slowly per pixel scrolled. Both values are per chapter in
`config/storyboard.ts`:

```ts
scrollVh: 320,        // desktop, in viewport heights
scrollVhMobile: 240,  // shorter, so phone scrolling never feels stuck
```

Card timings are expressed in **local chapter progress**, so copy lands on the
beat of the animation it describes rather than at an arbitrary scroll offset:

```ts
{ id: "dial", title: "The dial", from: 0.38, to: 0.66, placement: "right-lower" }
```

`from: 0` means "on screen from the first frame"; `to: 1` means "stay for the
rest of the chapter". Anything else fades in and back out.

Other knobs: `CROSSFADE` (seam width) in `config/storyboard.ts`; `SMOOTHING`
(scrub inertia — higher tracks the scrollbar more tightly) in
`lib/StageController.ts`.

---

## 5. Framing

The clips are 16:9 with the subject centred.

- **Landscape** — `object-fit: cover`. A 16:9-ish viewport crops essentially
  nothing.
- **Portrait** — `contain`, scaled 1.25× and lifted slightly above centre.
  Covering a 9:19.5 phone screen from a 16:9 master would show roughly a
  *quarter* of the frame's width, cutting the outer bracelet and component
  pieces out of chapters 02–04 entirely. A centred widescreen band keeps every
  component in frame and gives the copy the space beneath it. 1.25 is the most
  crop the widest chapter tolerates.

The footage is bright — silver water, pale sky — so the glass cards are *dark*
smoked panels rather than the usual white translucency. A light panel over that
footage washes out until the type inside stops being readable; a dark one
behaves like a neutral-density filter and holds contrast constant across all
five clips.

---

## 6. Accessibility

- Semantic landmarks, one `h1`, chapters as `h2`, cards as `h3`.
- Skip link to the enquiry details.
- Visible focus rings throughout; the mobile sheet moves focus to its first
  link, closes on `Escape` and on outside click, and returns focus to its
  toggle.
- Cards animate with GSAP's `autoAlpha`, so a faded-out card's links leave the
  tab order rather than becoming invisible focus traps.
- `prefers-reduced-motion`: the film is still scroll-driven — that is the
  user's own deliberate input, not autonomous motion — but scrub inertia,
  travel and parallax are dropped, and every chapter shortens to ~55% so the
  same story takes far less scrolling.

---

## 7. Layout

```
app/
  layout.tsx            fonts, metadata, skip link
  page.tsx              the five chapters in order
  globals.css           tokens, glass, stage framing, chapter heights
components/
  StageProvider.tsx     owns the controller, drives it from the GSAP ticker
  VideoStage.tsx        the fixed canvas: 5 clips + grade + outro scrim
  ScrollVideoSection.tsx  one chapter: scroll spacer + sticky copy layer
  GlassInfoCard.tsx     smoked-glass pane
  SectionIntro.tsx  AssemblySteps.tsx  FinalCTA.tsx
  Navbar.tsx  ProgressIndicator.tsx  ContactSection.tsx  Loader.tsx  Grain.tsx
config/
  siteConfig.ts         everything factual — configure this
  storyboard.ts         narrative, chapter lengths, card timings
lib/
  StageController.ts    the scrub engine
  gsap.ts  motion.ts
public/
  videos/  images/      all-intra clips + poster frames
```

Components that update every frame — the navbar's active marker, the chapter
rail, the assembly steps — subscribe to the controller and write directly to
the DOM. None of them holds scroll position in React state, so scrolling causes
no re-renders.

In development, `window.__stage` and `window.__gsap` are exposed for console
inspection. Both are stripped from production builds.

Running is very tricky.
