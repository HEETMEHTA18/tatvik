# Design System

## Design Philosophy
Tatvik should feel like a premium developer cockpit: calm, intelligent, and highly polished. The interface should combine the clarity of Linear, the responsiveness of Raycast, the depth of Apple VisionOS, and the professional density of GitHub Mobile.

The visual language is **dark-mode-first** with translucent surfaces, subtle glow, restrained motion, and strong hierarchy.

## Brand Attributes
- **Premium**: refined surfaces, elegant motion, and consistent spacing.
- **Trustworthy**: clear data presentation and predictable interactions.
- **Intelligent**: AI outputs must be structured, explainable, and confidence-aware.
- **Developer-centric**: code, stats, repository cards, and technical insights should feel native to developer workflows.

## Color System

### Base Colors
- **Background:** `#0A0A0F`
- **Primary Accent:** `#5B8CFF`
- **Secondary Accent:** `#8B5CF6`
- **Success:** `#22C55E`
- **Warning:** `#F59E0B`
- **Error:** `#EF4444`

### Surface Tokens
- **Card Fill:** `rgba(255,255,255,0.08)`
- **Glass Border:** `rgba(255,255,255,0.12)`
- **Glass Blur:** `20px`
- **Elevated Surface:** slightly brighter than card fill for focus states

### Semantic Usage
- **Primary accent** for key actions, links, progress, and active states.
- **Secondary accent** for AI and roadmap highlights.
- **Success** for completed milestones and positive growth signals.
- **Warning** for opportunities and medium-priority recommendations.
- **Error** for failed syncs, auth issues, and destructive actions.

## Typography

### Font Families
- **Primary UI:** Inter
- **Display / brand feel:** SF Pro Display where available

### Type Scale
- **Display:** 48–64 px, bold, tight letter spacing
- **H1:** 32–40 px, semibold
- **H2:** 24–28 px, semibold
- **H3:** 18–20 px, semibold
- **Body:** 14–16 px, regular
- **Caption:** 12–13 px, medium

### Typography Rules
- Prefer short, declarative headings.
- Use body copy sparingly on cards and dashboards.
- Use numeric emphasis for scores, percentages, and milestones.
- Maintain strong contrast on dark surfaces.

## Spacing and Layout

### Spacing Scale
- `8`
- `16`
- `24`
- `32`
- `48`

### Layout Principles
- Use a 12-column mental grid on larger layouts and stacked sections on mobile.
- Maintain generous outer padding.
- Use vertical rhythm to separate sections instead of heavy dividers.
- Group content into cards and clusters with consistent gaps.

## Corner Radius
- **Primary radius:** `24px`
- **Secondary radius:** `16px`
- **Small controls:** `12px`

Use rounder corners for major surfaces and tighter radii for pills, chips, and compact buttons.

## Glassmorphism Guidelines
- Backdrops should blur background layers subtly, not obscure content.
- Borders should remain visible but thin.
- Surfaces should feel layered, not flat.
- Use shadows sparingly and keep them soft.
- Combine blur with faint radial glow accents for hero areas.

## Motion System

### Motion Principles
- Smooth and fast enough to feel responsive.
- Avoid bouncy motion unless it supports delight.
- Animate content hierarchy, not decoration alone.

### Motion Patterns
- **Page transitions:** fade + slide.
- **Hero transitions:** shared element / Hero animations.
- **Floating cards:** gentle parallax or floating offset.
- **Micro-interactions:** press scale, chip selection, pulse on success.
- **Loading states:** skeletons and shimmer for data-heavy cards.

## Component Library

### Core Components
- App shell
- Glass card
- Stat card
- Score badge
- Progress ring
- Heatmap grid
- Repository card
- Roadmap timeline item
- Message bubble
- Prompt suggestion chip
- Empty state panel
- Error state panel

### Button System
- **Primary:** solid accent fill
- **Secondary:** transparent glass surface
- **Tertiary:** text-only action
- **Destructive:** error accent

### Form Controls
- Use floating labels or compact labels above fields.
- Keep helper text concise.
- Provide inline validation feedback.

## Data Visualization Rules
- Prefer compact charts optimized for mobile.
- Use a limited palette so data categories remain readable.
- Annotate charts with legends, labels, and trend deltas.
- Keep charts visually soft to match the glass design.

## Accessibility Standards
- Maintain contrast-friendly text on all surfaces.
- Support text scaling.
- Ensure all interactive elements have semantic labels.
- Never communicate status by color alone.
- Provide visible focus states for keyboard and accessibility navigation.

## Design Inspiration Mapping
- **Linear** — hierarchy, spacing, polish
- **Raycast** — command-style density and speed
- **Apple VisionOS** — translucency and depth
- **Arc Browser** — distinctive accent treatment
- **Notion Calendar** — clarity in dense scheduling / roadmap views
- **Vercel** — dark premium surfaces and crisp CTAs
- **Stripe Dashboard** — data-rich layout and trust
- **GitHub Mobile** — repository-native presentation

## Implementation Notes for Flutter
- Use Material 3 as the base system.
- Prefer reusable theme tokens over hard-coded values.
- Centralize colors, spacing, and radii in `core/theme/`.
- Implement glass surfaces with `BackdropFilter` and translucent fills.
- Keep animations lightweight to preserve frame rate.
