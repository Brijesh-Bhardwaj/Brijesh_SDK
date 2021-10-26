- Optimized code to handle multiple network callbacks simultaneously ensuring the webview doesn't reload the same login URL multiple times
- Removed the cool-off condition check in case the scraping is requested after notification click
- Optimized core data code to be thread safe using a synchronized thread handler ensuring the object is not accessed simultaneously by different threads


