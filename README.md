# Update-LatestAdoptiumJavaHome
This script will automatically check the base folder version for Eclipse Adoptium and update the specified Environment Variables needed, along with restarting Windows Services. 

We had an issue when automatically patching Eclipse Adoptium, where our Azure Build Servers would fail to build because of the version mismatch with Java.   

Just run this script as a scheduled task every morning.
