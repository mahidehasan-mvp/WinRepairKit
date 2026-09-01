---
name: Fluent Precision
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#404752'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#717783'
  outline-variant: '#c0c7d4'
  surface-tint: '#0060ab'
  primary: '#005faa'
  on-primary: '#ffffff'
  primary-container: '#0078d4'
  on-primary-container: '#ffffff'
  inverse-primary: '#a3c9ff'
  secondary: '#006e06'
  on-secondary: '#ffffff'
  secondary-container: '#91f77e'
  on-secondary-container: '#007306'
  tertiary: '#af2e00'
  on-tertiary: '#ffffff'
  tertiary-container: '#da3c03'
  on-tertiary-container: '#ffffff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d3e3ff'
  primary-fixed-dim: '#a3c9ff'
  on-primary-fixed: '#001c39'
  on-primary-fixed-variant: '#004883'
  secondary-fixed: '#94fa81'
  secondary-fixed-dim: '#79dd68'
  on-secondary-fixed: '#002200'
  on-secondary-fixed-variant: '#005303'
  tertiary-fixed: '#ffdbd1'
  tertiary-fixed-dim: '#ffb5a0'
  on-tertiary-fixed: '#3b0900'
  on-tertiary-fixed-variant: '#872100'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  page-title:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  section-title:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-base:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-bold:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
  mono-data:
    fontFamily: jetbrainsMono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  sidebar-width: 280px
  container-padding: 32px
  gutter: 16px
  stack-gap: 8px
  section-gap: 24px
---

## Brand & Style

This design system is built upon the principles of **Modern Corporate Utility**, drawing heavy inspiration from Microsoft’s Fluent Design System. The brand personality is professional, authoritative, and stable, designed to instill confidence in users performing sensitive system repairs.

The aesthetic utilizes a refined mix of **Minimalism** and **Glassmorphism**. It avoids the aggressive, alarmist visual language typical of "PC cleaners," opting instead for the sober, technical clarity of a first-party Windows utility. The interface emphasizes structural hierarchy, subtle translucency (Mica-like effects), and precise alignment to create an environment that feels like an integral part of the operating system.

## Colors

The palette is centered on the standard Windows Accent Blue, ensuring instant familiarity. 

- **Primary Blue:** Used for primary actions, active navigation states, and focus indicators.
- **Semantic Logic:** Green is reserved for "Healthy" system states and successful repairs. Amber represents "Attention Required" without implying immediate catastrophe. Red is used sparingly for critical hardware failures or destructive "Reset" actions.
- **Neutrals:** A sophisticated range of grays provides the foundation. Backgrounds use a layered approach: a base white/off-white with subtle gray borders to define containers.

## Typography

As a replacement for Segoe UI Variable, **Inter** is utilized for its exceptional legibility and neutral, systematic appearance that matches the Windows 11 aesthetic. **JetBrains Mono** is introduced for technical data strings, file paths, and registry keys to provide a clear distinction between UI labels and system data.

Hierarchy is strictly enforced:
- **Page Titles** use semi-bold weights with slight negative tracking for a modern, grounded feel.
- **Body Text** stays at a compact 14px to allow for high information density without clutter.
- **Technical Detail** levels use 12px Mono to ensure long paths and hex codes are readable and distinct.

## Layout & Spacing

The design system employs a **Fixed Sidebar / Fluid Content** model. This mimics the Windows Settings app structure.

- **Desktop:** The sidebar is docked to the left (280px). Content resides in a fluid container with a max-width of 1200px to prevent excessive line lengths in technical reports.
- **Rhythm:** A strict 4px/8px grid governs all spacing. Elements are grouped into "Cards" with 24px internal padding.
- **Adaptive Behavior:** On smaller windows, the sidebar collapses into a hamburger menu or a slim icon-only rail (64px). Padding scales down from 32px to 16px on mobile-sized viewports.

## Elevation & Depth

Depth is achieved through **Tonal Layering** and **Low-Contrast Outlines** rather than heavy shadows.

- **Base Layer:** The application background is a solid neutral or a subtle "Mica" texture (back-drop blur if the host OS supports it).
- **Surface Layer:** White or light-gray cards sit atop the base. Instead of shadows, these surfaces are defined by a 1px border (`#000000` at 8% opacity).
- **Active States:** Subtle 2px "Lift" shadows (very diffused, 4% opacity) are used only for hovered interactive cards to indicate clickability.

## Shapes

The design system follows the "Soft" geometry of modern Windows apps. 

- **Containers:** Main cards and modals use 8px (`rounded-lg`) corners.
- **Controls:** Buttons and input fields use 4px (`base`) corners.
- **Status Badges:** Use a pill-shaped radius to distinguish them from interactive buttons.

## Components

### Buttons
- **Primary:** Solid Blue background, white text. No gradient. 
- **Secondary/Ghost:** 1px gray border with a subtle hover tint.
- **Destructive:** Transparent background with red text, shifting to a solid red fill only on hover/active states to prevent "Red Fatigue."

### Navigation Sidebar
- Uses a vertical list of icons + labels. The active state is indicated by a 3px vertical "pill" marker on the left edge and a light background tint.

### Info Cards & Risk Badges
- Cards should feature a 16px icon (top-left) and a title. 
- **Risk Badges:** Small, non-interactive chips using semantic colors (e.g., a "Needs Review" badge in Amber).

### Technical Detail Expanders
- Horizontal bars with a chevron. When expanded, the background shifts to a slightly darker gray (`#F9F9F9`) to encapsulate the technical data, which is set in monospaced type.

### Operation Lists
- Sequential rows for scan results. Each row should feature a checkbox, a status icon, and a "Details" link. Hovering a row highlights it with a subtle gray fill.