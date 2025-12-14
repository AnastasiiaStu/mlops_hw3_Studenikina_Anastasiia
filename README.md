# ML Service Deployment with Blue-Green Strategy

## Создание структуры проекта - директорий и поддиректорий

```
ml-deployment-project/
├── app/
├── .github/
│   └── workflows/
├── nginx/
```
## Создание файлов в структуре

```
ml-deployment-project/
├── app/
│   ├── main.py
│   ├── model.pkl
│   └── requirements.txt
├── .github/
│   └── workflows/
│       └── deploy.yml
├── nginx/
│   ├── nginx.blue.conf
│   └── nginx.green.conf
├── Dockerfile
├── docker-compose.blue.yml
├── docker-compose.green.yml
└── README.md
```

## Настройка прав доступа 

```
cmd /c "icacls setup.sh /grant %USERNAME%:F"
cmd /c "icacls verify_setup.sh /grant %USERNAME%:F"
cmd /c "icacls test_script.sh /grant %USERNAME%:F"
```

###  Проверка окружения 

```
docker --version
docker ps
docker-compose --version
netstat -ano | findstr :80
```

###  Сборка Docker образов

```
docker build -t ml-service:v1.0.0 --build-arg MODEL_VERSION=v1.0.0 .
docker build -t ml-service:v1.1.0 --build-arg MODEL_VERSION=v1.1.0 .
```
### Переключение между версиями

```
# Если Green версия работает нормально
docker-compose -f docker-compose.green.yml up -d

# Откат на Blue при необходимости
docker-compose -f docker-compose.green.yml down
docker-compose -f docker-compose.blue.yml up -d

curl http://localhost/health
```

### Настройка CI/CD на GitHub

```
git init
git add .
git commit -m "Initial commit: ML service with Blue-Green deployment"
git branch -M main
git remote add origin https://github.com/...
git push -u origin main
```

2. секреты в GitHub
   - Settings → Secrets and variables → Actions
   - CLOUD_TOKEN и MODEL_VERSION

3. Workflow запустится автоматически при push в main

###  Проверка метрик и логов

```
docker-compose -f docker-compose.blue.yml logs -f ml-service
docker-compose -f docker-compose.green.yml logs -f ml-service
docker ps
docker stats
```

## Тестирование стратегии Blue-Green

###  1 вариант успешное 

```
docker-compose -f docker-compose.blue.yml up -d
curl http://localhost/health
docker build -t ml-service:v1.1.0 --build-arg MODEL_VERSION=v1.1.0 .
docker-compose -f docker-compose.blue.yml down
docker-compose -f docker-compose.green.yml up -d
curl http://localhost/health
```

###  2 вариант Rollback при ошибках

```
docker-compose -f docker-compose.green.yml down
docker-compose -f docker-compose.blue.yml up -d
curl http://localhost/health
```
