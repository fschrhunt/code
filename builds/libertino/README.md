# Libertino Cafe — speculative marketing site

Pitch-ready static one-pager for **Libertino Cafe** (Wynwood, Miami).

> **Not the official website.** Speculative redesign concept only — no client approval claimed.

## Design

- Feel: warm industrial indulgence (board-formed concrete / stone bar)
- Palette: daylit foam paper · espresso ink · quiet matcha
- Type: Fraunces (display) + Sora (sans)
- Full-bleed hero with **Libertino** as the brand signal
- Mobile-first, `prefers-reduced-motion` respected

## Sections

1. Speculative banner (always visible)
2. Hero
3. Coffee / La Cabra
4. Daytime menu
5. Space
6. Visit (address, phone, hours, Instagram)

## Business facts used

| Field | Value |
| --- | --- |
| Name | Libertino Cafe |
| Address | 220 NW 24th St, Miami, FL 33127 |
| Phone | (786) 913-1061 |
| Instagram | [@libertinocafe](https://instagram.com/libertinocafe) |
| Coffee | La Cabra specialty |
| Hours | Daily ~8am–8pm (**unverified** — confirm before visiting) |

## Placeholders

Images in `assets/` are generated stand-ins for atmosphere. Replace with real shop photos before any owner-facing pitch that implies photography ownership. Captions on the page call this out.

## Local preview

```bash
cd builds/libertino
python3 -m http.server 4173
# open http://localhost:4173
```

## Preview URL

Vercel project: [libertino-cafe](https://vercel.com/intuitum/libertino-cafe)

Shareable preview (SSO bypass, ~23h):  
https://libertino-cafe-fschrhunt-intuitum.vercel.app/?_vercel_share=q3XSTMG6qWM9024uzhAAgwBTfIoGI3qH

> Note: regenerate a share link via Vercel if expired. The deployment may need a refresh with inlined assets for anonymous viewing; full fidelity is always available by serving this folder locally.

## Stack

Static HTML / CSS / JS. No build step.
