# NetConMonitor

This module assists with the creation of WMI subscriptions to monitor for, and log, new outbound network connections on one or more systems. Subscriptions can be either ephemeral (session only) or persistent, depending on whether the monitor needs to persist through reboots.

## Description

This module assists with the creation of WMI subscriptions to monitor for, and log, new outbound network connections on one or more systems. Subscriptions can be either ephemeral (session only) or persistent, depending on whether the monitor needs to persist through reboots.

## Introduction

## Requirements

## Installation

Powershell Gallery (PS 5.0, Preferred method)
`install-module NetConMonitor`

Manual Installation
`iex (New-Object Net.WebClient).DownloadString("https://github.com/merddyin/NetConMonitor/raw/master/Install.ps1")`

Or clone this repository to your local machine, extract, go to the .\releases\NetConMonitor directory
and import the module to your session to test, but not install this module.

## Features

## Versions

0.0.1 - Initial Release

## Contribute

Please feel free to contribute by opening new issues or providing pull requests.
For the best development experience, open this project as a folder in Visual
Studio Code and ensure that the PowerShell extension is installed.

* [Visual Studio Code](https://code.visualstudio.com/)
* [PowerShell Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)

This module is tested with the PowerShell testing framework Pester. To run all tests, just start the included build scrip with the test param `.\Build.ps1 -test`.

## Other Information

**Author:** Topher Whitfield

**Website:** https://github.com/merddyin/NetConMonitor
