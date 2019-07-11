## Install some dependencies

```
sudo apt-get -t stretch-backports install golang
sudo apt-get install postgresql postgis libvips-dev nodejs
```

NodeJS at the time of the release of stretch had many security issues, best to use latest versions:
https://github.com/nodesource/distributions

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
go get github.com/adamboardman/react-markdown-concepts

### Pack the markdown-concepts dependency

```
cd go/src/github.com/adamboardman/react-markdown-concepts
npm install
npm run-script pack
```

### Install the npm dependencies

```
cd go/src/github.com/adamboardman/thinkglobally
npm install
npm install ../react-markdown-concepts/react-markdown-concepts-4.1.0.tgz
```

## Testing

Should always check that the tests are passing before committing:
```
go test ./store
go test ./server
```

Good to check the lint errors:
```
npm run eslint
```

## Debugging
To run the server locally you need to:
```
npm run start
go run main.go -debugging=true
```

## Compile for deployment
To compile on the server:
```
npm run build
go build main.go
./main
```

## Live server config - to run on port 3030
Expected to be running via a proxy on port 80