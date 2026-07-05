# UNESCO World Heritage for Liquid Galaxy

## Table of Contents
1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Technologies Used](#technologies-used)
4. [Prerequisites](#prerequisites)
5. [Installation](#installation)
6. [Usage](#usage)

## Overview
UNESCO World Heritage for Liquid Galaxy is a Flutter-based Android application designed to work with the Liquid Galaxy rig, as part of Google Summer of Code. It provides an immersive, interactive, and educational experience to explore UNESCO World Heritage sites globally using the multi-screen Liquid Galaxy visualization system. 
Users can discover cultural and natural wonders through guided tours, dynamic AI interactions, and 3D visual representations.

## Key Features
- **Liquid Galaxy Integration**: Seamless connection with Liquid Galaxy rigs via SSH for a synchronized, immersive multi-screen view of world heritage sites.
- **Interactive Tour Guide**: Utilizes AI and Text-to-Speech to provide dynamic and informative voice-guided tours of different heritage sites.
- **Voice Commands**: Integrated Speech-to-Text allows users to control the application and navigate the map hands-free.
- **AI-Powered Insights**: Generative AI integration to answer questions, summarize site history, and enhance the educational aspect of the exploration.
- **3D KML Generation**: Dynamically creates and sends KML files to render rich 3D tours, points of interest, and geometry on the Liquid Galaxy screens.
- **Comprehensive Database**: Detailed information on numerous UNESCO World Heritage sites around the world.

## Technologies Used
- **Framework**: Flutter (Dart) - Natively compiled application framework by Google.
- **State Management & Architecture**: Riverpod (`flutter_riverpod`)
- **AI Integration**: Google Generative AI (`google_generative_ai`)
- **Voice Services**: Speech-to-Text (`speech_to_text`), Text-to-Speech (`flutter_tts`)
- **LG Connection**: SSH client (`dartssh2`)
- **Networking**: `http`, `cached_network_image`
- **UI & Animations**: `shimmer_animation`, `animated_text_kit`, Material Design

## Prerequisites
- Android device or emulator 
- Flutter SDK (^3.10.4)
- Liquid Galaxy rig (or virtual machine setup)
- Google Generative AI API Key

## Installation

### Building from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/LiquidGalaxyLAB/unesco-world-heritage.git
   cd unesco-world-heritage
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Check your environment:**
   Ensure your Flutter environment is correctly set up.
   ```bash
   flutter doctor
   ```

4. **Run the application:**
   Connect your Android device or start an emulator, then run:
   ```bash
   flutter run
   ```

5. **Build the APK:**
   To build a release APK for installation on your device:
   ```bash
   flutter build apk
   ```
   The APK file will be located in `/build/app/outputs/flutter-apk/app-release.apk`.

## Usage
1. **Initial Setup:** Launch the app on your Android device.
2. **Connect to Liquid Galaxy:** Navigate to the settings and enter the Liquid Galaxy Master node's IP address, port, username, and password to establish an SSH connection.
3. **Explore Sites:** Browse the list of UNESCO World Heritage sites.
4. **Interactive Tours:** Select a site to send it to the Liquid Galaxy rig and listen to AI-generated insights via the Voice Guide.
