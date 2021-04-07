# BlackStraw OrderScrapper iOS SDK - Changelog

All notable changes to OrderScrapper iOS project will be documented in this file.

# Structure of this changelog:

- Header2 texts (sections marked with `##`) are in this format - `[Version] - YYYY-MM-DD`
- Header3 texts (sections marked with `###`) could be either one of these:
  - Added : This section to enlist the additions/implementations 
  - Changed : This section to enlist the changes to existing implementations
  - Notes : Any extra notes/remarks for the release

## [Unreleased]

## [0.1.8] - 2021-04-08

### Added
- Added the AnalyticsProvider to delegate the event logging mechanism to the app, in case the app has implemented 
  any analytics. If there is no analytics implemented in the app, the SDK logs the event in Firebase as usual.

### Changed
- Modified the SDK fonts and color scheme based on the provided specs
- Changed the email label from 'Email or mobile number with country code' to just 'Email or mobile number'

## [0.1.7] - 2021-03-31

### Fixed
- Fixed issue with the reconnect flow

## [0.1.6] - 2021-03-31

### Fixed
- Alignment fixes for the UI screens

## [0.1.5] - 2021-03-31

### Added
- Login flow with API integration added
- File deletion/purging logic in the SDK

### Fixed
- Handling of out of range date/year for amazon order report page
- Date range does not match with the API and the generated order history report issue fixed
- 'Fetched' string updated to lowercase on receipts fetched successfully screen
- The "Fetching receipts" text displayed in the app is not aligned
- Cosmetic issues of keyboard and UI fixed
- When an unexpected error occurs, when clicked on the "Try Again" button, it starts 
  the process with step 1 but it is shown at the end of the progress bar
- Complete page was not visible on iPad while trying to enter amazon id and password  
- Getting an unexpected error during fetching the receipts

## [0.1.4] - 2021-03-30

### Fixed
- Fixed incorrect alert message when "enableScrapper" flag is set to false
- Fixed keyboard dismiss handling

### Changed
- Changed error messages and UI label strings

## [0.1.3] - 2021-03-29

### Fixed
- Fixed incorrect date-range values for order csv files uploaded for years later than the expected year.

### Added
- Integrated Firebase-Analytics in SDK
- Implemented code to handle "enableScrapper" property in date-range API. Fetch reports only if this property is set to `true`

### Changed
- Changed UI implementation from SwiftUI to UIKit

## [0.1.2] - 2021-03-28

### Fixed

- Trimmed the trailing white-spaces in user-entered amazon id
- Fixed the discrepancies observed between reports generated from the apk and amazon.com
  - Set the report-type to "ITEMS" explicitly without relying on the default
- Set the start-date and month as 1 if the oldest possible year on report generation page 
  is later than the expected year from daterange API.

### Added

 - Added code and JS to check the oldest possible year on report generation page, 
   and use that value if the API fetched start-year is older than the oldest possible value.

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
