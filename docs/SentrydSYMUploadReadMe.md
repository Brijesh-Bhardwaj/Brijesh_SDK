# Introduction

The document describes steps to upload the Debug Symbols(dSYM) and BCSymbolMap files to Sentry to show symbolicated error stack.

## Uploading Debug Symbols

Debug Symbol files can uploaded automatically using App Store Connect integration, Fastlane integration or through XCode. It can
also be uploaded manually using sentry-cli.

### With Bitcode (Manual)

Both the SDK and the Coinout app is built with bitcode enabled. The dSYM file is available in the App Store Connect 
after it processes the build.

- After uploading the build, open App Store Connect.
- Go to TestFlight tab and select the uploaded build number.
- Go to *Build Metadata* tab and search for *Includes Symbols*
- Click on Download dSYM
- If the files are downloaded as a zip, unzip it to a folder.
- Open terminal and follow the below instructions. sentry-cli should be installed if not already.
- If sentry is on-prem, then set the sentry url in terminal using the command:
  > export SENTRY\_URL=<on-prem-sentry-url>
- Run the following command to upload the dSYM files:
  > sentry-cli --auth-token <AUTH-TOKEN> upload-dif --org <ORG-NAME> --project <PROJECT-NAME> <DSYM-FOLDER-PATH>
- Replace:
  AUTH-TOKEN with the Auth Token created in Sentry. For QA sentry the value is `220812aa8d294c4d9ca1044249947c152e96e7e0ee744eb18165dcd9ccf59b26`
  ORG-NAME with the Organization name set in Sentry. For QA sentry the value is `blackstraw`
  PROJECT-NAME with Project Name set in Sentry. For QA sentry the value is `coinout-ios`
  DSYM-FOLDER-PATH with the path to the folder where dSYM files are downloaded and extracted
- Run the above command with .xcarchive path to upload the BCSymbolMap file.

### Without Bitcode (Using XCode)

Your project’s dSYM can be upload during the build phase as a “Run Script”. For this you need to set the DEBUG\_INFORMATION\_FORMAT 
to be DWARF with dSYM File. By default, an Xcode project will only have DEBUG\_INFORMATION\_FORMAT set to DWARF with dSYM File in 
Release so make sure everything is set in your build settings properly.

For more information visit: https://docs.sentry.io/platforms/apple/dsym/