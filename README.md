# MyMissionGame

## Elevator pitch

MyMissionGame: plan a budgeted Earth-Moon mission and watch liftoff, LEO, transfer, and lunar ops—making orbits, burns, and trajectories intuitive for middle and high schoolers before the textbook.

---

## Inspiration

Many STEM outreach tools focus on coding or robotics; fewer invite students to reason about **feedback, trajectories, and constrained design** the way real aerospace missions do. Orbital systems are a natural bridge: they are visual, consequential, and historically motivating (exploration, satellites, human spaceflight). This project exists to give younger learners a **low-friction first contact** with those ideas through gameplay rather than equations alone.

---

## What it does

- **Mission planning:** Players work within a **budget** to assemble **crew** and **cargo**, balancing costs against needs like food, water, health, and morale.
- **Cinematic Earth–Moon mission:** The main experience walks through scripted phases—**liftoff → LEO → transfer burn → lunar capture → lunar orbit**—so players see how a mission unfolds as a sequence of orbital regimes and maneuvers.
- **Orbital visualization:** The game includes **map-style cues** inspired by mission-planning tools (for example, predicted-path markers for transfer geometry), helping connect “what the rocket is doing” to “what the path looks like” in a 2D map view.

---

## How we built it

- **Engine:** [Godot 4.x](https://godotengine.org/) (project targets **4.6** with Forward Plus rendering; Windows uses **D3D12** where configured).
- **Language:** **GDScript** for gameplay, mission orchestration, and UI.
- **Structure:** A shared **`MissionState` autoload** carries planning data (budget, crew counts, cargo selections) between planning screens and the main mission scene. Core flight logic lives in **`earth_mission_controller.gd`**, with supporting modules under `assets/scripts/mission/` (geometry, camera routines, transfer/burn helpers) and `assets/scripts/orbit/` (2D conic/orbit helpers and overlays).
- **Physics:** The project is configured to use **Jolt** for 3D physics where applicable; the showcased Earth–Moon sequence is primarily **scripted 2D** motion along paths and tweens for clarity and teaching readability.

---

## Challenges we ran into

- **Teaching vs. realism:** Real astrodynamics is subtle; a hackathon-scale game has to **simplify** (2D map, scripted phases) while still **reading** as a coherent orbital story. Finding that balance took iteration.
- **Pipeline and scope:** Wiring **menu → planning → main scene**, shared state, and a polished camera/orbit readout in limited time meant hard choices about what to simulate vs. what to choreograph.
- **Presentation:** Making **transfers and burns** readable on a small viewport (640×360 with stretch) required tuning zoom, timing, and visual overlays so students are not lost in the frame.

---

## Accomplishments that we're proud of

- A **clear mission arc** from pad to lunar orbit that students can follow without a physics prerequisite.
- **Planning gameplay** that introduces **systems thinking** (budgets, trade-offs, multi-objective cargo) before the flight sequence.
- **KSP-style map cues** (e.g., transfer apsides) that connect intuitive “path shape” language to on-screen markers.
- Modular **GDScript** layout (`mission_*` helpers, orbit utilities) that keeps the high-level mission readable and extensible.

---

## What we learned

- **Orbital ideas are teachable when they are visible:** Small affordances (phased mission, predicted markers, camera framing) matter as much as the underlying math.
- **Godot 2D + autoloads** are a strong fit for rapid prototyping of **linear, cinematic tutorials** with a thin layer of shared state.
- **Outreach tools need a narrow promise:** We focused on intuition for **systems** and **orbital sequencing** rather than full n-body simulation.

---

## What's next for the game

- **Deeper teaching modes:** Optional labels or pauses that name each phase (LEO, Hohmann-style transfer, capture) and relate them to core concepts in **controls** and **systems** (feedback, constraints, planning under uncertainty).
- **Interactive sandbox:** Let learners tweak **burn timing** or **transfer windows** within safe bounds and see the predicted path update.
- **Accessibility and classroom use:** Larger UI presets, teacher notes, and short “discussion prompts” for club or classroom settings.
- **Content expansion:** Additional mission profiles (e.g., Earth orbit-only tutorials, satellite deployment vignettes) built on the same orchestration pipeline.

---

## Running the project

1. Install [Godot 4.6](https://godotengine.org/download) (or matching 4.x for this repo).
2. Open the project folder in Godot (**Project → Import** if needed).
3. Run the main scene (**F5**); the entry point is configured as `res://assets/levels/main_menu.tscn`.

---

*This README reflects the educational mission of the project: to give middle and high school students an engaging first exposure to **orbital systems** as a gateway to **systems and controls engineering**.*
