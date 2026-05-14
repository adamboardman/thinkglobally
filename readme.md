## Install some dependencies

```
sudo apt-get install golang postgresql postgis libvips-dev elm-compiler uglifyjs
```

## Database

Need to create postgres users and database:
```
$ sudo -u postgres psql
$ sudo -u postgres createuser tgtest
$ sudo -u postgres createdb -O tgtest tgtest
$ sudo -u postgres psql
psql=# alter user tgtest with encrypted password '<password>';
$ sudo -u postgres psql tgtest
tgtest=# CREATE EXTENSION postgis;
```

Running the go tests or main.go the first time will create a file postgres_args.txt you should edit this file with your postgres database details:
```
host=localhost port=5432 sslmode=disable user=tgtest dbname=tgtest password=[...]
```

## Go dependencies

You'll need to get lots of go dependencies using something similar to:

go get golang.org/x/sys/cpu

## Testing

Should always check that the tests are passing before committing (do not run on the server):
```
go test ./store
go test ./server
```

## Debugging
To run locally you need to:
```
elm make client/Main.elm --output public/elm.js --debug
go run main.go -debugging=true
```

## Compile for deployment
To compile on the server:
```
elm make client/Main.elm --optimize --output=public/elm.js
uglifyjs public/elm.js --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | node_modules/uglify-js/bin/uglifyjs --mangle --output public/elm.min.js
go build main.go
./main
```

### Add as a systemd service
/lib/systemd/system/thinkglobally.service
```
[Unit]
Description=thinkglobally

[Service]
Type=simple
Restart=always
RestartSec=5s
User=user
Group=user
WorkingDirectory=/home/user/go/src/github.com/githubuser/thinkglobally/
ExecStart=/home/user/go/src/github.com/githubuser/thinkglobally/main

[Install]
WantedBy=multi-user.target
```

## Live server config - to run on port 3030
Expected to be running via a proxy on port 80/443

