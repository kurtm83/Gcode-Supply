@echo off
rem Double-click this to add a YouTube video to the gcode.supply gallery.
rem It uses the link on your clipboard, or asks you to paste one.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gallery-add.ps1" %*
