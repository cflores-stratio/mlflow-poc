# generación de imagen base para el entrenador (environment) de mlflow: Contiene las librerías que se necesita para entrenar:
```
docker build -t mlflow-python-docker-trainer:rocket -f docker/Dockerfile .
```


# entrenamiento de mlflow con docker
· dentro de la carpeta docker-model contiene MLproject y script de entrenamiento
- MLproject contiene la definición del environment que se va a usar para las ejecuciones, en este caso es docker, se define la imagen generada previamente. 
    - ejecución del entrenamiento:
    `
    mlflow run docker-model -P alpha=0.5
    `
# generate mlflow docker server:
```
docker build -t mlflow-server -f docker-server/Dockerfile docker-server/
```

# guardar imagen docker
```
docker save -o mlflow-server.tar mlflow-server:latest
```

# subida al cluster
```
scp  mlflow-server.tar  bootstrap.golf.hetzner.stratio.com:/tmp/
```

# distribuir imagen en el cluster
```
hosts=("10.130.15.101" "10.130.15.102" "10.130.15.103" "10.130.15.104" "10.130.15.105" "10.130.15.106" "10.130.15.107" "10.130.15.108" "10.130.15.109" "10.130.15.110" "10.130.15.111" "10.130.15.112" "10.130.15.113" "10.130.15.114" "10.130.15.115" "10.130.15.116")
sudo su
for host in ${hosts[*]}; do echo "scp -i /stratio_volume/key.pem /tmp/mlflow-server.tar operador@${host}:/tmp/";  done
```


# exponer mlflow model como microservicio
```bash
docker run -it --rm -v $(pwd)/mlruns/0/2021c5de3f0a406f9ba8ee63c2352b06/artifacts/xgb_mlflow_pyfunc:/models -p 1234:1234 mlflow-server:latest
```

```bash
docker run -it --rm --net host -e MODEL_URL="http://localhost:8000/mlflow-model.zip" mlflow-server:latest
```
# explotar vía API
```
mlflow_server="mlflow-project-mlflow-xgboost-model0-mleap0130.mlmodels.rocket-antonio.tenant1.marathon.mesos"
```
```
curl -X POST -H "Content-Type:application/json; format=pandas-split" --data '{"columns":["alcohol", "chlorides", "citric acid", "density", "fixed acidity", "free sulfur dioxide", "pH", "residual sugar", "sulphates", "total sulfur dioxide", "volatile acidity"],"data":[[12.8, 0.029, 0.48, 0.98, 6.2, 29, 3.33, 1.2, 0.39, 75, 0.66]]}' http://${mlflow_server}:1234/invocations
```

