# BlackStraw OrderScrapper iOS SDK - Changelog

All notable changes to OrderScrapper iOS project will be documented in this file.

# Structure of this changelog:

- Header2 texts (sections marked with `##`) are in this format - `[Version] - YYYY-MM-DD`
- Header3 texts (sections marked with `###`) could be either one of these:
  - Added : This section to enlist the additions/implementations 
  - Changed : This section to enlist the changes to existing implementations
  - Notes : Any extra notes/remarks for the release
  
## Unreleased
  ### Added
   - Changes added for consistent connection flow of instacart and walmart (RPA-752)
   - Added scrape time for order details  in the backend DB (RPA-756)
   - Issue fixes added for MOSP-513, MOSP-514,MOSP-515, MOSP-516
   - Issue fixes added for MOSP-517, MOSP-518 and MOSP-531
   
## [2.0.2] - 2022-01-19
   ### Added
   - Issue fix for user not able to connect instacart account (RPA-824)
   - Fixes added for the tickets RPA-689, RPA-692, RPA-710, RPA-711, RPA-713, RPA-743, RPA-755, RPA-757   
   
## [2.0.1] - 2022-01-03
   ### Added
   - bumped up the sdk version for multi-retailers features.

## [1.2.0] - 2021-12-15
  ### Added
   - Added new enum value connectionInProgress in AccountState enum. During connection flow on authentication completed updated account state as connectionInProgress  
   - In foreground scrapping on uploading all scrape orders updated account state as connected in DB and backend through API call
   
   ### Fixed
   - Issue fix for the account state changing to connectedButException in backgroundAuthentication (RPA-662)
   - Added ServicesStatusListener to handle the API down scenario from the SDK side. A callback given to the Application when the services are down.


## [1.1.9] - 2021-12-14
  ### Added
   - Sending input to API for switching scrapping type during manual scrapping/foreground scrapping
   - Instacart screen get visible for some time if we get any popup(like verification code and capcha) on screen
   - Instacart home screen get visible if we click on close or cancel button from the popup
   - Show error screen on getting failure for manual scrapping. Considering it will need UI changes for showing error screen. 

## [1.1.8] - 2021-12-10
  ### Added
   - Email validation updated which allows multiple dots after @ symbol
   - SDK provided an enum in the return value for the `fetchOrders()` method to the app stating the state of the scraping such as enqueued, in-progress etc. 
   - Static message updated on the Instacart login screen
   - Fixed added for the Instacart home screen get visible if we click on the close or cancel from the popup

## [1.1.7] - 2021-12-07
  ### Added
   - Added manual value in FetchRequestSource enum for manual scrapping. On receiving manual value as fetch request source in fetchOrders() from the app we are   doing foreground scrapping for all orders.
   - Labels and success messages updated on progress screen and success screen

## [1.1.6] - 2021-11-17

  ### Added
   - Added Walmart connect, disconnect and reconenct operations. Also added scrapping operations in both foreground and background
   - Added bug fixes related with the Walmart authentication
   - For Kroger added bug fixed in case of getting 'adblocker' error message during connection flow   
   - Added enhanced sentry logs which includes some additional attribute information and error logged as events 

## [1.1.5] - 2021-10-25
 
  ### Fixed
   - Optimized code to handle multiple network callbacks simultaneously ensuring the webview doesn't reload the same login URL multiple times
   - Removed the cool-off condition check in case the scraping is requested after notification click
   - Optimized core data code to be thread safe using a synchronized thread handler ensuring the object is not accessed simultaneously by different threads

## [1.1.4] - 2021-10-07
 
  ### Fixed
  - Sentry configs changes added such that if Sentry is enable in get_config API response then only Sentry will log the errors and events
  - Account state return as ConnectedButScrappingFailed to the app if account state is connected and scrapping is failing
  - Sentry configs changes added such that if Sentry is enable in get_config API response then only Sentry will log the errors and events

## [1.1.3] - 2021-09-17

  ### Fixed
  - On timeout update status API not getting called issue fixed 

## [1.1.2] - 2021-09-08

  ### Added
 - While scraping in background if user gets authentication challenge such as captcha, two-factor auth and approval auth, then maintained the scraping failure count in SDK and if in case the scraping failure count increases than the configured value then shown notification to user and on click of that notification navigated user to progress bar screen to handle auth challenge scenario.
 - Implemented configured cool-off period while scraping in background.
 - Implemented csv scraping in background mode if SDK gets configured scraping type as csv from backend.

## [1.1.1] - 2021-08-12
  
  ### Added
  - Static message on login screen for alerting the panelists for the csv file they will be sent after they connect their account.

## [1.1.0] - 2021-07-08

  ### Added
 - SDK developed with background scrapping, navigation code, amazon connection and order scrapping support.
 - Amazon orders are fetched by scraping of html content from orders listing and order details page.
 - Added public interfaces and classes to allow application to integrate with SDK.
 - Implemented code to connect to Amazon account using a hidden webview.
   Login/Connection code supports these scenarios:
   - Successful login with correct user-id and password
   - Login failure on wrong account or password
   - Captcha identification,unknown url identification and changing account state to connected with exception.
 - Data-Persistence code to save order listing details in database.
 - Integration with API/backend for
   - Retrieve the date-ranges to fetch the orders for a connected amazon account. 
   - Upload order details after fetching it.
 - JavaScripts for operations like:
   - Amazon login and evaluating login success/failure.
   - Navigating to order listing page
   - Retrieve the list of orders that needs to be scraped from the order listing page.
   - Retrieve order details by navigating to order details page for each order.
 - Configuration api integrated to make SDK timeout time configurable.
 - Implemented timeout functionality  in sdk, added timeout in between steps of sdk when trying to scrape the orders.
 - Shown an error message to user in case timeout exceeds the configured timeout time.

## [1.0.5] - 2021-07-15
  
### Added
  - SDK version updated to 1.0.5
  - Added the payment instrument column into CSV and remvoed the PII information.
  
## [1.0.4] - 2021-07-08

### Added
- SDK updated with the Sentry integration to log the events, errors and crashes
- Please check ReadMe.SDK.build.md file updated for Sentry changes  

## [1.0.3] - 2021-07-05
- SDK version updated to 1.0.3

### Added
- Configuration api integrated to make SDK timeout time configurable.
- Implemented timeout functionality  in sdk, added timeout in between steps of sdk when trying to scrape the orders.
- Shown an error message to user in case timeout exceeds the configured timeout time.
  
## [1.0.2] - 2021-06-25

### Changed
- Redirecting to order report page in case sign in URL is intercepted after authentication

## [1.0.1] - 2021-06-17
  
### Changed
- Modified the error message for AuthProvider

## [0.3.6] - 2021-07-15

### Added
- Sample app UI updated with the list of accounts of order source type amazon and instacart
- User can open login page of amazon and instacart by clicking respective button from the listing cell 

## [0.3.5] - 2021-06-07

### Added
- Implementation of user authentication in background using zero size webview
- Downloading of JS file and reading script from the file
- Scrapping of order listing page using JS script and inserted scrape details into DB
- Retrieve order details from DB and scrapping of order detail page one after another
- Uploading of scrape order detail page data to backend through API
- Completion/failure callback given to the caller after uploading of scrape order details data     

## [0.3.4] - 2021-06-01

### Changed
- Modified the shouldShowWebView method to return true on approval and OTP urls
- Removed the extra call for shouldShowWebView from the decidePolicy delegate method (In some edge cases, this delegate method was called incorrectly after didFinish method)

## [0.3.3] - 2021-05-26

### Added
- Added `OrderExtractorConfig` class to pass configurations to the SDK from the app. It includes base URL, app name and app version.

### Changed
- Modified the update_status API
- Removed build configurations from the SDK project.

## [0.3.2] - 2021-05-18

### Fixed
Fixed Github Issue #80: Fixed the memory leak which restricted the ViewControllers to deinitialize, thereby causing the web view to connect again on network change.

## [0.3.1] - 2021-05-14

### Added
- Network check added before showing error view. If network is not present then no network error view shown instead of error view.

## [0.3.0] - 2021-05-11

### Fixed
- Fixed Issue #71: compared the amazon ID received from the server and local DB and accordingly updated the local DB.
- ensured correct isFirstConnectedAccount flag is passed to the app
- disabled back button on success screen and set `shouldAllowBack` flag to false

## [0.2.9] - 2021-05-07

### Changed
- firstaccount flag coming in get accounts API response updated in DB object and given back in the callback to the app
- Error message given in the callback if user aborted the scrapping process

## [0.2.8] - 2021-05-05

### Added
- On error or network error screen callback added on the back button click with the exception type as userAborted  
- Back button disable while scrapping is going on and in case of any error or network failure back button enable on the progress screen
- ASLException updated with the optional ErrorType attribute.
- Event logs added for the event of the generate report and download report. User properties logging added for some important user values. 

### Changed
- Account connect event logging added when the csv gets uploaded successfully to the server. 

### Known Issue
- [Github Issue #64]: User not credited with points/spins When the user turn off internet and press back button in ongoing process in between step4 and step5.

## [0.2.7] - 2021-04-23

### Added
- added logic to show the webview in case any unknown url is encountered in the authentication step. For any other step, user is navigated back to login screen showing generic error message
- added logs for error scenarios encountered in the SDK flow
- In AccountDisconnectedListener protocol ASLException parameter added as error reason in the onAccountDisconnectionFailed callback method

### Changed
- the progress view UI element to have a border and padding

### Fixed
- added fix for stuck at step 1 by checking for the required element in the webpage and if not found then shown the web view to the user to proceed manually

## [0.2.6] - 2021-04-20

### Added
- added logic to remove the account from the local database for a panelist, if get account API returns empty value to ensure the disconnect status is synced across devices

### Changed
- changed the event logging text for account connected state

## [0.2.5] - 2021-04-17

### Added
- added back button on ConnectAccount screen. On back button click, user is navigated back to previous screen. No restriction is added even if connection process is in progress. 
- added handling for `forgotpassword` URL. Displayed the error message to user whenever this URL is encountered. This also solves the issue of user getting stuck on the connection steps when the approval sms is denied.

### Changed
- changed the No Network message to match the Application's message
- changed password text field type to `Unspecified` and kept default settings. This is done to test out the iOS 14.2 keyboard bug.

## [0.2.4] - 2021-04-16

### Added
- Build configuration for Dev, QA, UAT & Prod environment 

### Changed
- Login UI revamped as per the app specs
- Button background changed for success and failure views

## [0.2.3] - 2021-04-15

### Changed
- UI changes as per the provided specs including button background changes, icon changes and text changes

### Added
- Added show password feature
- Added additional flag `hasNeverConnected` in response to getAccounts() method for certain UI flows 

### Fixed
- Fixed issue with webcache not clearing 

## [0.2.2] - 2021-04-14

### Fixed
- Fixed issue with account and order status logging to the backend

## [0.2.1] - 2021-04-13

### Added
- OrderStatus enum added
- Order status param added in the register_connection and update_status API which pass the status of the order fetching process

## [0.2.0] - 2021-04-10

### Added
- Integrated the account management APIs: register account, update account and get list of accounts.
- Register connection API called on authentication failure also for the backend to keep track of connections.
- Logged the Never connected account state with backend for connection logging to NCP
- Added panelist id column in SDK DB
- DB queries in the SDK are based on panelist id

### Changed
- Modified the orderExtractionCallback to retun the Account object as well, with the firstConnection flag info
- Changed SDK internal DB schema and DB queries as per the new design

### Fixed
- Fixed the view offset issue while the keyboard is shown on the register account screen

### Notes:
- Since this release contains, DB schema changes. The app should be re-installed for the new SDK integration. DB versioning would be added in future releases.

## [0.1.9] - 2021-04-09

### Removed
- Removed Firebase library from SDK and used the analytics provider protocol to log the event in the app.

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
