@echo off
rem Double-click this to see the state of the gcode.supply gallery.
rem Read-only: it changes nothing and opens a summary page in your browser.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gallery-status.ps1" %*
