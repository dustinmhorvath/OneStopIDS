# OneStopIDS
### Single machine, single interface intrusion detection.
- Downloads, builds, and installs Suricata IDS, Barnyard2 log/database-parser, and Snorby web-ui frontend.
- Built and tested for Debian 8 Jessie 64-bit.
- This implementation is currently in **BETA**. Has been confirmed working on clean install of Debian 8, though has only been tested in a limited environment. Expect revisions.

### Install:
- Execute `install.sh`. Requires sudo privileges.
- Install takes a **long time**. Expect a setup time anywhere from **30 to 120 minutes**, depending on your hardware.
- You'll need to use routing to mirror traffic from the network in question to the machine running OneStopIDS. This can be accomplished with router-supported port mirroring or by using firewall rules such as:
`iptables -t mangle -A POSTROUTING -d 0.0.0.0/0 -j ROUTE --tee --gw $MACHINE_IP_HERE`
`iptables -t mangle -A PREROUTING -s 0.0.0.0/0 -j ROUTE --tee --gw $MACHINE_IP_HERE`

### Requirements:
1. 2170 MB free disk space
2. 1 GB ram
3. ~2?GB swap space for compilation
- Note: considerable memory is used for compiling ruby gems, which generally fail gracefully but with unhelpful error messages when memory is filled. Actual required *running* memory is likely much lower, so this can be reduced for a physical machine or VM after Snorby deployment.

### Components:
1. [Suricata](https://suricata-ids.org/) is a next-generation intrusion detection system that supports multi-core architectures as well as additional performance enhancements, and can be considered a more sophisticated version of Snort.
2. [Barnyard2](https://github.com/firnsy/barnyard2) is a log-parser that can convert Suricata's output detection logs into database entries. It stores these entries with MySQL.
3. [Snorby](https://github.com/Snorby/snorby) is a web-ui frontend built using Ruby on Rails. It is relatively complex and relies on quite a few dependencies to be built from source. It's capable of interpreting Barnyard2's database entries (which also work with Snort), and can perform rule lookups using Suricata's ruleset. It supports multiple users, alerts, emails, and other useful features.

### Utilizes:
- Apache
- Ruby
- Rails
- MySQL
- Git
- wkhtmltopdf
- Nokogiri
- Passenger
