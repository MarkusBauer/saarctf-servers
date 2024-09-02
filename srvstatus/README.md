# About

Small python script that gets systemd service information by calling 
`systemctl status <service>`, parses the output into json and prints it.
Services to check are defined in `$PWD/settings.ini`. 

# What for?

Invoked by telegraf (see `telegraf.d/systemd.conf`) to collect information about 
services.
