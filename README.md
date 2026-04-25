# DjonStNix Vehicle Giver 🚗

A premium, secure, and intuitive vehicle generating tool strictly designed for **QBCore**. Generate a purely local, "ghost" preview of a vehicle, customize its primary/secondary colors and license plate in real-time, and securely push it to the database before physically spawning it into the world.

---

## ⚡ Features
- **Local Ghost Previews**: When an admin enters a model name, the script creates a transparent, non-networked collision-free vehicle allowing you to visually configure it without affecting the server state.
- **Dynamic UI Support**: Natively supports both QBCore standard wrappers (`qb-menu` & `qb-input`) AND modern interfaces (`ox_lib` contexts & inputs). Toggle freely via `Config.UseOxLib`.
- **Zero-Trust Synchronization**: Server aggressively dictates validation, ensuring color IDs remain in mathematical bounds (0-160), plate texts are uppercase clamped, and the model physically exists.
- **Plate Uniqueness Engine**: Performs asynchronous database sweeps prior to insertion. If a plate duplicate exists, it appends safe randomized data dynamically, preventing SQL Unique Constraint crashes while avoiding duplicate item assignments.
- **Immediate Ownership**: Saves straight to `player_vehicles` as JSON and spawns seamlessly, handing the admin keys automatically via QBCore native exports.

---

## 📦 Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qb-menu] _or_ [ox_lib] (Fully switchable in the config)
- [qb-input] _(if not using ox_lib)_

---

## 🛠️ Usage
1. Make sure you have the QBCore Admin permission attached to your citizen ID.
2. In-game, run the command **`/givevehicle`**.
3. Select "Change Vehicle Model" to spawn your initial ghost preview using any active vehicle hash (e.g., `sultan`, `adder`).
4. Modify the `Primary Color`, `Secondary Color`, and `Plate Text` to watch the modifications map live cleanly.
5. Click **Confirm & Spawn**. The ghost vehicle deletes locally, database transactions engage, and the new networked persistence vehicle drops out for you to drive.

---

## ⚙️ Configuration
Open `config.lua` to easily edit:
- **CommandName**: Modify the admin trigger command (Default: `givevehicle`)
- **UseOxLib**: Change to `true` to utilize modern overextended ox_lib UI elements or `false` for raw qb interfaces.
- **DefaultGarage**: Choose which persistent parking garage property data writes into (Default: `pillboxgarage`).
- **EnableLogs**: Set whether you want aggressive output prints inside your server runtime.

*Developed explicitly for the DjonStNix ecosystem.*
