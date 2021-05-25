
# Summary

This readme describes the OrderScrapper SDK for iOS.

OrderScrapper is an SDK/library that provides Order fetching capability from eCommerce sources.

For iOS, the library is provided as a Framework.


# Overview of SDK features

## Account  
Currently supported order sources are 
- Amazon

SDK provides accounts API to:
- get the list of accounts registered through the SDK with its respective state
- register a new account by connecting to it by providing necessary credentials

### Account connect procedure

#### Amazon

SDK connects to the provided amazon account credentials as below
- User is presented with an account-connection screen to enter amazon credentials
- SDK reads the credentials and hits the amazon website to log in.  
 The user is presented with a "Connect Account" screen with a progress bar indication
- While login, if a captcha, device-authorization, or two-factor authentication screen is detected then the user is presented the amazon webpage with the details to proceed further.
- On login failure user is redirected to the previous screen and the failure event is registered in the backend database
- On successful login, the SDK attempts to fetch the order details.
- On fetching failure, the SDK shows an error screen and prompts the user to retry the operation
- On fetching success, the account credentials are stored in an encrypted format on the device private to the application, and the success event is registered in the backend database

## Orders

Currently supported order sources are 
- Amazon

SDK provides order fetch feature through :
- Order report generation page by downloading the order items in a CSV format
- Order history extraction by background scrapping in which order data extracted from html pages 

### Orders fetching mechanism

#### Amazon

SDK fetches orders as a CSV file from Amazon's order-report generation page as below:
- For the current panelist-id and amazon-id, SDK fetches the desired start and end dates of reports from API.
- Hits the amazon [[order-generation page]](https://www.amazon.com/gp/b2b/reports)
- SDK injects and executes scripts to initiate a "Report request" by filling appropriate
 field values as below:
 - Report Type: "Items"
 - Start-Date: _as received from api_
 - End-Date: _as received from api_
- SDK hooks to callbacks to identify report generation readiness. Once a report is available it is then downloaded to an app internal storage location.
- The downloaded report (CSV) is edited to delete any personal/PII-related data from it. The identification of PII data columns is configurable through `PII` related APIs in the server.  
 **Note that the personal data is NOT read or stored on the device. It is deleted from the CSV**
- The edited CSV is then uploaded to the backend through an upload API.
- Post upload irrespective of failure/success, the file is deleted from the internal storage too.

# Notes

- Downloaded order reports are always deleted after upload. 
- While the order fetch is in progress, it is mandatory for users to keep the app running in the foreground and let it finish the operation.
- Configurations in the backend determine the frequency of fetch and the start date for order reports.  
 Hence if the API responses indicate no scraping for a particular request then the SDK would redirect users back to the previous screen with an appropriate message.
- Some dependencies needed by the library will have to be linked into the application. More details in ReadMe.app.md
- For event logging/analytics, the SDK utilizes the application's event logging/analytics mechanism. The application should implement the provided SDK protocol method to log the SDK events.
- Background order scrapping done only for already connected accounts and no user interaction needed in this type of scrapping
 

# Usage 

- Refer to ReadMe.SDK.build.md file for SDK build instructions
- Refer to ReadMe.app.md for instructions on integrating the SDK with an application
- Refer to sample code under `samples/AmazonOrderScrapper` for a sample application that integrates the SDK
