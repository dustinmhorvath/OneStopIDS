# SuricataBuilder
#####Downloads, builds, and installs Suricata IDS, Barnyard2 log/database-parser, and Snorby web-ui frontend.

#####This implementation is currently in BETA. Has been confirmed working on clean install of Debian 8, though has not been tested in any thorough manner. Expect revisions.

###Install:

- execute `install.sh`. Requires sudo privileges.
- Install takes a **long time**. Expect a setup time anywhere from 30 to 120 minutes, depending on your hardware.

###Requirements:

1. 2GB free disk space
2. 1GB ram
3. ~2?GB swap space, mostly for compilation
- Note: considerable memory is used for compiling ruby gems, which generally fail gracefully but with unhelpful error messages when memory is filled. Actual required *running* memory is likely much lower, so this can be reduced for a physical machine or VM after Snorby deployment.

###Utilizes:

- Apache
- Ruby
- Rails
- Git
- wkhtmltopdf
- Nokogiri
- Passenger
