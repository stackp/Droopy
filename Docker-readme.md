# How to use Droopy with docker
First build the container
```
docker build -t droopy .
```

Then run with
```
docker run droopy
```
With appropriate options added.
As an example, I run
```
docker run -d -v /path/to/datadir/on/host:/app/data -v /path/to/config/on/host:/app/config -p 8000:8000 --name droopy --restart always droopy
```

