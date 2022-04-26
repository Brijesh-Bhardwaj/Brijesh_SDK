# Steps

- Add the library to the cartfile 
  github "getsentry/sentry-cocoa" ~> 7.1.3
- To update the cartfile use the commands
- carthage update sentry-cocoa
- carthage build --use-xcframeworks -no-use-binaries 
- To upload the error logs to sentry URL
  -  Follow the steps for without-bitcode 
   https://docs.sentry.io/platforms/apple/dsym/?_ga=2.103799298.361840438.1625369633-1483733308.1625036729#dsym-without-bitcode
-Add the script file in SDK side path 
  -- To get auth-token follow path
  -- https://sentry.io/settings/account/api/auth-tokens/
  -- Add the script at  and Add input files at
   AppProject -> Build Phase -> New run script 
  -- To install the sentry-cli
     https://docs.sentry.io/product/cli/installation/
- Add the framework and its dependencies to the SDK at
 `AppProject -> General -> Framework,Libraries



 # Steps for Sentry Application
 - To create a new project
   Projects -> create Project -> Mobile -> IOS
   - Add the project name
- To check the issues
  Issues -> issue name
  you can check the issue with different environment with selecting speicific environment at the top
- To check the thread stack
  Issues -> issues name
  under that you can change the options to App only, Full, Raw to check thread stack trace
- To check issues for specific environment you 
  change from ALL Environment
- You can check the Environment and Build Name 
  and Build Id in the below the specific issue
  

