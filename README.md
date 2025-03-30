# Smart Attendance System Using BLE Beacons & Flutter App

This repository contains the code and documentation for the Smart Attendance System project developed for the Networks Protocols course (NETW703) at the Information Engineering & Technology Department. The project is supervised by Dr. Amr Talaat and Eng. Nawraz Saeed. It is developed as part of a multi-milestone project aimed at creating a Flutter application that utilizes BLE beacons to monitor and log student attendance.

## Overview

The project’s primary goal is to build a robust, scalable attendance system that leverages:
- **BLE Beacons**: For proximity detection.
- **Flutter App**: For cross-platform mobile functionality.
- **Firebase**: For user authentication and cloud data synchronization.

The system is implemented over two main milestones:
- **Milestone 1** focuses on setting up the basic Flutter app with BLE beacon scanning capabilities.
- **Milestone 2** introduces attendance logging, cloud integration, and a basic dashboard for viewing attendance logs.

## Features

### Milestone 1
- **User Authentication**: Secure login and registration using Firebase Authentication (via email/password or OAuth providers like Google/Facebook).
- **BLE Beacon Scanning**: Integration with the `flutter_blue_plus` package to scan for nearby BLE beacons.
- **Beacon Data Display**: The app detects beacons and displays their UUID and signal strength (RSSI) on the main screen.
- **Distance Calculation**: Approximate distance estimation between the device and the beacon to determine attendance status.
- **User Interface**: A simple, intuitive home page that provides access to beacon discovery and attendance functionalities.  

### Milestone 2
- **Attendance Logging**: Automatic logging of attendance details (student ID, class ID, beacon UUID, and timestamp) when a beacon is detected.
- **Cloud Integration**: Data storage and synchronization using Firebase (Realtime Database or Cloud Firestore).
- **Dashboard**: A basic dashboard for students to view their attendance history, including attendance percentages and absence levels.  

## Technologies & Tools

- **Flutter & Dart**: For cross-platform mobile app development.
- **Android Studio**: Primary IDE for development.
- **Firebase**: For authentication and backend services.
- **flutter_blue_plus**: Flutter package for BLE beacon scanning.
- **BLE Beacons**: Hardware devices configured with unique UUIDs and adjusted RSSI settings (5-10 meters detection range).
