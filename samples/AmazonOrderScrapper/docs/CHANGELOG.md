# BlackStraw AmazonOrderScrapper iOS application - Changelog

All notable changes to AmazonOrderScrapper iOS sample application will be documented 
in this file.

# Structure of this changelog:

- Header2 texts (sections marked with `##`) are in this format - `[Version] - YYYY-MM-DD`
- Header3 texts (sections marked with `###`) could be either one of these:
  - Added : This section to enlist the additions/implementations 
  - Changed : This section to enlist the changes to existing implementations
  - Notes : Any extra notes/remarks for the release

## [Unreleased]

## [0.1.5] - 2021-03-31

### Added
- Progress view added on login screen

### Fixed
- Login screen email and password validation
- Disconnect word should show completely
- Connect account screen header text alignment 


## [0.1.4] - 2021-03-29

### Fixed
- Fixed typos in the UI labels

### Changed
- Added Scrapper SDK version 0.1.4

## [0.1.3] - 2021-03-29

### Added
- Added alert to show message generated from the SDK

### Changed
- Added Scrapper SDK version 0.1.3

## [0.1.2] - 2021-03-28

### Changed
- Added Scrapper SDK version 0.1.2

## [0.1.1] - 2021-03-26

### Fixed
 
- Fixed the issue with Dark mode of the device, the app allows only Light mode
- Fixed the white bar being present in the Accounts list page

 ### Changed
 
- Changed the app icons

## [0.1.0] - 2021-03-23

### Added

- iOS sample application developed with UI design, navigation code, amazon connection 
   and order support
- The Sample application is linked with OrderScrapper framework library as its dependency
- Integration with SDK for
   - Connecting a Amazon account
   - Fetching order CSV and uploading to the backend
   - Provision to initiate order fetch if account is already connected
- Added UI and implementation for:
   - Panelist account details
   - List of amazon accounts connected with option to initate order fetch
   
### Notes
- This is the first internal APK targeted for internal QA and feedback.
- Currently the panelist-id and auth-token combination is used in the application.
   - A hard-coded Auth-Token is pre-populated that can be edited on the app login screen.
