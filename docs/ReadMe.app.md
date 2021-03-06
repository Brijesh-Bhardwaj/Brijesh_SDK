# Summary

Describes steps to integrate `OrderScrapper` SDK in mobile applications written using Native
iOS SDK.

SDK target is a Framework file that can be linked and embedded in the target iOS
applications.

The steps described here use XCode as the development and build tool.

Refer to our implemented application under `samples/AmazonOrderScrapper/` for integration.

# Prerequisites

- XCode 12.4 or higher
- Carthage 0.37.0

# Steps

## Link/Build settings

- Build the SDK framework by following steps enlisted in `ReadMe.SDK.build.md`
- Ensure that OrderScrapper.framework file is present under `<order_scrapping_ios>/bin` directory
- Open your target application in XCode
- Add the framework and its dependencies to the application at
 `AppProject -> General -> Framework,Libraries & Embedded Contents`
 Please note that the SDK is dependent on these three frameworks
 - Alamofire.xcframework
 - CSV.xcframework
 - RNCryptor.xcframework
 Hence these frameworks along with the `OrderScrapper.framework` must be embedded in the application.
- Ensure that the bin directory & frameworks download directory is added as the framework search path in the 'Build Settings' of the application project
 ```
 $(PROJECT_DIR)/../../bin
 $(PROJECT_DIR)/<path_to_xcframeworks_directory>
 ```

## Code integration

SDK provides a class named `OrdersExtractor`. Use this class for your initial
interactions with the SDK.

All protocols needed to be implemented by the application are
- AuthProvider
- ViewPresenter
- AnalyticsProvider (Optional)
- AccountDisconnectedListener
- OrderExtractionListener

### Initialization

- Write a class/extension to implement `AuthProvider` protocol, or implement the protocol in an existing
 class to provide functionalities related to Authentication-Token that are needed by the SDK for
 making API calls.

- Write a class/extension to implement `ViewPresenter` protocol, or implement the protocol in an existing
 class to provide functionalities related to View presentation that the SDK would internally call
 whenever needed to present a new screen to users during the account-registration and 
 order-fetching operations

- Create an instance of `OrderExtractorConfig` class and set these properties:
 - baseURL: The base URL for the SDK to communicate with the backend. The app must ensure that this URL is correct and is for the same environment as the app. This property is mandatory.
 - appName: The name of the application integrating the SDK. This property is utilized for analytics and logging purpose. This property is mandatory.
 - appVersion: The version of the current application. Also used for analytics and logging purpose. This property is optional.
 
 - Note: The application ViewController must present the SDK ViewControllers using 
 ```
 viewController.present(sdkViewController, animated: true, completion: nil)
 ```
 - Note: The application ViewController must dismiss the SDK ViewControllers using 
 ```
 viewController.dismiss(animated: true, completion: nil)
 ```

- If the app has implemented any analytics service like Firebase etc. then write a class/extension to implement `AnalyticsProvider` protocol or implement the protocol in an existing class to provide functionalities related to event logging for analytics. This protocol implementation is optional. 
   
- Initialize the library before calling its method as below
 ```
 OrdersExtractor.initialize(authProvider, viewPresenter, analyticsProvider?, orderExtractorConfig)
 ```
 parameters *authProvider*, *viewPresenter* and *analyticsProvider* are the references implementing `AuthProvider`,
 `ViewPresenter` and `AnalyticsProvider` protocols and orderExtractorConfig is the instance created above for passing the config information to the SDK.
 - Note: This method throws a runtime error in case the authProvider interface doesn't return a valid value
 in the implementation or in case the config is missing

- Once initialized you can use the static methods to invoke the functionalities provided by the SDK

- To connect to a new account call `registerAccount` method as below for different order-sources
 ```
 OrdersExtractor.registerAccount(.Amazon, orderExtractionListener)
 ```
 - Currently, the SDK supports `Amazon` , `Instacart` , `Kroger` and `Walmart` as an order source
 - orderExtractionListener is the reference implementing the OrderExtractionListener protocol.

- Once your application has registered accounts, they can be fetched back using `getAccounts`
 method.
 ```
 OrdersExtractor.getAccounts(.Amazon,.Instacart,.Kroger,.Walmart completionBlock)
 ```
 - Note that the SDK currently only supports 1 account connection at a time
 - Use the `accountState` property on the returned Account references to identify the current status of an account. The account status is represented by `AccountState` enum with these
  values:
  - NeverConnected : Account was never connected
  - Connected - Account is registered and connected successfully.
  - ConnectedAndDisconnected - Account is in a disconnected state now and was successfully connected before the SDK encountered issues with the account.
  - ConnectedButException - Account connected before but SDK encountered issues with the account.
  - ConnectedButScrappingFailed - Account is connected but the order scrapping is failing
  - ConnectionInProgress - Account is not connected and all connection time scrape orders are not uploaded
 - Use the `hasNeverConnected` flag, to check if the panelist has never connected any account before.
 
- To initiate an order-extraction operation on a connected account silently i.e without any UI and without user-intervention, use instance method `fetchOrders` on account reference as below:
 ```
 account.fetchOrders(orderExtractionListener, source: .general)
 ```
   - where orderExtractionListener is a reference implementing protocol `OrderExtractionListener`
   - for this method, the SDK invokes the background order scrapping mechanism
   - **the SDK uses the same protocol to provide callback for foreground and background mechanism of scrapping.  In order to distinguish between them, it is recommended to pass differerent protocol instances.** 
 
### SDK Callback Methods

- SDK provides callback methods to the application to notify the status of the operations.
- In order to find the status for `registerAccount` or `fetchOrders` operation, implement the `OrdersExtractionListener` protocol.
 It provides these callback methods:
 > func onOrderExtractionSuccess(successType: OrderFetchSuccessType, account: Account)
  
 This method is called when the user account is successfully connected and orders are extracted.
   
 > func onOrderExtractionFailure(error: ASLException, account: Account)
  
 This method is called when there is some failure in the registration and order extraction process.
  
 To find whether the account is the first connected account with a panelist, use the `isFirstConnectedAccount` property on the Account object returned in the OrderExtractionListener methods.
  
- In order to find the status for `disconnectAccount` operation, implement the `AccountDisconnectedListener` protocol.
 It provides these callback methods:
 > func onAccountDisconnected(account : Account)
   
  This method is called when the account is disconnected successfully
   
 > func onAccountDisconnectionFailed(account : Account, error: ASLException)
   
  This method is called when the account disconnection has failed  
  
- On calling fetchOrders() method from the application it will return RetailerScrapingStatus enum value
- RetailerScrapingStatus has three enum values:
  - InProgress : the retailer scraping is in progress
  - Enqueued : the retailer scraping is in queue 
  - Other : it is default value  
