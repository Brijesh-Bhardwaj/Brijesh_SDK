# Summary

Describes steps to build the SDK.
iOS SDK is built as a Framework.

# Prerequisites

 - XCode 12.4 or higher 
 - Carthage 0.37.0 or higher 

# Manage Dependencies

- The OrderScrapper project uses *Carthage* for managing dependencies
- Using the 'Terminal', navigate to '<amazon_order_scraping_ios>/src/OrderScrapper/'
- Run command `carthage update --use-xcframeworks`. This will fetch dependencies into a 'Carthage/Checkouts' folder and build each one or download a pre-compiled XCFramework inside 'Carthage/Build'.
- The dependencies and paths are already configured in the project.

# Build SDK

- Open '<amazon_order_scraping_ios>/src/OrderScrapper/OrderScrapper.xcodeproj' project using XCode
- Select the 'OrderScrapper' scheme
- Select appropriate **target** for the scheme
- Build the SDK by choosing `Product -> Build`
- The built framework is copied to '<amazon_order_scraping_ios>/bin' directory on successful build as 'OrderScrapper.framework'

# Updating SDK

This section provides instructions to update the SDK version in case there are specific changes required in the application.

## Version 1.1.0

This version introduces Sentry library integration with the SDK. The following steps needs to be done to udpate it.

- Using the 'Terminal', navigate to '<amazon_order_scraping_ios>/src/OrderScrapper/'
- Run this command to update the carthage dependencies
  > carthage update sentry-cocoa
  > carthage build --use-xcframeworks --no-use-binaries  
- Install the sentry-cli: This step enables Sentry to upload dSYM file to symbolicate the crash logs.
     https://docs.sentry.io/product/cli/installation/
- Add the Sentry.xcframework dependency to the application at
  AppProject -> General -> Framework, Libraries, and Embedded Contents    

# Notes

- Currently, the framework is created for a single target only, either for the `Simulator` or for the `iOS device` 
- Hence to run the application, build the SDK accordingly for the desired target. 
