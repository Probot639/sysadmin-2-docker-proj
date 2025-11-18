# Sysadmin 2 Docker Networking Demonstration

## Docker compose method
```bash
cd dcompose-test/
docker compose up
```
- There is no current clean method for this- list docker networks and remove the offending ones to clean up after a run
- clean, works

## Dockerfile method (the demo for class)
```bash
cd dfile-test
./clean.sh
./build.sh
# if you need a reminder
cat reminder.md
```
- This one works pretty well for now
