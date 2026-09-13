---
name: Ambient Intelligence
colors:
  surface: '#131315'
  surface-dim: '#131315'
  surface-bright: '#39393b'
  surface-container-lowest: '#0e0e10'
  surface-container-low: '#1b1b1d'
  surface-container: '#1f1f21'
  surface-container-high: '#2a2a2c'
  surface-container-highest: '#353437'
  on-surface: '#e5e1e4'
  on-surface-variant: '#c2c6d6'
  inverse-surface: '#e5e1e4'
  inverse-on-surface: '#303032'
  outline: '#8c909f'
  outline-variant: '#424754'
  surface-tint: '#adc6ff'
  primary: '#adc6ff'
  on-primary: '#002e6a'
  primary-container: '#4d8eff'
  on-primary-container: '#00285d'
  inverse-primary: '#005ac2'
  secondary: '#a4c9ff'
  on-secondary: '#00315d'
  secondary-container: '#0267b8'
  on-secondary-container: '#d6e5ff'
  tertiary: '#bdc2ff'
  on-tertiary: '#131e8c'
  tertiary-container: '#7c87f3'
  on-tertiary-container: '#081486'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a42'
  on-primary-fixed-variant: '#004395'
  secondary-fixed: '#d4e3ff'
  secondary-fixed-dim: '#a4c9ff'
  on-secondary-fixed: '#001c39'
  on-secondary-fixed-variant: '#004883'
  tertiary-fixed: '#e0e0ff'
  tertiary-fixed-dim: '#bdc2ff'
  on-tertiary-fixed: '#000767'
  on-tertiary-fixed-variant: '#2f3aa3'
  background: '#131315'
  on-background: '#e5e1e4'
  surface-variant: '#353437'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 30px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
    letterSpacing: -0.005em
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0em
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.03em
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style
The design system delivers an ultra-clean, conversation-first mobile experience built for modern Android ergonomics. It prioritizes direct cognitive connection between user and intelligence: zero clutter, razor-sharp typographic hierarchy, and lightning-fast responsiveness. 

The aesthetic sits at the intersection of focused minimalism and deep-space digital precision. Surfaces feel physical yet weightless, using pitch-black backgrounds to merge seamlessly into OLED displays. Vibrancy is applied with absolute discipline—reserved exclusively for active voice processing, primary actions, and system states. The emotional tone is calm, authoritative, deeply capable, and frictionless.

## Colors
The palette is engineered specifically for high-contrast legibility in low-light environments and seamless OLED screen integration.

- **Canvas & Backgrounds:** Base canvas uses deep pitch black (`#0D0D0E`) and conversation stream background (`#131315`).
- **Elevated Surfaces:** Surface nesting follows three disciplined tiers: Card/Drawer tier (`#1A1A1E`), Interactive Surface (`#222226`), and Active/Hover state (`#2A2A30`).
- **Input & Controls:** The composer bar sits on `#212124` bounded by a crisp `#2E2E34` hairline border.
- **Text Tiers:** Pure `#FFFFFF` for primary user and agent speech; `#A1A1AA` for secondary meta-information and labels; `#71717A` for tertiary indicators, timestamps, and placeholders.
- **Accents:** Electric cobalt (`#3B82F6`) provides focused visual momentum, backed by sky cyan (`#60A5FA`) for micro-interactions and soft indigo (`#818CF8`) for multimodal voice listening glows.
- **Syntax & Code:** Code blocks occupy `#121214` with tokens in emerald (`#34D399`), cyan (`#38BDF8`), amber (`#FBBF24`), and violet (`#A78BFA`).

## Typography
Typographic rhythm is optimized for extensive reading sessions and markdown rendering. Inter provides clean letterforms with broad unicode support and neutral rendering across high-density mobile screens. JetBrains Mono is designated for all inline code, terminal snippets, and mathematical notation.

Paragraph spacing within markdown prose is set strictly to `12px` between nodes to maintain fluid reading momentum without fragmenting the message flow. Headings inside assistant responses remain compact to avoid artificial conversational bloat.

## Layout & Spacing
The layout adheres to an edge-to-edge mobile-first paradigm designed around Android 14/15 system gestures:
- **Vertical Hierarchy:** Status bar (safe area top), dynamic pinned conversational header, unbounded vertical scrolling message thread, floating bottom action bar, and the Android gesture navigation pill clearance (minimum 24px bottom buffer).
- **Horizontal Framing:** Chat streams conform to a 16px (`1rem`) outer margin. The input composer floats 8px above the keyboard or navigation pill, retaining 16px lateral padding.
- **Message Grouping:** Intra-bubble element spacing uses 8px (`space-sm`), between consecutive messages within the same sender role uses 8px (`space-sm`), and turn transitions (User to AI) expand to 24px (`space-xl`) to establish distinct conversational beats.

## Elevation & Depth
Depth is created through structured tonal layering and high-precision hairline dividers rather than aggressive drop shadows.

- **Base Thread:** Absolute background (`#0D0D0E`) sits at ground level.
- **Assistant Stream:** Renders directly on ground level with no enclosing bubble, allowing reading to feel borderless and unconstrained.
- **User Prompts:** Contained in elevated pills/rectangles (`#222226`) with a 1px border (`#2E2E34`) to clearly mark user ownership.
- **Persistent Input Dock:** Elevated at `#212124` with a hairline stroke (`#2E2E34`). An ultra-subtle ambient shadow (`rgba(0, 0, 0, 0.45)`, 12px blur, 4px Y-offset) separates the floating composer from the conversation stream passing beneath it.
- **Sheets & Drawers:** Modal drawers and history sheets layer at `#1A1A1E` over a 60% black scrim, bounded by a 1px top border (`#27272A`).
- **Voice Glow:** Multimodal voice mode triggers an ambient radial blur (48px blur, opacity 0.25) utilizing `#3B82F6` blending into `#818CF8`, centered behind the voice status indicator.

## Shapes
The shape philosophy is defined by pill forms and fluid continuous curves that harmonize with modern hardware corner radiuses. Fully rounded pill profiles (`roundedness: 3`) govern high-frequency interaction points—the main message prompt composer, prompt suggestion chips, action chips, and system toggles.

Conversational content containers, code panels, and bottom sheets adopt large rounded rectangles (`24px` to `28px`) to maintain structural grounding without harsh geometry.

## Components

### Persistent Input Composer
- **Container:** Floating pill container, min-height `52px`, background `#212124`, 1px solid `#2E2E34`.
- **Text Field:** Multiline auto-expanding (up to 6 lines before internal scroll), text `#FFFFFF`, hint text `#71717A`.
- **Action Icons:** 40px touch targets with 20px SVG icons. Left side houses attachment/camera tools; right side houses the dictate/send toggle. The send button transforms from a muted circle to an active `#3B82F6` pill button upon text entry.

### Conversation Stream & Message Bubbles
- **User Messages:** Right-aligned or right-indented rounded containers (`20px` radius, bottom-right tailored to `6px`), background `#222226`, text `#FFFFFF`.
- **Assistant Responses:** Left-aligned, unboxed canvas layout for maximum breathing space. Avatar mark is minimal (24px).
- **Inline Action Bar:** Sits directly below assistant responses. A muted row of 36px icon buttons (Copy, Regenerate, Thumbs Up, Thumbs Down, Share) using `#71717A` with hover/press background `#222226`.

### Action & Suggestion Chips
- **Geometry:** Height `36px`, pill-shaped (`9999px`), 12px horizontal padding.
- **Styling:** Background `#1A1A1E`, border 1px solid `#27272A`. Text in `label-lg` (`#A1A1AA`). Active state transitions to `#222226` with text `#FFFFFF`.

### Code Blocks
- **Header:** Height `36px`, background `#1A1A1E`, 1px border on top/sides (`#27272A`), rounded top corners (`12px`). Contains language tag (`label-sm`, `#A1A1AA`) and quick-copy icon button.
- **Body:** Background `#121214`, rounded bottom corners (`12px`), 12px padding, horizontal scrolling with hidden scrollbars. Monospace typography (`code-md`).

### Navigation & Bottom Sheets
- **Top Header:** Height `56px`, transparent to `#0D0D0E` blur, housing conversation title, drawer trigger (left), and model selector pill dropdown (center).
- **Bottom Sheets (History / Settings):** Surface `#1A1A1E`, top corner radius `28px`. Includes a centered drag handle (`36px` width, `4px` height, `#3F3F46`, `12px` top margin).