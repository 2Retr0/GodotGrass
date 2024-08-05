# Godot Third Person Camera

<p align="center">
  <a href="https://godotengine.org">
	<img src="TPC-doc-assets/ThirdPersonCamera.svg" width="200" alt="Godot third person camera icon">
  </a>
</p>


A Third Person Camera for Godot4.

[![Status](https://img.shields.io/badge/status-active-success.svg)](Status)
[![GitHub Issues](https://img.shields.io/github/issues/JeanKouss/godot-third-person-camera)](https://github.com/JeanKouss/godot-third-person-camera/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/JeanKouss/godot-third-person-camera)](https://github.com/JeanKouss/godot-third-person-camera/pulls)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](/LICENSE)

## 📝 Table of Contents

- [Godot Third Person Camera](#godot-third-person-camera)
- [📝 Table of Contents](#-table-of-contents)
- [❓ About](#-about)
- [🧤 How to use ?](#how-to-use)
- [📖 Documentation](#documentation)
- [Camera3D Properties](#camera3d-properties)

## ❓ About<a id = "about"></a>

This is a ready-to-use third person camera for your 3D games. It is also highly configurable and its configurability allows you to use it in multiple ways :
- Dynamic Follow
- Fixed Perspective
- Shoulder View
- Over-The-Shoulder View

## 🧤 How to use ?<a id = "how-to-use"></a>

1. Add the scene `ThirdPersonCamera.tscn` located at `addons\third-person-camera\third_person_camera` as child for you character node.
2. Twerk the properties to fit you need.

## 📖 Documentation <a id = "documentation"></a>

Take a look at the documentation in the [wiki](https://github.com/JeanKouss/godot-third-person-camera/wiki#-documentation)

## Camera3D Properties

All Godot `Camera3D` Properties are available. You can access to camera node by `get_camera()` method. Also, it exported variables are available in the editor.

![Camera3D properties image](TPC-readme-assets/doc/inspector.png)
