# Meal Screen Redesign — Team Plan

## Goal
Polish `MealScreen` to match the user's mockup description (frontend only).
Outer chrome exact; Main/Side dish content area is interactive UI shell (backend later).

## Roles
| Role | Owner | Deliverable |
|------|-------|-------------|
| Manager | orchestrator | Plan, keys contract, merge gate |
| Worker UI | hero + chrome | Short name, image, info card, actions |
| Worker Gradient | scrim painter | Theme-aware fading name overlay |
| Worker Tabs | dish section | Main/Side1/Side2 selection + circular placeholder |
| Tester Widget | widget tests | Keys, tab switching, not-found, RTL |
| Tester Perf | static review | No rebuild waste, cacheWidth, const |

## Layout (top → bottom)
1. AppBar: back · title · [cloud sync] [favorite]  (3 existing app icons family)
2. Short name (centered, bold)
3. Hero image 260h, 20px radius
   - Full name overlaid
   - Theme scrim (light→white / dark→black), soft alpha
   - Gradient fade: top edge into photo + trailing edge by text direction
4. Info rectangle: protein · carbs · prep time · budget chips (icons + labels)
5. Hairline separator
6. Dish tabs: Main / Side 1 / Side 2 (only show sides when data would exist; for now always show Main, optional sides via flags placeholder)
7. Selected-dish detail shell (notes-like card) — frontend stub
8. Circular decorative placeholder (empty UI)
9. Notes (if any) · Edit / Delete row

## Non-goals
- Backend dish composition payloads
- Redesigning "more favorites" interior
- New packages

## Keys contract (stable for tests)
- meal_screen
- meal_screen_back_button
- meal_screen_favorite_button
- meal_screen_body
- meal_screen_not_found
- meal_screen_short_name
- meal_screen_hero
- meal_screen_full_name
- meal_screen_info_card
- meal_screen_dish_tabs
- meal_screen_tab_main
- meal_screen_tab_side1
- meal_screen_tab_side2
- meal_screen_dish_panel
- meal_screen_circle_placeholder
- meal_screen_notes
- meal_screen_edit_button
- meal_screen_delete_button

## Merge gate
- Syntax clean (no escaped quote bugs)
- Widget tests green (or analyzable without flutter if SDK missing)
- Stay on arena/01a0c71b-daily-meal; open PR → main
