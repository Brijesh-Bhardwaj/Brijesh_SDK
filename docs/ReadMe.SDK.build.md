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

# Notes

- Currently, the framework is created for a single target only, either for the `Simulator` or for the `iOS device` 
- Hence to run the application, build the SDK accordingly for the desired target. 
