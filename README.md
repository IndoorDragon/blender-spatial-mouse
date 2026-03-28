# Blender Spatial Mouse

🚧 **WORK IN PROGRESS** 🚧

Blender Spatial Mouse is a system that allows you to control Blender using your phone as a spatial controller.

It consists of two main components:

- 📱 **Mobile App (Flutter)**  
  Uses your phone’s motion sensors and/or AR tracking to send movement data.

- 🧠 **Blender Add-on (Python)**  
  Receives that data and applies it to objects, bones, or the camera in Blender.

---

## 🎯 Goal

Turn your phone into a 6DOF (six degrees of freedom) controller for Blender

---

## 🧩 Project Structure

blender-spatial-mouse/
mobile_app/ #Flutter mobile application
blender_addon/ # Blender Python add-on

---

## 🚀 Current Status

- ✅ Basic communication between app and Blender (TCP)
- ✅ Object / pose control working
- 🚧 UI improvements in progress
- 🚧 App store release not yet available

---

## 📦 Installation (Current)

### Blender Add-on

1. Zip the `blender_addon/` folder
2. In Blender:
   - Go to **Edit → Preferences → Add-ons**
   - Click **Install**
   - Select the zip file
   - Enable the add-on

---

### Mobile App

Currently not released.

To run manually:

```bash
cd mobile_app
flutter run
```

🛠 Tech Stack
Flutter (Dart)
Blender Python API
TCP socket communication
iOS (ARKit / motion tracking)
Android (WIP)

⚠️ Disclaimer

This project is experimental and under active development.
Expect bugs, breaking changes, and incomplete features.

📜 License

This project is licensed under the GNU General Public License (GPL).

