# Sysadmin 2 Docker Networking Demonstration

## Docker compose method - DEPRECATED
```bash
cd dcompose-test/
docker compose up
```
- There is no current clean method for this- list docker networks and remove the offending ones to clean up after a run
- clean, works
- This is deprecated, i'm not going to be putting work into this

## Dockerfile method - Preferred method

- Make sure the network interface is correct in either `build.sh` or `autobuild.sh`

```bash
cd dfile-test
./clean.sh
./build.sh # to walk through the install
./autobuild.sh # to do the install without stepping through it
# if you need a reminder
cat reminder.md

# to run automated health checks
./check.sh
```

## File tree
```bash
.
├── dcompose-test
│   ├── app-bridge
│   │   └── html
│   │       └── index.html
│   ├── docker-compose.yml
│   ├── lan-web
│   │   └── html
│   │       └── index.html
│   └── logs
│       └── sample.log
├── dfile-test
│   ├── autobuild.sh
│   ├── bridge-app
│   │   ├── Dockerfile
│   │   └── html
│   │       └── index.html
│   ├── bridge-db
│   │   └── Dockerfile
│   ├── build.sh
│   ├── check.sh
│   ├── clean.sh
│   ├── failcheck.txt
│   ├── logs
│   ├── macvlan-web
│   │   ├── Dockerfile
│   │   └── html
│   │       └── index.html
│   ├── metrics-host
│   │   └── Dockerfile
│   ├── offline-worker
│   │   ├── Dockerfile
│   │   └── process-logs.sh
│   ├── reminder.md
│   ├── sample.log
│   └── successcheck.txt
└── README.md
c
16 directories, 21 files
```
