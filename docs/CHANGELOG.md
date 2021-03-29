# BlackStraw OrderScrapper iOS SDK - Changelog

All notable changes to OrderScrapper iOS project will be documented in this file.

# Structure of this changelog:

- Header2 texts (sections marked with `##`) are in this format - `[Version] - YYYY-MM-DD`
- Header3 texts (sections marked with `###`) could be either one of these:
  - Added : This section to enlist the additions/implementations 
  - Changed : This section to enlist the changes to existing implementations
  - Notes : Any extra notes/remarks for the release

## [Unreleased]

## [0.1.1] - 2021-03-26

### Fixed

- Fixed CSV column headers getting generated randomly, the order of the headers is fixed 
- Fixed the issue with Dark mode of the device, the SDK allows only Light mode

 ### Changed
 
- SDK interface changes: Refactored the design so that application code can just query the list of
   accounts and perform operation on the account from the list.
- Changed the hint label on the Connect Amazon Account screen for email and mobile number

## [0.1.0] - 2021-03-23

### Added

 - iOS SDK developed with UI design, navigation code, amazon connection and order fetching support
 - Amazon orders are fetched by using the b2b reports that allows to download order CSV files.
 - Added public interfaces and factory classes to allow application to integrate with SDK.
 - Implemented code to connect to Amazon account using a hidden webview.
   Login/Connection code supports these scenarios:
   - Succesful login with correct user-id and password
   - Login failure on wrong account/password
   - Captcha identification and rendering the captcha screen for user-intervention
   - Device-authorization identification and notifying user accordingly
 - Data-Persistence code to save amazon account details in database with encrypted format.
 - Implemented code to fetch list of account-ids with their respective states for application.
 - Provided support for disconnecting a connected account.
 - Integration with API/backend for
   - Retrieve the date-ranges to fetch the orders for a connected amazon account
   - Retrieve the list of headers that needs to be purged from the CSV i.e. PII data that needs to
     be removed from CSV file
   - Upload order CSV after fetching it
 - JavaScripts for operations like:
   - Amazon login and evaluating login success/failure.
   - Navigating to order report page
   - JS to select dates on the report generation page
   - JS to submit report generation request
 - Implementation for webview with delegates to handle the URL changes and 
   detecting the status from page loads
 - Added SDK UI for:
   - `Amazon login`: Appears first time until user is connected successfully.
   - `Connecting Account`: Appears as first-step when the amazon account details is used to login
   - `Fetching Reports` : Appears as steps 2 to 5, where the SDK is in background performing these 
      operations:
      - fetching date-range
      - exectuing JS to navigate to order reports page
      - executing JS to set date-ranges and other fields
      - executing JS to request report generation
      - downlaoding the order csv
      - editing CSV to remove the PII data
      - uploading the edited CSV to server
   - Error screens
     - Network failure screen
     - Generic error view
   
### Notes
 - This is the first internal SDK targeted for internal QA and feedback.
